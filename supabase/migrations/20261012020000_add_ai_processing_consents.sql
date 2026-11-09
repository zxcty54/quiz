-- Explicit opt-in used by the scheduled AI mastery worker. This migration is
-- staged only; apply it to the Supabase project before deploying the Worker.
CREATE TABLE IF NOT EXISTS public.ai_processing_consents (
  user_id         text PRIMARY KEY,
  consent_version text NOT NULL,
  consented_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ai_processing_consents_user_id_length
    CHECK (char_length(trim(user_id)) BETWEEN 1 AND 160),
  CONSTRAINT ai_processing_consents_version_length
    CHECK (char_length(trim(consent_version)) BETWEEN 1 AND 80)
);

ALTER TABLE public.ai_processing_consents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ai_processing_consents_insert
  ON public.ai_processing_consents;
CREATE POLICY ai_processing_consents_insert
  ON public.ai_processing_consents
  FOR INSERT TO anon, authenticated
  WITH CHECK (
    char_length(trim(user_id)) BETWEEN 1 AND 160
    AND char_length(trim(consent_version)) BETWEEN 1 AND 80
  );

DROP POLICY IF EXISTS ai_processing_consents_update
  ON public.ai_processing_consents;
CREATE POLICY ai_processing_consents_update
  ON public.ai_processing_consents
  FOR UPDATE TO anon, authenticated
  USING (true)
  WITH CHECK (
    char_length(trim(user_id)) BETWEEN 1 AND 160
    AND char_length(trim(consent_version)) BETWEEN 1 AND 80
  );

DROP POLICY IF EXISTS ai_processing_consents_delete
  ON public.ai_processing_consents;
CREATE POLICY ai_processing_consents_delete
  ON public.ai_processing_consents
  FOR DELETE TO anon, authenticated
  USING (true);

-- The app can register/revoke an opt-in but cannot enumerate consent records.
-- The scheduled Worker reads them with its server-side Supabase service role.
REVOKE ALL ON public.ai_processing_consents FROM anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.ai_processing_consents TO anon, authenticated;
GRANT SELECT (user_id) ON public.ai_processing_consents TO anon, authenticated;

COMMENT ON TABLE public.ai_processing_consents IS
  'Device-user opt-ins for server-side AI processing of stored mastery attempts; client write-only.';
