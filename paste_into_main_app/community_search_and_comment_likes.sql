-- ============================================================================
-- MockTester Community: Server-side Search + Comment Likes
-- ----------------------------------------------------------------------------
-- Supabase Dashboard -> SQL Editor me pura paste karke Run karna hai.
-- Iske baad Dart wala hissa (community_feed_screen.dart +
-- community_comments_sheet.dart) iske saath chalega.
--
-- Isme:
--   1) Comment likes: comment_likes table + post_comments.upvotes counter
--      trigger se maintain + toggle_comment_like() RPC
--   2) Search: get_ranked_community_feed() me p_search parameter.
--      Search ab sirf load hue posts me nahi, poore server par hoga
--      (content, author naam, tag, creator handle — sab me).
--
-- Best Answer wala feature isme NAHI hai (user ne skip kiya hai).
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1A) post_comments.upvotes column (agar pehle se nahi hai)
-- ----------------------------------------------------------------------------
ALTER TABLE public.post_comments
  ADD COLUMN IF NOT EXISTS upvotes integer NOT NULL DEFAULT 0;


-- ----------------------------------------------------------------------------
-- 1B) comment_likes table: kis user ne kis comment ko like kiya
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.comment_likes (
  comment_id  bigint NOT NULL REFERENCES public.post_comments(id) ON DELETE CASCADE,
  user_handle text   NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (comment_id, user_handle)
);

CREATE INDEX IF NOT EXISTS idx_comment_likes_comment
  ON public.comment_likes(comment_id);

ALTER TABLE public.comment_likes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS comment_likes_select ON public.comment_likes;
CREATE POLICY comment_likes_select ON public.comment_likes
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS comment_likes_insert ON public.comment_likes;
CREATE POLICY comment_likes_insert ON public.comment_likes
  FOR INSERT TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS comment_likes_delete ON public.comment_likes;
CREATE POLICY comment_likes_delete ON public.comment_likes
  FOR DELETE TO anon, authenticated USING (true);

GRANT SELECT, INSERT, DELETE ON public.comment_likes TO anon, authenticated;


-- ----------------------------------------------------------------------------
-- 1C) Counter trigger: comment_likes badle to upvotes apne aap sahi rahe
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_comment_like_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.post_comments
       SET upvotes = (SELECT COUNT(*)::integer FROM public.comment_likes WHERE comment_id = NEW.comment_id)
     WHERE id = NEW.comment_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.post_comments
       SET upvotes = (SELECT COUNT(*)::integer FROM public.comment_likes WHERE comment_id = OLD.comment_id)
     WHERE id = OLD.comment_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_comment_like_count ON public.comment_likes;
CREATE TRIGGER trg_sync_comment_like_count
AFTER INSERT OR DELETE ON public.comment_likes
FOR EACH ROW EXECUTE FUNCTION public.sync_comment_like_count();


-- ----------------------------------------------------------------------------
-- 1D) Toggle RPC: like hai to hatao, nahi hai to lagao.
--     Return: {"liked": true/false, "likes": kul_ginti}
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.toggle_comment_like(
  p_comment_id  bigint,
  p_user_handle text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_liked boolean;
  v_count integer;
BEGIN
  IF p_comment_id IS NULL OR p_user_handle IS NULL OR btrim(p_user_handle) = '' THEN
    RETURN jsonb_build_object('liked', false, 'likes', 0);
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.comment_likes
     WHERE comment_id = p_comment_id AND user_handle = p_user_handle
  ) THEN
    DELETE FROM public.comment_likes
     WHERE comment_id = p_comment_id AND user_handle = p_user_handle;
    v_liked := false;
  ELSE
    INSERT INTO public.comment_likes (comment_id, user_handle)
    VALUES (p_comment_id, p_user_handle)
    ON CONFLICT DO NOTHING;
    v_liked := true;
  END IF;

  SELECT COUNT(*)::integer INTO v_count
    FROM public.comment_likes
   WHERE comment_id = p_comment_id;

  RETURN jsonb_build_object('liked', v_liked, 'likes', v_count);
END;
$$;

GRANT EXECUTE ON FUNCTION public.toggle_comment_like(bigint, text)
  TO anon, authenticated;


-- ----------------------------------------------------------------------------
-- 2) Feed function me p_search.
--    Purane versions hata kar 6-parameter wala banaya jata hai.
--    Baaki ranking formula bilkul waisa hi hai jaisa pehle tha.
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_ranked_community_feed(text, text[], integer, integer);
DROP FUNCTION IF EXISTS public.get_ranked_community_feed(text, text[], integer, integer, text);

