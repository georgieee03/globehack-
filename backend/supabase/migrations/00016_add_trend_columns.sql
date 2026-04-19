-- Migration 00016: Add trend tracking columns to client_profiles
-- Supports outcome trend analysis, needs_attention flagging, and next-visit signals

ALTER TABLE public.client_profiles
  ADD COLUMN IF NOT EXISTS trend_classification text
    NOT NULL DEFAULT 'insufficient_data'
    CHECK (trend_classification IN ('improving', 'plateau', 'regressing', 'insufficient_data'));

ALTER TABLE public.client_profiles
  ADD COLUMN IF NOT EXISTS needs_attention boolean
    NOT NULL DEFAULT false;

ALTER TABLE public.client_profiles
  ADD COLUMN IF NOT EXISTS next_visit_signal jsonb;

-- Index for practitioner dashboard: quickly find clients needing attention
CREATE INDEX IF NOT EXISTS idx_client_profiles_needs_attention
  ON public.client_profiles(clinic_id, needs_attention)
  WHERE needs_attention = true;

-- Index for trend-based filtering
CREATE INDEX IF NOT EXISTS idx_client_profiles_trend
  ON public.client_profiles(clinic_id, trend_classification);
