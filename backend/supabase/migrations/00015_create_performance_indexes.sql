-- Migration 00015: Performance indexes for analytics queries
-- These supplement the indexes already created in the base migrations

-- Outcome lookups by session + recorded_by (already exists as unique index, adding explicit composite)
CREATE INDEX IF NOT EXISTS idx_outcomes_session_recorded
  ON public.outcomes(session_id, recorded_by);

-- Recovery graph lookups by client + region + time (already exists, ensuring DESC ordering)
-- idx recovery_graph_client_region_recorded_at_idx already covers this

-- Session lookups by clinic + status (already exists as sessions_clinic_status_idx)
-- Adding practitioner-specific index for per-practitioner analytics
CREATE INDEX IF NOT EXISTS idx_sessions_practitioner_status
  ON public.sessions(practitioner_id, status);

-- Session config JSONB indexes for protocol effectiveness queries
CREATE INDEX IF NOT EXISTS idx_sessions_config_recovery_goal
  ON public.sessions ((session_config->>'recoveryGoal'))
  WHERE status = 'completed' AND session_config IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_sessions_config_body_region
  ON public.sessions ((session_config->>'bodyRegion'))
  WHERE status = 'completed' AND session_config IS NOT NULL;

-- Client retention: sessions by client for counting return visits
CREATE INDEX IF NOT EXISTS idx_sessions_client_status
  ON public.sessions(client_id, status);

-- Daily checkins for Recovery Score computation
CREATE INDEX IF NOT EXISTS idx_daily_checkins_client_recent
  ON public.daily_checkins(client_id, created_at DESC);
