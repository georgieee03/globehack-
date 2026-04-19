-- Migration 00014: Create analytics views for clinic dashboards
-- All views include clinic_id for RLS filtering

-- Clinic aggregate metrics view
CREATE OR REPLACE VIEW public.clinic_metrics_v AS
SELECT
  s.clinic_id,
  COUNT(s.id) AS total_sessions,
  COUNT(DISTINCT s.client_id) AS unique_clients,
  COUNT(DISTINCT s.practitioner_id) AS active_practitioners,
  AVG(s.total_duration_s) AS avg_session_duration_s,
  AVG(
    CASE
      WHEN o.stiffness_before IS NOT NULL AND o.stiffness_after IS NOT NULL
      THEN (o.stiffness_before - o.stiffness_after)::numeric / 10
    END
  ) AS avg_improvement,
  COUNT(DISTINCT CASE
    WHEN s.created_at >= now() - interval '30 days' THEN s.client_id
  END) AS active_clients_30d
FROM public.sessions s
LEFT JOIN public.outcomes o ON o.session_id = s.id AND o.recorded_by = 'practitioner'
WHERE s.status = 'completed'
GROUP BY s.clinic_id;

-- Per-practitioner metrics view
CREATE OR REPLACE VIEW public.practitioner_metrics_v AS
SELECT
  s.clinic_id,
  s.practitioner_id,
  u.full_name AS practitioner_name,
  COUNT(s.id) AS total_sessions,
  COUNT(DISTINCT s.client_id) AS client_count,
  COUNT(DISTINCT DATE(s.created_at)) AS active_days,
  CASE
    WHEN COUNT(DISTINCT DATE(s.created_at)) > 0
    THEN COUNT(s.id)::numeric / COUNT(DISTINCT DATE(s.created_at))
    ELSE 0
  END AS avg_sessions_per_day,
  AVG(
    CASE
      WHEN o.stiffness_before IS NOT NULL AND o.stiffness_after IS NOT NULL
      THEN (o.stiffness_before - o.stiffness_after)::numeric / 10
    END
  ) AS avg_outcome_score
FROM public.sessions s
JOIN public.users u ON u.id = s.practitioner_id
LEFT JOIN public.outcomes o ON o.session_id = s.id AND o.recorded_by = 'practitioner'
WHERE s.status = 'completed'
GROUP BY s.clinic_id, s.practitioner_id, u.full_name;

-- Device utilization view
CREATE OR REPLACE VIEW public.device_utilization_v AS
SELECT
  d.clinic_id,
  d.id AS device_id,
  d.label,
  d.room,
  d.device_mac,
  d.status AS current_status,
  COUNT(s.id) AS session_count,
  MAX(s.completed_at) AS last_session_at
FROM public.devices d
LEFT JOIN public.sessions s ON s.device_id = d.id AND s.status = 'completed'
GROUP BY d.clinic_id, d.id, d.label, d.room, d.device_mac, d.status;

-- Protocol effectiveness view
CREATE OR REPLACE VIEW public.protocol_effectiveness_v AS
SELECT
  s.clinic_id,
  s.session_config->>'recoveryGoal' AS recovery_goal,
  s.session_config->>'bodyRegion' AS body_region,
  COUNT(s.id) AS session_count,
  AVG(
    CASE
      WHEN o.stiffness_before IS NOT NULL AND o.stiffness_after IS NOT NULL
      THEN (o.stiffness_before - o.stiffness_after)::numeric / 10
    END
  ) AS avg_outcome_score,
  CASE
    WHEN COUNT(s.id) < 5 THEN true
    ELSE false
  END AS limited_data
FROM public.sessions s
LEFT JOIN public.outcomes o ON o.session_id = s.id
WHERE s.status = 'completed'
  AND s.session_config IS NOT NULL
GROUP BY s.clinic_id, s.session_config->>'recoveryGoal', s.session_config->>'bodyRegion';

-- Client retention view
CREATE OR REPLACE VIEW public.client_retention_v AS
SELECT
  s.clinic_id,
  COUNT(DISTINCT s.client_id) AS total_clients,
  COUNT(DISTINCT CASE
    WHEN client_sessions.session_count >= 2 THEN s.client_id
  END) AS returning_clients,
  AVG(client_sessions.session_count) AS avg_sessions_per_client
FROM public.sessions s
JOIN (
  SELECT client_id, COUNT(*) AS session_count
  FROM public.sessions
  WHERE status = 'completed'
  GROUP BY client_id
) client_sessions ON client_sessions.client_id = s.client_id
WHERE s.status = 'completed'
GROUP BY s.clinic_id;