CREATE OR REPLACE FUNCTION public.get_ranked_community_feed(
  p_user_handle text DEFAULT NULL,
  p_followed_handles text[] DEFAULT ARRAY[]::text[],
  p_limit integer DEFAULT 20,
  p_offset integer DEFAULT 0,
  p_mode text DEFAULT 'for_you',
  p_search text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  WITH post_metrics AS (
    SELECT
      p.*,

      cp.handle_id AS cp_handle_id,
      cp.name AS cp_name,
      cp.subject_specialty AS cp_subject_specialty,
      cp.followers_count AS cp_followers_count,
      cp.creator_tier AS cp_creator_tier,
      cp.is_approved AS cp_is_approved,

      m.id AS mock_id_found,
      m.title AS mock_title,
      m.subject AS mock_subject,
      m.duration_mins AS mock_duration_mins,
      m.attempts_count AS mock_attempts_count,
      m.questions_json AS mock_questions_json,

      COALESCE(p.upvotes, 0) AS like_count,
      COALESCE(p.comments_count, 0) AS comment_count,
      COALESCE(p.bookmarks_count, 0) AS bookmark_count,

      CASE
        WHEN JSONB_TYPEOF(COALESCE(p.poll_data -> 'votes', 'null'::jsonb)) = 'array'
        THEN COALESCE((
          SELECT SUM(vote_value::integer)::integer
            FROM JSONB_ARRAY_ELEMENTS_TEXT(p.poll_data -> 'votes') AS vote_value
        ), 0)
        ELSE 0
      END AS poll_vote_count,

      (SELECT COUNT(*)::integer
         FROM public.post_reports rp
        WHERE rp.post_id = p.id) AS report_count,

      CASE
        WHEN JSONB_TYPEOF(COALESCE(p.poll_data -> 'votes', 'null'::jsonb)) = 'array'
        THEN p.poll_data -> 'votes'
        ELSE '[]'::jsonb
      END AS actual_poll_votes,

      GREATEST(
        EXTRACT(EPOCH FROM (NOW() - p.created_at)) / 3600.0,
        0
      ) AS age_hours

    FROM public.community_posts p

    LEFT JOIN public.creator_profiles cp
      ON cp.handle_id = p.creator_id

    LEFT JOIN public.creator_mocks m
      ON m.id = p.mock_id

    WHERE COALESCE(p.is_approved, true) = true
      AND NOT EXISTS (
        SELECT 1
          FROM public.post_reports ur
         WHERE ur.post_id = p.id
           AND p_user_handle IS NOT NULL
           AND ur.reported_by = p_user_handle
      )
      -- Server-side search: content, author, tag aur creator handle me.
      AND (
        p_search IS NULL
        OR btrim(p_search) = ''
        OR p.content ILIKE '%' || btrim(p_search) || '%'
        OR p.author_name ILIKE '%' || btrim(p_search) || '%'
        OR COALESCE(p.tag, '') ILIKE '%' || btrim(p_search) || '%'
        OR COALESCE(cp.handle_id, '') ILIKE '%' || btrim(p_search) || '%'
        OR COALESCE(cp.name, '') ILIKE '%' || btrim(p_search) || '%'
      )
  ),

  scored AS (
    SELECT
      pm.*,

      CASE
        WHEN pm.poll_data IS NULL THEN NULL
        ELSE JSONB_SET(pm.poll_data, '{votes}', pm.actual_poll_votes, true)
      END AS actual_poll_data,

      (
        (pm.like_count * 3)
        + (pm.comment_count * 5)
        + (pm.bookmark_count * 4)
        + (COALESCE(pm.shares_count, 0) * 6)
        + (pm.poll_vote_count * 2)
        - (COALESCE(pm.downvotes, 0) * 2)
        - (pm.report_count * 8)
      ) AS engagement_points,

      (
        (
          1 + GREATEST(
            (
              (pm.like_count * 3)
              + (pm.comment_count * 5)
              + (pm.bookmark_count * 4)
              + (COALESCE(pm.shares_count, 0) * 6)
              + (pm.poll_vote_count * 2)
              - (COALESCE(pm.downvotes, 0) * 2)
              - (pm.report_count * 8)
            ),
            0
          )::double precision
        )
        / POWER(pm.age_hours + 2, 1.5)
      )
      * CASE
          WHEN pm.creator_id = ANY(COALESCE(p_followed_handles, ARRAY[]::text[]))
          THEN 1.8
          ELSE 1.0
        END
      * CASE
          WHEN pm.cp_handle_id IS NOT NULL
           AND COALESCE(pm.cp_is_approved, true) = true
          THEN 1.12
          ELSE 1.0
        END
      * CASE
          WHEN COALESCE(pm.cp_followers_count, 0) >= 1000 THEN 1.05
          WHEN COALESCE(pm.cp_followers_count, 0) >= 100 THEN 1.03
          ELSE 1.0
        END
      * CASE
          WHEN LOWER(REGEXP_REPLACE(COALESCE(pm.tag, ''), '[^a-zA-Z0-9 ]', '', 'g'))
                 LIKE '%doubt%'
           AND pm.comment_count = 0
           AND pm.age_hours <= 48
          THEN 1.45
          ELSE 1.0
        END
      * CASE
          WHEN pm.mock_id_found IS NOT NULL THEN 1.10
          ELSE 1.0
        END
      * CASE
          WHEN pm.poll_data IS NOT NULL THEN 1.05
          ELSE 1.0
        END
      AS final_score

    FROM post_metrics pm
    WHERE pm.report_count < 10
  ),

  ranked AS (
    SELECT
      s.*,
      ROW_NUMBER() OVER (
        ORDER BY
          CASE
            WHEN LOWER(COALESCE(p_mode, 'for_you')) = 'latest'
            THEN EXTRACT(EPOCH FROM s.created_at)
          END DESC,
          CASE
            WHEN LOWER(COALESCE(p_mode, 'for_you')) <> 'latest'
            THEN s.final_score
          END DESC,
          s.created_at DESC,
          s.id DESC
      ) AS rank_no
    FROM scored s
    ORDER BY
      CASE
        WHEN LOWER(COALESCE(p_mode, 'for_you')) = 'latest'
        THEN EXTRACT(EPOCH FROM s.created_at)
      END DESC,
      CASE
        WHEN LOWER(COALESCE(p_mode, 'for_you')) <> 'latest'
        THEN s.final_score
      END DESC,
      s.created_at DESC,
      s.id DESC
    LIMIT LEAST(GREATEST(COALESCE(p_limit, 20), 1), 50)
    OFFSET GREATEST(COALESCE(p_offset, 0), 0)
  )

  SELECT COALESCE(
    JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'id', r.id,
        'creator_id', r.creator_id,
        'content', r.content,
        'tag', r.tag,
        'mock_id', r.mock_id,
        'upvotes', r.like_count,
        'downvotes', COALESCE(r.downvotes, 0),
        'views_count', COALESCE(r.views_count, 0),
        'created_at', r.created_at,
        'image_url', r.image_url,
        'author_name', r.author_name,
        'is_approved', COALESCE(r.is_approved, true),
        'shares_count', COALESCE(r.shares_count, 0),
        'bookmarks_count', r.bookmark_count,
        'poll_data', r.actual_poll_data,
        'comments_count', r.comment_count,
        'poll_votes_count', r.poll_vote_count,
        'engagement_score', ROUND(r.final_score::numeric, 6),
        'creator_profiles',
        CASE
          WHEN r.cp_handle_id IS NULL THEN NULL
          ELSE JSONB_BUILD_OBJECT(
            'handle_id', r.cp_handle_id,
            'name', r.cp_name,
            'subject_specialty', r.cp_subject_specialty,
            'followers_count', COALESCE(r.cp_followers_count, 0),
            'creator_tier', r.cp_creator_tier,
            'is_approved', COALESCE(r.cp_is_approved, true)
          )
        END,
        'creator_mocks',
        CASE
          WHEN r.mock_id_found IS NULL THEN NULL
          ELSE JSONB_BUILD_OBJECT(
            'id', r.mock_id_found,
            'title', r.mock_title,
            'subject', r.mock_subject,
            'duration_mins', r.mock_duration_mins,
            'attempts_count', r.mock_attempts_count,
            'questions_json', r.mock_questions_json
          )
        END
      )
      ORDER BY r.rank_no
    ),
    '[]'::jsonb
  )
  FROM ranked r;
$$;

COMMENT ON FUNCTION public.get_ranked_community_feed(text, text[], integer, integer, text, text)
IS 'MockTester feed. p_mode=for_you ranked, p_mode=latest chronological, p_search server-side search (content/author/tag/handle). JSON array return karta hai.';

GRANT EXECUTE ON FUNCTION public.get_ranked_community_feed(text, text[], integer, integer, text, text)
  TO anon, authenticated;


-- ----------------------------------------------------------------------------
-- Test queries (chaaho to Run karke dekh lo):
--
-- SELECT public.get_ranked_community_feed(NULL, ARRAY[]::text[], 5, 0, 'for_you', 'polity');
-- SELECT public.get_ranked_community_feed(NULL, ARRAY[]::text[], 5, 0, 'latest', '');
-- SELECT public.toggle_comment_like(1, 'user');
-- SELECT id, upvotes FROM public.post_comments ORDER BY id LIMIT 5;
-- ----------------------------------------------------------------------------
