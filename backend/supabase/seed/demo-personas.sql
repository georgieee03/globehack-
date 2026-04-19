-- Demo Personas Seed Data
-- Three client personas with 3-5 sessions each, showing visible Recovery Score trends
-- Depends on seed.sql having created the demo clinic, practitioners, and devices
--
-- Persona 1: Alex Rivera — improving trend (right_shoulder)
-- Persona 2: Jordan Chen — plateau trend (lower_back)
-- Persona 3: Sam Patel — regressing trend (left_knee)

-- ═══════════════════════════════════════════════════════════════════════════════
-- NOTE: This seed file assumes the following IDs exist from seed.sql:
--   Clinic:       Use the first clinic from seed.sql
--   Practitioner: Use the first practitioner user
--   Device:       Use the first device
--   Client users: We create 3 new client auth users + profiles below
-- ═══════════════════════════════════════════════════════════════════════════════

DO $demo$
DECLARE
  v_clinic_id uuid;
  v_practitioner_id uuid;
  v_device_id uuid;

  -- Alex Rivera (improving)
  v_alex_auth_id uuid := gen_random_uuid();
  v_alex_profile_id uuid;
  v_alex_session_ids uuid[] := ARRAY[gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid()];

  -- Jordan Chen (plateau)
  v_jordan_auth_id uuid := gen_random_uuid();
  v_jordan_profile_id uuid;
  v_jordan_session_ids uuid[] := ARRAY[gen_random_uuid(), gen_random_uuid(), gen_random_uuid()];

  -- Sam Patel (regressing)
  v_sam_auth_id uuid := gen_random_uuid();
  v_sam_profile_id uuid;
  v_sam_session_ids uuid[] := ARRAY[gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid()];

