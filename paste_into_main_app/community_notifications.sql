-- ============================================================================
-- MockTester Community: In-App Notifications
-- ----------------------------------------------------------------------------
-- Supabase SQL Editor me paste karke Run karna hai.
-- Jab koi aapki post par comment kare, aapke comment ka reply de,
-- ya aapke post/comment ko like kare — to user_notifications me ek
-- entry banegi. App ki ghanti (bell) wahi dikhayegi.
-- Dobara chalane se duplicate nahi banta.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.user_notifications (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_handle  text NOT NULL,
  actor_handle text,
  type         text NOT NULL,
  post_id      bigint,
  comment_id   bigint,
  message      text,
  is_read      boolean NOT NULL DEFAULT false,
  created_at   timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.user_notifications
  ADD COLUMN IF NOT EXISTS user_handle  text,
  ADD COLUMN IF NOT EXISTS actor_handle text,
  ADD COLUMN IF NOT EXISTS type         text,
  ADD COLUMN IF NOT EXISTS post_id      bigint,
  ADD COLUMN IF NOT EXISTS comment_id   bigint,
  ADD COLUMN IF NOT EXISTS message      text,
  ADD COLUMN IF NOT EXISTS is_read      boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS created_at   timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_user_notifications_user
  ON public.user_notifications(user_handle, created_at DESC);

ALTER TABLE public.user_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_notifications_all ON public.user_notifications;
CREATE POLICY user_notifications_all ON public.user_notifications
  FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

GRANT SELECT, INSERT, UPDATE ON public.user_notifications TO anon, authenticated;


-- 1) Post par comment / comment ka reply
CREATE OR REPLACE FUNCTION public.notify_on_post_comment()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_post_owner text;
  v_parent_author text;
  v_parent_text text;
BEGIN
  SELECT creator_id INTO v_post_owner
    FROM public.community_posts WHERE id = NEW.post_id;

  IF NEW.parent_comment_id IS NOT NULL THEN
    SELECT user_handle INTO v_parent_author
      FROM public.post_comments WHERE id = NEW.parent_comment_id;

    IF v_parent_author IS NOT NULL AND v_parent_author <> NEW.user_handle THEN
      INSERT INTO public.user_notifications (user_handle, actor_handle, type, post_id, comment_id, message)
      VALUES (
        v_parent_author, NEW.user_handle, 'comment_reply', NEW.post_id, NEW.id,
        COALESCE(NEW.user_name, 'Someone') || ' replied to your comment'
      );
    END IF;

    -- Post owner ko alag se tabhi batao jab woh reply wale se alag ho,
    -- warna ek hi ghatna ki do ghantiyan bajengi.
    IF v_post_owner IS NOT NULL
       AND v_post_owner <> NEW.user_handle
       AND v_post_owner IS DISTINCT FROM v_parent_author THEN
      INSERT INTO public.user_notifications (user_handle, actor_handle, type, post_id, comment_id, message)
      VALUES (
        v_post_owner, NEW.user_handle, 'post_comment', NEW.post_id, NEW.id,
        COALESCE(NEW.user_name, 'Someone') || ' commented on your post'
      );
    END IF;
  ELSE
    IF v_post_owner IS NOT NULL AND v_post_owner <> NEW.user_handle THEN
      INSERT INTO public.user_notifications (user_handle, actor_handle, type, post_id, comment_id, message)
      VALUES (
        v_post_owner, NEW.user_handle, 'post_comment', NEW.post_id, NEW.id,
        COALESCE(NEW.user_name, 'Someone') || ' commented on your post'
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_post_comment ON public.post_comments;
CREATE TRIGGER trg_notify_on_post_comment
AFTER INSERT ON public.post_comments
FOR EACH ROW EXECUTE FUNCTION public.notify_on_post_comment();


-- 2) Comment like
CREATE OR REPLACE FUNCTION public.notify_on_comment_like()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_author text;
  v_post_id bigint;
BEGIN
  SELECT user_handle, post_id INTO v_author, v_post_id
    FROM public.post_comments WHERE id = NEW.comment_id;

  IF v_author IS NOT NULL AND v_author <> NEW.user_handle THEN
    INSERT INTO public.user_notifications (user_handle, actor_handle, type, post_id, comment_id, message)
    VALUES (
      v_author, NEW.user_handle, 'comment_like', v_post_id, NEW.comment_id,
      'Someone liked your comment'
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_comment_like ON public.comment_likes;
CREATE TRIGGER trg_notify_on_comment_like
AFTER INSERT ON public.comment_likes
FOR EACH ROW EXECUTE FUNCTION public.notify_on_comment_like();


-- 3) Post like
CREATE OR REPLACE FUNCTION public.notify_on_post_like()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_owner text;
BEGIN
  SELECT creator_id INTO v_owner
    FROM public.community_posts WHERE id = NEW.post_id;

  IF v_owner IS NOT NULL AND v_owner <> NEW.user_handle THEN
    INSERT INTO public.user_notifications (user_handle, actor_handle, type, post_id, message)
    VALUES (
      v_owner, NEW.user_handle, 'post_like', NEW.post_id,
      'Someone liked your post'
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_post_like ON public.post_likes;
CREATE TRIGGER trg_notify_on_post_like
AFTER INSERT ON public.post_likes
FOR EACH ROW EXECUTE FUNCTION public.notify_on_post_like();
