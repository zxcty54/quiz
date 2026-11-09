-- Device-based UGC/AI moderation reports used by the Flutter app.
-- Apply this migration in Supabase before releasing the app; it is not applied
-- to the production project by this repository change.

CREATE TABLE IF NOT EXISTS public.content_moderation_reports (
  id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  reported_by     text NOT NULL,
  target_type     text NOT NULL CHECK (
    target_type IN (
      'ai_response',
      'community_post',
      'community_user',
      'community_comment',
      'batch_test',
      'question_error',
      'public_mock'
    )
  ),
  target_id       text NOT NULL,
  target_handle   text,
  post_id         bigint,
  source          text,
  reason          text NOT NULL,
  content_excerpt text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT content_moderation_reports_reported_by_length
    CHECK (char_length(reported_by) BETWEEN 1 AND 160),
  CONSTRAINT content_moderation_reports_target_id_length
    CHECK (char_length(target_id) BETWEEN 1 AND 200),
  CONSTRAINT content_moderation_reports_reason_length
    CHECK (char_length(reason) BETWEEN 1 AND 100),
  CONSTRAINT content_moderation_reports_excerpt_length
    CHECK (content_excerpt IS NULL OR char_length(content_excerpt) <= 600),
  CONSTRAINT content_moderation_reports_unique_report
    UNIQUE (reported_by, target_type, target_id)
);

CREATE INDEX IF NOT EXISTS idx_content_moderation_reports_created_at
  ON public.content_moderation_reports (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_content_moderation_reports_target
  ON public.content_moderation_reports (target_type, target_id, created_at DESC);

ALTER TABLE public.content_moderation_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS content_moderation_reports_insert
  ON public.content_moderation_reports;
CREATE POLICY content_moderation_reports_insert
  ON public.content_moderation_reports
  FOR INSERT TO anon, authenticated
  WITH CHECK (
    char_length(trim(reported_by)) BETWEEN 1 AND 160
    AND char_length(trim(target_id)) BETWEEN 1 AND 200
    AND char_length(trim(reason)) BETWEEN 1 AND 100
    AND (content_excerpt IS NULL OR char_length(content_excerpt) <= 600)
  );

-- Client apps may submit reports, but cannot read, alter, or erase the queue.
REVOKE ALL ON public.content_moderation_reports FROM anon, authenticated;
GRANT INSERT ON public.content_moderation_reports TO anon, authenticated;

COMMENT ON TABLE public.content_moderation_reports IS
  'User-submitted moderation reports for AI responses, community posts/users/comments, public mocks, batch tests, and question content. Client inserts only.';