BEGIN
  -- Get existing demo data references
  SELECT id INTO v_clinic_id FROM public.clinics LIMIT 1;
  SELECT id INTO v_practitioner_id FROM public.users WHERE role = 'practitioner' AND clinic_id = v_clinic_id LIMIT 1;
  SELECT id INTO v_device_id FROM public.devices WHERE clinic_id = v_clinic_id LIMIT 1;

  IF v_clinic_id IS NULL OR v_practitioner_id IS NULL OR v_device_id IS NULL THEN
    RAISE NOTICE 'Demo seed requires existing clinic, practitioner, and device from seed.sql. Skipping demo personas.';
    RETURN;
  END IF;

  -- ═══════════════════════════════════════════════════════════════════════════
  -- Create auth users (simplified — in production these come from Supabase Auth)
  -- ═══════════════════════════════════════════════════════════════════════════

  INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at, instance_id, aud, role)
  VALUES
    (v_alex_auth_id, 'alex.rivera@demo.hydrascan.app', crypt('demo-password', gen_salt('bf')), now(), now() - interval '60 days', now(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated'),
    (v_jordan_auth_id, 'jordan.chen@demo.hydrascan.app', crypt('demo-password', gen_salt('bf')), now(), now() - interval '45 days', now(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated'),
    (v_sam_auth_id, 'sam.patel@demo.hydrascan.app', crypt('demo-password', gen_salt('bf')), now(), now() - interval '30 days', now(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated')
  ON CONFLICT (id) DO NOTHING;

  -- Create user records
  INSERT INTO public.users (id, clinic_id, role, email, full_name)
  VALUES
    (v_alex_auth_id, v_clinic_id, 'client', 'alex.rivera@demo.hydrascan.app', 'Alex Rivera'),
    (v_jordan_auth_id, v_clinic_id, 'client', 'jordan.chen@demo.hydrascan.app', 'Jordan Chen'),
    (v_sam_auth_id, v_clinic_id, 'client', 'sam.patel@demo.hydrascan.app', 'Sam Patel')
  ON CONFLICT DO NOTHING;

  -- Create client profiles
  INSERT INTO public.client_profiles (user_id, clinic_id, primary_regions, goals, activity_context)
  VALUES
    (v_alex_auth_id, v_clinic_id, '["right_shoulder"]'::jsonb, '{recovery}', 'Desk worker with shoulder tension from computer use')
  RETURNING id INTO v_alex_profile_id;

  INSERT INTO public.client_profiles (user_id, clinic_id, primary_regions, goals, activity_context)
  VALUES
    (v_jordan_auth_id, v_clinic_id, '["lower_back"]'::jsonb, '{mobility,recovery}', 'Runner with persistent lower back tightness')
  RETURNING id INTO v_jordan_profile_id;

  INSERT INTO public.client_profiles (user_id, clinic_id, primary_regions, goals, activity_context)
  VALUES
    (v_sam_auth_id, v_clinic_id, '["left_knee"]'::jsonb, '{recovery,warm_up}', 'Post-marathon recovery, left knee stiffness increasing')
  RETURNING id INTO v_sam_profile_id;

  -- ═══════════════════════════════════════════════════════════════════════════
  -- ALEX RIVERA — 5 sessions, IMPROVING (stiffness: 8→7→6→4→3)
  -- Recovery Scores: 35 → 52 → 61 → 68 → 74
  -- ═══════════════════════════════════════════════════════════════════════════

  INSERT INTO public.sessions (id, client_id, clinic_id, practitioner_id, device_id, session_config, status, completed_at, total_duration_s, created_at)
  VALUES
    (v_alex_session_ids[1], v_alex_profile_id, v_clinic_id, v_practitioner_id, v_device_id,
     '{"bodyRegion":"right_shoulder","recoveryGoal":"recovery","thermalIntensity":5,"vibrationRange":[3,7],"durationMinutes":20}'::jsonb,
     'completed', now() - interval '50 days', 1200, now() - interval '50 days'),
    (v_alex_session_ids[2], v_alex_profile_id, v_clinic_id, v_practitioner_id, v_device_id,
     '{"bodyRegion":"right_shoulder","recoveryGoal":"recovery","thermalIntensity":6,"vibrationRange":[4,8],"durationMinutes":25}'::jsonb,
     'completed', now() - interval '40 days', 1500, now() - interval '40 days'),
    (v_alex_session_ids[3], v_alex_profile_id, v_clinic_id, v_practitioner_id, v_device_id,
     '{"bodyRegion":"right_shoulder","recoveryGoal":"recovery","thermalIntensity":6,"vibrationRange":[4,8],"durationMinutes":25}'::jsonb,
     'completed', now() - interval '30 days', 1500, now() - interval '30 days'),
    (v_alex_session_ids[4], v_alex_profile_id, v_clinic_id, v_practitioner_id, v_device_id,
     '{"bodyRegion":"right_shoulder","recoveryGoal":"mobility","thermalIntensity":7,"vibrationRange":[5,9],"durationMinutes":30}'::jsonb,
     'completed', now() - interval '15 days', 1800, now() - interval '15 days'),
    (v_alex_session_ids[5], v_alex_profile_id, v_clinic_id, v_practitioner_id, v_device_id,
     '{"bodyRegion":"right_shoulder","recoveryGoal":"mobility","thermalIntensity":7,"vibrationRange":[5,9],"durationMinutes":30}'::jsonb,
     'completed', now() - interval '5 days', 1800, now() - interval '5 days');

  -- Alex outcomes (improving: stiffness decreasing)
  INSERT INTO public.outcomes (session_id, client_id, clinic_id, recorded_by, recorded_by_user_id, stiffness_before, stiffness_after, mobility_improved, session_effective, repeat_intent, practitioner_notes, created_at)
  VALUES
    (v_alex_session_ids[1], v_alex_profile_id, v_clinic_id, 'practitioner', v_practitioner_id, 9, 8, 'maybe', 'yes', 'yes', 'Initial session, moderate response', now() - interval '50 days'),
    (v_alex_session_ids[2], v_alex_profile_id, v_clinic_id, 'practitioner', v_practitioner_id, 8, 7, 'yes', 'yes', 'yes', 'Good improvement, increased intensity', now() - interval '40 days'),
    (v_alex_session_ids[3], v_alex_profile_id, v_clinic_id, 'practitioner', v_practitioner_id, 7, 6, 'yes', 'yes', 'yes', 'Consistent progress', now() - interval '30 days'),
    (v_alex_session_ids[4], v_alex_profile_id, v_clinic_id, 'practitioner', v_practitioner_id, 6, 4, 'yes', 'yes', 'yes', 'Significant improvement, shifted to mobility focus', now() - interval '15 days'),
    (v_alex_session_ids[5], v_alex_profile_id, v_clinic_id, 'practitioner', v_practitioner_id, 5, 3, 'yes', 'yes', 'yes', 'Excellent progress, near baseline', now() - interval '5 days');

  -- Alex Recovery Graph points
  INSERT INTO public.recovery_graph (client_id, clinic_id, body_region, metric_type, value, source, source_id, recorded_at)
  VALUES
    (v_alex_profile_id, v_clinic_id, 'right_shoulder', 'stiffness', 8, 'session_outcome', v_alex_session_ids[1], now() - interval '50 days'),
    (v_alex_profile_id, v_clinic_id, 'right_shoulder', 'stiffness', 7, 'session_outcome', v_alex_session_ids[2], now() - interval '40 days'),
    (v_alex_profile_id, v_clinic_id, 'right_shoulder', 'stiffness', 6, 'session_outcome', v_alex_session_ids[3], now() - interval '30 days'),
    (v_alex_profile_id, v_clinic_id, 'right_shoulder', 'stiffness', 4, 'session_outcome', v_alex_session_ids[4], now() - interval '15 days'),
    (v_alex_profile_id, v_clinic_id, 'right_shoulder', 'stiffness', 3, 'session_outcome', v_alex_session_ids[5], now() - interval '5 days'),
    -- Recovery Scores
    (v_alex_profile_id, v_clinic_id, 'overall', 'recovery_score', 35, 'session_outcome', v_alex_session_ids[1], now() - interval '50 days'),
    (v_alex_profile_id, v_clinic_id, 'overall', 'recovery_score', 52, 'session_outcome', v_alex_session_ids[2], now() - interval '40 days'),
    (v_alex_profile_id, v_clinic_id, 'overall', 'recovery_score', 61, 'session_outcome', v_alex_session_ids[3], now() - interval '30 days'),
    (v_alex_profile_id, v_clinic_id, 'overall', 'recovery_score', 68, 'session_outcome', v_alex_session_ids[4], now() - interval '15 days'),
    (v_alex_profile_id, v_clinic_id, 'overall', 'recovery_score', 74, 'session_outcome', v_alex_session_ids[5], now() - interval '5 days');

  -- Update Alex's trend
  UPDATE public.client_profiles SET
    trend_classification = 'improving',
    needs_attention = false,
    next_visit_signal = '{"recommended_return_days":10,"urgency":"routine","rationale":"Recovery trajectory is positive — routine follow-up recommended."}'::jsonb
  WHERE id = v_alex_profile_id;

  -- ═══════════════════════════════════════════════════════════════════════════
  -- JORDAN CHEN — 3 sessions, PLATEAU (stiffness: 6→6→5)
  -- Recovery Scores: 45 → 47 → 46
  -- ═══════════════════════════════════════════════════════════════════════════

  INSERT INTO public.sessions (id, client_id, clinic_id, practitioner_id, device_id, session_config, status, completed_at, total_duration_s, created_at)
  VALUES
    (v_jordan_session_ids[1], v_jordan_profile_id, v_clinic_id, v_practitioner_id, v_device_id,
     '{"bodyRegion":"lower_back","recoveryGoal":"mobility","thermalIntensity":5,"vibrationRange":[3,6],"durationMinutes":20}'::jsonb,
     'completed', now() - interval '30 days', 1200, now() - interval '30 days'),
    (v_jordan_session_ids[2], v_jordan_profile_id, v_clinic_id, v_practitioner_id, v_device_id,
     '{"bodyRegion":"lower_back","recoveryGoal":"mobility","thermalIntensity":5,"vibrationRange":[3,6],"durationMinutes":20}'::jsonb,
     'completed', now() - interval '20 days', 1200, now() - interval '20 days'),
    (v_jordan_session_ids[3], v_jordan_profile_id, v_clinic_id, v_practitioner_id, v_device_id,
     '{"bodyRegion":"lower_back","recoveryGoal":"recovery","thermalIntensity":6,"vibrationRange":[4,7],"durationMinutes":25}'::jsonb,
     'completed', now() - interval '10 days', 1500, now() - interval '10 days');

  INSERT INTO public.outcomes (session_id, client_id, clinic_id, recorded_by, recorded_by_user_id, stiffness_before, stiffness_after, mobility_improved, session_effective, repeat_intent, practitioner_notes, created_at)
  VALUES
    (v_jordan_session_ids[1], v_jordan_profile_id, v_clinic_id, 'practitioner', v_practitioner_id, 7, 6, 'maybe', 'maybe', 'yes', 'Minimal change, lower back remains tight', now() - interval '30 days'),
    (v_jordan_session_ids[2], v_jordan_profile_id, v_clinic_id, 'practitioner', v_practitioner_id, 7, 6, 'maybe', 'maybe', 'maybe', 'Same pattern, consider protocol adjustment', now() - interval '20 days'),
    (v_jordan_session_ids[3], v_jordan_profile_id, v_clinic_id, 'practitioner', v_practitioner_id, 6, 5, 'maybe', 'yes', 'yes', 'Slight improvement with new protocol', now() - interval '10 days');

  INSERT INTO public.recovery_graph (client_id, clinic_id, body_region, metric_type, value, source, source_id, recorded_at)
  VALUES
    (v_jordan_profile_id, v_clinic_id, 'lower_back', 'stiffness', 6, 'session_outcome', v_jordan_session_ids[1], now() - interval '30 days'),
    (v_jordan_profile_id, v_clinic_id, 'lower_back', 'stiffness', 6, 'session_outcome', v_jordan_session_ids[2], now() - interval '20 days'),
    (v_jordan_profile_id, v_clinic_id, 'lower_back', 'stiffness', 5, 'session_outcome', v_jordan_session_ids[3], now() - interval '10 days'),
    (v_jordan_profile_id, v_clinic_id, 'overall', 'recovery_score', 45, 'session_outcome', v_jordan_session_ids[1], now() - interval '30 days'),
    (v_jordan_profile_id, v_clinic_id, 'overall', 'recovery_score', 47, 'session_outcome', v_jordan_session_ids[2], now() - interval '20 days'),
    (v_jordan_profile_id, v_clinic_id, 'overall', 'recovery_score', 46, 'session_outcome', v_jordan_session_ids[3], now() - interval '10 days');

  UPDATE public.client_profiles SET
    trend_classification = 'plateau',
    needs_attention = true,
    next_visit_signal = '{"recommended_return_days":4,"urgency":"soon","rationale":"Recovery Score plateauing — a follow-up session may help break through."}'::jsonb
  WHERE id = v_jordan_profile_id;

  -- ═══════════════════════════════════════════════════════════════════════════
  -- SAM PATEL — 4 sessions, REGRESSING (stiffness: 4→5→6→7)
  -- Recovery Scores: 60 → 55 → 48 → 42
  -- ═══════════════════════════════════════════════════════════════════════════

  INSERT INTO public.sessions (id, client_id, clinic_id, practitioner_id, device_id, session_config, status, completed_at, total_duration_s, created_at)
  VALUES
    (v_sam_session_ids[1], v_sam_profile_id, v_clinic_id, v_practitioner_id, v_device_id,
     '{"bodyRegion":"left_knee","recoveryGoal":"recovery","thermalIntensity":4,"vibrationRange":[2,5],"durationMinutes":15}'::jsonb,
     'completed', now() - interval '25 days', 900, now() - interval '25 days'),
    (v_sam_session_ids[2], v_sam_profile_id, v_clinic_id, v_practitioner_id, v_device_id,
     '{"bodyRegion":"left_knee","recoveryGoal":"recovery","thermalIntensity":5,"vibrationRange":[3,6],"durationMinutes":20}'::jsonb,
     'completed', now() - interval '18 days', 1200, now() - interval '18 days'),
    (v_sam_session_ids[3], v_sam_profile_id, v_clinic_id, v_practitioner_id, v_device_id,
     '{"bodyRegion":"left_knee","recoveryGoal":"recovery","thermalIntensity":5,"vibrationRange":[3,6],"durationMinutes":20}'::jsonb,
     'completed', now() - interval '10 days', 1200, now() - interval '10 days'),
    (v_sam_session_ids[4], v_sam_profile_id, v_clinic_id, v_practitioner_id, v_device_id,
     '{"bodyRegion":"left_knee","recoveryGoal":"warm_up","thermalIntensity":6,"vibrationRange":[4,7],"durationMinutes":25}'::jsonb,
     'completed', now() - interval '3 days', 1500, now() - interval '3 days');

  INSERT INTO public.outcomes (session_id, client_id, clinic_id, recorded_by, recorded_by_user_id, stiffness_before, stiffness_after, mobility_improved, session_effective, repeat_intent, practitioner_notes, created_at)
  VALUES
    (v_sam_session_ids[1], v_sam_profile_id, v_clinic_id, 'practitioner', v_practitioner_id, 5, 4, 'yes', 'yes', 'yes', 'Good initial response post-marathon', now() - interval '25 days'),
    (v_sam_session_ids[2], v_sam_profile_id, v_clinic_id, 'practitioner', v_practitioner_id, 6, 5, 'maybe', 'maybe', 'yes', 'Stiffness returning between sessions', now() - interval '18 days'),
    (v_sam_session_ids[3], v_sam_profile_id, v_clinic_id, 'practitioner', v_practitioner_id, 7, 6, 'no', 'maybe', 'maybe', 'Regression noted, may need different approach', now() - interval '10 days'),
    (v_sam_session_ids[4], v_sam_profile_id, v_clinic_id, 'practitioner', v_practitioner_id, 8, 7, 'no', 'no', 'maybe', 'Continued regression, recommend activity modification', now() - interval '3 days');

  INSERT INTO public.recovery_graph (client_id, clinic_id, body_region, metric_type, value, source, source_id, recorded_at)
  VALUES
    (v_sam_profile_id, v_clinic_id, 'left_knee', 'stiffness', 4, 'session_outcome', v_sam_session_ids[1], now() - interval '25 days'),
    (v_sam_profile_id, v_clinic_id, 'left_knee', 'stiffness', 5, 'session_outcome', v_sam_session_ids[2], now() - interval '18 days'),
    (v_sam_profile_id, v_clinic_id, 'left_knee', 'stiffness', 6, 'session_outcome', v_sam_session_ids[3], now() - interval '10 days'),
    (v_sam_profile_id, v_clinic_id, 'left_knee', 'stiffness', 7, 'session_outcome', v_sam_session_ids[4], now() - interval '3 days'),
    (v_sam_profile_id, v_clinic_id, 'overall', 'recovery_score', 60, 'session_outcome', v_sam_session_ids[1], now() - interval '25 days'),
    (v_sam_profile_id, v_clinic_id, 'overall', 'recovery_score', 55, 'session_outcome', v_sam_session_ids[2], now() - interval '18 days'),
    (v_sam_profile_id, v_clinic_id, 'overall', 'recovery_score', 48, 'session_outcome', v_sam_session_ids[3], now() - interval '10 days'),
    (v_sam_profile_id, v_clinic_id, 'overall', 'recovery_score', 42, 'session_outcome', v_sam_session_ids[4], now() - interval '3 days');

  UPDATE public.client_profiles SET
    trend_classification = 'regressing',
    needs_attention = true,
    next_visit_signal = '{"recommended_return_days":2,"urgency":"priority","rationale":"Recovery Score below 40 with regressing trend — early return recommended."}'::jsonb
  WHERE id = v_sam_profile_id;

  RAISE NOTICE 'Demo personas seeded: Alex Rivera (improving), Jordan Chen (plateau), Sam Patel (regressing)';
END;
$demo$;
