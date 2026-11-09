-- Stores the canonical content_base taxonomy tag alongside each AI-mastery attempt.
-- Apply this additive migration before deploying the Flutter client that sends topic_tag.
ALTER TABLE public.user_question_attempts
  ADD COLUMN IF NOT EXISTS topic_tag text;

COMMENT ON COLUMN public.user_question_attempts.topic_tag IS
  'Canonical question taxonomy tag in subject.domain.topic format';
