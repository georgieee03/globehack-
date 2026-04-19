insert into public.clinics (id, name, address, timezone)
values
  ('11111111-1111-1111-1111-111111111111', 'Phoenix Recovery Center', '1201 E Camelback Rd, Phoenix, AZ', 'America/Phoenix'),
  ('22222222-2222-2222-2222-222222222222', 'Scottsdale Wellness Studio', '7010 E Shea Blvd, Scottsdale, AZ', 'America/Phoenix')
on conflict (id) do nothing;

alter table public.users disable trigger users_ensure_client_profile;

insert into auth.users (
  id,
  email,
  password,
  email_verified,
  created_at,
  updated_at,
  profile,
  metadata,
  is_project_admin,
  is_anonymous
)
select
  seed_users.id,
  seed_users.email,
  crypt('HydraScan123!', gen_salt('bf')),
  true,
  now(),
  now(),
  jsonb_build_object(
    'full_name',
    seed_users.full_name
  ),
  jsonb_build_object(
    'role',
    seed_users.role,
    'clinic_id',
    seed_users.clinic_id::text,
    'auth_provider',
    seed_users.role,
    seed_users.auth_provider
  ),
  false,
  false
from (
  values
    ('aaaaaaaa-1111-1111-1111-111111111111'::uuid, '11111111-1111-1111-1111-111111111111'::uuid, 'admin', 'admin@phoenixrecovery.test', 'Avery Admin', 'email'),
    ('aaaaaaaa-2222-2222-2222-222222222222'::uuid, '11111111-1111-1111-1111-111111111111'::uuid, 'practitioner', 'priya@phoenixrecovery.test', 'Priya Practitioner', 'email'),
    ('aaaaaaaa-3333-3333-3333-333333333333'::uuid, '11111111-1111-1111-1111-111111111111'::uuid, 'practitioner', 'marco@phoenixrecovery.test', 'Marco Mobility', 'apple'),
    ('aaaaaaaa-4444-4444-4444-444444444444'::uuid, '11111111-1111-1111-1111-111111111111'::uuid, 'client', 'carmen@phoenixrecovery.test', 'Carmen Client', 'apple'),
    ('aaaaaaaa-5555-5555-5555-555555555555'::uuid, '11111111-1111-1111-1111-111111111111'::uuid, 'client', 'drew@phoenixrecovery.test', 'Drew Daily', 'email'),
    ('aaaaaaaa-6666-6666-6666-666666666666'::uuid, '11111111-1111-1111-1111-111111111111'::uuid, 'client', 'elena@phoenixrecovery.test', 'Elena Energy', 'email'),
    ('bbbbbbbb-1111-1111-1111-111111111111'::uuid, '22222222-2222-2222-2222-222222222222'::uuid, 'admin', 'admin@scottsdalewellness.test', 'Sam Admin', 'email'),
    ('bbbbbbbb-2222-2222-2222-222222222222'::uuid, '22222222-2222-2222-2222-222222222222'::uuid, 'practitioner', 'talia@scottsdalewellness.test', 'Talia Trainer', 'email'),
    ('bbbbbbbb-3333-3333-3333-333333333333'::uuid, '22222222-2222-2222-2222-222222222222'::uuid, 'practitioner', 'noah@scottsdalewellness.test', 'Noah Recovery', 'apple'),
    ('bbbbbbbb-4444-4444-4444-444444444444'::uuid, '22222222-2222-2222-2222-222222222222'::uuid, 'client', 'mila@scottsdalewellness.test', 'Mila Mobility', 'apple'),
    ('bbbbbbbb-5555-5555-5555-555555555555'::uuid, '22222222-2222-2222-2222-222222222222'::uuid, 'client', 'owen@scottsdalewellness.test', 'Owen Output', 'email'),
    ('bbbbbbbb-6666-6666-6666-666666666666'::uuid, '22222222-2222-2222-2222-222222222222'::uuid, 'client', 'zoe@scottsdalewellness.test', 'Zoe Zen', 'email')
) as seed_users(id, clinic_id, role, email, full_name, auth_provider)
on conflict (id) do nothing;

insert into auth.user_providers (
  id,
  user_id,
  provider,
  provider_account_id,
  provider_data,
  created_at,
  updated_at
)
select
  gen_random_uuid(),
  seed_users.id,
  seed_users.auth_provider,
  seed_users.email,
  jsonb_build_object(
    'sub',
    seed_users.id::text,
    'email',
    seed_users.email
  ),
  now(),
  now()
from (
  values
    ('aaaaaaaa-1111-1111-1111-111111111111'::uuid, 'admin@phoenixrecovery.test', 'email'),
    ('aaaaaaaa-2222-2222-2222-222222222222'::uuid, 'priya@phoenixrecovery.test', 'email'),
    ('aaaaaaaa-3333-3333-3333-333333333333'::uuid, 'marco@phoenixrecovery.test', 'apple'),
    ('aaaaaaaa-4444-4444-4444-444444444444'::uuid, 'carmen@phoenixrecovery.test', 'apple'),
    ('aaaaaaaa-5555-5555-5555-555555555555'::uuid, 'drew@phoenixrecovery.test', 'email'),
    ('aaaaaaaa-6666-6666-6666-666666666666'::uuid, 'elena@phoenixrecovery.test', 'email'),
    ('bbbbbbbb-1111-1111-1111-111111111111'::uuid, 'admin@scottsdalewellness.test', 'email'),
    ('bbbbbbbb-2222-2222-2222-222222222222'::uuid, 'talia@scottsdalewellness.test', 'email'),
    ('bbbbbbbb-3333-3333-3333-333333333333'::uuid, 'noah@scottsdalewellness.test', 'apple'),
    ('bbbbbbbb-4444-4444-4444-444444444444'::uuid, 'mila@scottsdalewellness.test', 'apple'),
    ('bbbbbbbb-5555-5555-5555-555555555555'::uuid, 'owen@scottsdalewellness.test', 'email'),
    ('bbbbbbbb-6666-6666-6666-666666666666'::uuid, 'zoe@scottsdalewellness.test', 'email')
) as seed_users(id, email, auth_provider)
on conflict do nothing;

insert into public.users (id, clinic_id, role, email, full_name, auth_provider, phone)
values
  ('aaaaaaaa-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'admin', 'admin@phoenixrecovery.test', 'Avery Admin', 'email', '602-555-0101'),
  ('aaaaaaaa-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'practitioner', 'priya@phoenixrecovery.test', 'Priya Practitioner', 'email', '602-555-0102'),
  ('aaaaaaaa-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'practitioner', 'marco@phoenixrecovery.test', 'Marco Mobility', 'apple'),
  ('aaaaaaaa-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'client', 'carmen@phoenixrecovery.test', 'Carmen Client', 'apple'),
  ('aaaaaaaa-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', 'client', 'drew@phoenixrecovery.test', 'Drew Daily', 'email'),
  ('aaaaaaaa-6666-6666-6666-666666666666', '11111111-1111-1111-1111-111111111111', 'client', 'elena@phoenixrecovery.test', 'Elena Energy', 'email'),
  ('bbbbbbbb-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'admin', 'admin@scottsdalewellness.test', 'Sam Admin', 'email', '480-555-0201'),
  ('bbbbbbbb-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222', 'practitioner', 'talia@scottsdalewellness.test', 'Talia Trainer', 'email'),
  ('bbbbbbbb-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222', 'practitioner', 'noah@scottsdalewellness.test', 'Noah Recovery', 'apple'),
  ('bbbbbbbb-4444-4444-4444-444444444444', '22222222-2222-2222-2222-222222222222', 'client', 'mila@scottsdalewellness.test', 'Mila Mobility', 'apple'),
  ('bbbbbbbb-5555-5555-5555-555555555555', '22222222-2222-2222-2222-222222222222', 'client', 'owen@scottsdalewellness.test', 'Owen Output', 'email'),
  ('bbbbbbbb-6666-6666-6666-666666666666', '22222222-2222-2222-2222-222222222222', 'client', 'zoe@scottsdalewellness.test', 'Zoe Zen', 'email')
on conflict (id) do nothing;

alter table public.users enable trigger users_ensure_client_profile;

insert into public.client_profiles (
  id,
  user_id,
  clinic_id,
  primary_regions,
  recovery_signals,
  goals,
  activity_context,
  sensitivities,
  notes,
  wearable_hrv,
  wearable_strain,
  wearable_sleep_score,
  wearable_last_sync
)
values
  (
    'c1111111-1111-1111-1111-111111111111',
    'aaaaaaaa-4444-4444-4444-444444444444',
    '11111111-1111-1111-1111-111111111111',
    '["lower_back", "right_hip"]'::jsonb,
    '{"lower_back":{"type":"tightness","severity":7,"trigger":"morning"},"right_hip":{"type":"restriction","severity":6,"trigger":"after_running"}}'::jsonb,
    array['mobility', 'recovery']::text[],
    'Training for a half marathon and feeling stiffness after long runs.',
    array['heat_sensitive']::text[],
    'Prefers shorter pre-session guidance.',
    48.2,
    13.4,
    82,
    now() - interval '4 hours'
  ),
  (
    'c2222222-2222-2222-2222-222222222222',
    'aaaaaaaa-5555-5555-5555-555555555555',
    '11111111-1111-1111-1111-111111111111',
    '["neck", "upper_back"]'::jsonb,
    '{"neck":{"type":"soreness","severity":5,"trigger":"post_travel"},"upper_back":{"type":"guarding","severity":4,"trigger":"evening"}}'::jsonb,
    array['relaxation']::text[],
    'Desk-heavy work week and recent travel.',
    array[]::text[],
    null,
    39.1,
    9.8,
    74,
    now() - interval '1 day'
  ),
  (
    'c3333333-3333-3333-3333-333333333333',
    'aaaaaaaa-6666-6666-6666-666666666666',
    '11111111-1111-1111-1111-111111111111',
    '["left_knee"]'::jsonb,
    '{"left_knee":{"type":"stiffness","severity":6,"trigger":"after_lifting"}}'::jsonb,
    array['performance_prep']::text[],
    'Returning to lower-body strength work.',
    array['cold_sensitive']::text[],
    null,
    52.0,
    11.0,
    86,
    now() - interval '6 hours'
  ),
  (
    'd1111111-1111-1111-1111-111111111111',
    'bbbbbbbb-4444-4444-4444-444444444444',
    '22222222-2222-2222-2222-222222222222',
    '["left_shoulder", "right_arm"]'::jsonb,
    '{"left_shoulder":{"type":"restriction","severity":8,"trigger":"after_lifting"},"right_arm":{"type":"tightness","severity":4,"trigger":"general"}}'::jsonb,
    array['warm_up']::text[],
    'Preparing for overhead lifting sessions.',
    array[]::text[],
    null,
    44.7,
    15.2,
    79,
    now() - interval '10 hours'
  ),
  (
    'd2222222-2222-2222-2222-222222222222',
    'bbbbbbbb-5555-5555-5555-555555555555',
    '22222222-2222-2222-2222-222222222222',
    '["right_calf", "right_foot"]'::jsonb,
    '{"right_calf":{"type":"soreness","severity":5,"trigger":"post_training"},"right_foot":{"type":"tightness","severity":3,"trigger":"morning"}}'::jsonb,
    array['recovery']::text[],
    'Coming off a long cycling block.',
    array[]::text[],
    null,
    50.5,
    12.3,
    88,
    now() - interval '8 hours'
  ),
  (
    'd3333333-3333-3333-3333-333333333333',
    'bbbbbbbb-6666-6666-6666-666666666666',
    '22222222-2222-2222-2222-222222222222',
    '["lower_back"]'::jsonb,
    '{"lower_back":{"type":"guarding","severity":6,"trigger":"after_running"}}'::jsonb,
    array['mobility']::text[],
    'Restarting movement work after a break.',
    array['vibration_sensitive']::text[],
    null,
    41.9,
    8.7,
    77,
    now() - interval '2 days'
  )
on conflict (id) do nothing;

insert into public.devices (
  id,
  clinic_id,
  device_mac,
  label,
  room,
  assigned_practitioner,
  status,
  firmware,
  last_seen_at
)
values
  ('de111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'AA:BB:CC:11:22:33', 'Hydra Bay 1', 'Room A', 'aaaaaaaa-2222-2222-2222-222222222222', 'idle', '1.0.4', now() - interval '2 minutes'),
  ('de222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'AA:BB:CC:11:22:44', 'Hydra Bay 2', 'Room B', 'aaaaaaaa-3333-3333-3333-333333333333', 'maintenance', '1.0.3', now() - interval '1 hour'),
  ('de333333-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222', 'DD:EE:FF:55:66:77', 'Scottsdale Pod 1', 'North Room', 'bbbbbbbb-2222-2222-2222-222222222222', 'in_session', '1.0.5', now() - interval '30 seconds'),
  ('de444444-4444-4444-4444-444444444444', '22222222-2222-2222-2222-222222222222', 'DD:EE:FF:55:66:88', 'Scottsdale Pod 2', 'South Room', 'bbbbbbbb-3333-3333-3333-333333333333', 'offline', '1.0.2', now() - interval '3 hours')
on conflict (id) do nothing;

insert into public.assessments (
  id,
  client_id,
  clinic_id,
  practitioner_id,
  assessment_type,
  quickpose_data,
  rom_values,
  asymmetry_scores,
  movement_quality_scores,
  gait_metrics,
  heart_rate,
  hrv_rmssd,
  body_zones,
  recovery_goal,
  subjective_baseline,
  recovery_map,
  recovery_graph_delta,
  created_at
)
values
  (
    'as111111-1111-1111-1111-111111111111',
    'c1111111-1111-1111-1111-111111111111',
    '11111111-1111-1111-1111-111111111111',
    'aaaaaaaa-2222-2222-2222-222222222222',
    'intake',
    '{"capturedAt":"2026-04-16T17:15:00Z","jointAngles":{"right_hip_flexion":108.0},"romValues":{"right_hip_flexion":118.0},"asymmetryScores":{"hip_flexion":9.4},"movementQuality":{"hip_hinge":0.72}}'::jsonb,
    '{"right_hip_flexion":118.0,"lumbar_flexion":74.0}'::jsonb,
    '{"hip_flexion":9.4}'::jsonb,
    '{"hip_hinge":0.72}'::jsonb,
    '{"cadence":98.0,"stepSymmetry":0.93,"stepLength":0.68}'::jsonb,
    64,
    42,
    '[{"region":"lower_back"},{"region":"right_hip"}]'::jsonb,
    'mobility',
    '{"stiffness":7,"soreness":5}'::jsonb,
    '{"highlightedRegions":[{"region":"lower_back","severity":7,"signalType":"tightness","romDelta":-6.0,"asymmetryFlag":false}],"suggestedGoal":"mobility","generatedAt":"2026-04-16T17:16:00Z"}'::jsonb,
    '{"recovery_score":-4.0}'::jsonb,
    now() - interval '2 days'
  ),
  (
    'as222222-2222-2222-2222-222222222222',
    'c2222222-2222-2222-2222-222222222222',
    '11111111-1111-1111-1111-111111111111',
    'aaaaaaaa-3333-3333-3333-333333333333',
    'pre_session',
    '{"capturedAt":"2026-04-17T09:45:00Z","jointAngles":{"neck_rotation":42.0},"romValues":{"left_shoulder_flexion":146.0},"asymmetryScores":{"shoulder_flexion":5.2},"movementQuality":{"squat":0.78}}'::jsonb,
    '{"left_shoulder_flexion":146.0,"right_shoulder_flexion":154.0}'::jsonb,
    '{"shoulder_flexion":5.2}'::jsonb,
    '{"squat":0.78}'::jsonb,
    '{"cadence":101.0,"stepSymmetry":0.97,"stepLength":0.71}'::jsonb,
    61,
    38,
    '[{"region":"neck"},{"region":"upper_back"}]'::jsonb,
    'relaxation',
    '{"stiffness":5,"soreness":4}'::jsonb,
    '{"highlightedRegions":[{"region":"neck","severity":5,"signalType":"soreness","romDelta":-2.0,"asymmetryFlag":false}],"suggestedGoal":"relaxation","generatedAt":"2026-04-17T09:46:00Z"}'::jsonb,
    '{"recovery_score":1.0}'::jsonb,
    now() - interval '1 day'
  ),
  (
    'as333333-3333-3333-3333-333333333333',
    'd1111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222222',
    'bbbbbbbb-2222-2222-2222-222222222222',
    'intake',
    '{"capturedAt":"2026-04-17T16:10:00Z","jointAngles":{"left_shoulder_flexion":122.0},"romValues":{"left_shoulder_flexion":138.0},"asymmetryScores":{"shoulder_flexion":12.6},"movementQuality":{"squat":0.69}}'::jsonb,
    '{"left_shoulder_flexion":138.0,"right_shoulder_flexion":158.0}'::jsonb,
    '{"shoulder_flexion":12.6}'::jsonb,
    '{"squat":0.69}'::jsonb,
    '{"cadence":96.0,"stepSymmetry":0.9,"stepLength":0.65}'::jsonb,
    68,
    35,
    '[{"region":"left_shoulder"}]'::jsonb,
    'warm_up',
    '{"stiffness":6,"soreness":3}'::jsonb,
    '{"highlightedRegions":[{"region":"left_shoulder","severity":8,"signalType":"restriction","romDelta":-10.0,"asymmetryFlag":true}],"suggestedGoal":"warm_up","generatedAt":"2026-04-17T16:11:00Z"}'::jsonb,
    '{"recovery_score":-6.0}'::jsonb,
    now() - interval '20 hours'
  )
on conflict (id) do nothing;

insert into public.sessions (
  id,
  client_id,
  clinic_id,
  practitioner_id,
  device_id,
  assessment_id,
  session_config,
  recommended_config,
  practitioner_edits,
  recommendation_rationale,
  confidence_score,
  status,
  started_at,
  completed_at,
  total_duration_s,
  outcome,
  practitioner_notes,
  retest_values,
  created_at
)
values
  (
    'se111111-1111-1111-1111-111111111111',
    'c1111111-1111-1111-1111-111111111111',
    '11111111-1111-1111-1111-111111111111',
    'aaaaaaaa-2222-2222-2222-222222222222',
    'de111111-1111-1111-1111-111111111111',
    'as111111-1111-1111-1111-111111111111',
    '{"mac":"AA:BB:CC:11:22:33","playCmd":1,"sessionCount":1,"pwmValues":{"hot":90,"cold":180},"vibMin":15,"vibMax":120,"hotDrop":3,"coldDrop":2,"edgeCycleDuration":8,"totalDuration":1200}'::jsonb,
    '{"pwmValues":{"hot":88,"cold":182}}'::jsonb,
    '{"pwmValues":{"hot":90}}'::jsonb,
    'Lower-back mobility emphasis based on intake and ROM delta.',
    0.84,
    'completed',
    now() - interval '2 days' + interval '1 hour',
    now() - interval '2 days' + interval '1 hour 20 minutes',
    1200,
    '{"summary":"Completed without interruption"}'::jsonb,
    'Client tolerated session well.',
    '{"lumbar_flexion":79.0}'::jsonb,
    now() - interval '2 days'
  ),
  (
    'se222222-2222-2222-2222-222222222222',
    'c2222222-2222-2222-2222-222222222222',
    '11111111-1111-1111-1111-111111111111',
    'aaaaaaaa-3333-3333-3333-333333333333',
    'de222222-2222-2222-2222-222222222222',
    'as222222-2222-2222-2222-222222222222',
    '{"mac":"AA:BB:CC:11:22:44","playCmd":1,"sessionCount":1,"pwmValues":{"hot":70,"cold":165},"vibMin":12,"vibMax":110,"hotDrop":2,"coldDrop":2,"edgeCycleDuration":7,"totalDuration":900}'::jsonb,
    '{"pwmValues":{"hot":68,"cold":160}}'::jsonb,
    '{"sessionPause":30}'::jsonb,
    'Short reset session for neck and upper-back travel stiffness.',
    0.78,
    'completed',
    now() - interval '1 day' + interval '2 hours',
    now() - interval '1 day' + interval '2 hours 15 minutes',
    900,
    '{"summary":"Completed with reduced thermal intensity"}'::jsonb,
    'Reduced heat slightly for comfort.',
    '{"left_shoulder_flexion":150.0}'::jsonb,
    now() - interval '1 day'
  ),
  (
    'se333333-3333-3333-3333-333333333333',
    'd1111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222222',
    'bbbbbbbb-2222-2222-2222-222222222222',
    'de333333-3333-3333-3333-333333333333',
    'as333333-3333-3333-3333-333333333333',
    '{"mac":"DD:EE:FF:55:66:77","playCmd":1,"sessionCount":1,"pwmValues":{"hot":82,"cold":172},"vibMin":14,"vibMax":118,"hotDrop":3,"coldDrop":2,"edgeCycleDuration":9,"totalDuration":1020}'::jsonb,
    '{"pwmValues":{"hot":80,"cold":170}}'::jsonb,
    '{"led":1}'::jsonb,
    'Warm-up session for overhead training readiness.',
    0.81,
    'active',
    now() - interval '10 minutes',
    null,
    null,
    null,
    'Currently in progress.',
    null,
    now() - interval '10 minutes'
  )
on conflict (id) do nothing;

update public.devices
set last_session_id = case id
  when 'de111111-1111-1111-1111-111111111111' then 'se111111-1111-1111-1111-111111111111'::uuid
  when 'de222222-2222-2222-2222-222222222222' then 'se222222-2222-2222-2222-222222222222'::uuid
  when 'de333333-3333-3333-3333-333333333333' then 'se333333-3333-3333-3333-333333333333'::uuid
  else last_session_id
end
where id in (
  'de111111-1111-1111-1111-111111111111',
  'de222222-2222-2222-2222-222222222222',
  'de333333-3333-3333-3333-333333333333'
);

insert into public.outcomes (
  id,
  session_id,
  client_id,
  clinic_id,
  recorded_by,
  recorded_by_user_id,
  stiffness_before,
  stiffness_after,
  soreness_before,
  soreness_after,
  mobility_improved,
  session_effective,
  readiness_improved,
  repeat_intent,
  rom_after,
  rom_delta,
  client_notes,
  practitioner_notes,
  created_at
)
values
  (
    'ou111111-1111-1111-1111-111111111111',
    'se111111-1111-1111-1111-111111111111',
    'c1111111-1111-1111-1111-111111111111',
    '11111111-1111-1111-1111-111111111111',
    'client',
    'aaaaaaaa-4444-4444-4444-444444444444',
    7,
    3,
    5,
    2,
    'yes',
    'yes',
    'yes',
    'yes',
    '{"lumbar_flexion":79.0}'::jsonb,
    '{"lumbar_flexion":5.0}'::jsonb,
    'Felt more open through the hips after the session.',
    null,
    now() - interval '2 days' + interval '1 hour 25 minutes'
  ),
  (
    'ou222222-2222-2222-2222-222222222222',
    'se111111-1111-1111-1111-111111111111',
    'c1111111-1111-1111-1111-111111111111',
    '11111111-1111-1111-1111-111111111111',
    'practitioner',
    'aaaaaaaa-2222-2222-2222-222222222222',
    7,
    4,
    5,
    3,
    'yes',
    'yes',
    'yes',
    'yes',
    '{"lumbar_flexion":79.0}'::jsonb,
    '{"lumbar_flexion":5.0}'::jsonb,
    null,
    'Improved hip drive and lower-back ease after session.',
    now() - interval '2 days' + interval '1 hour 30 minutes'
  ),
  (
    'ou333333-3333-3333-3333-333333333333',
    'se222222-2222-2222-2222-222222222222',
    'c2222222-2222-2222-2222-222222222222',
    '11111111-1111-1111-1111-111111111111',
    'client',
    'aaaaaaaa-5555-5555-5555-555555555555',
    5,
    2,
    4,
    2,
    'yes',
    'maybe',
    'yes',
    'maybe',
    '{"left_shoulder_flexion":150.0}'::jsonb,
    '{"left_shoulder_flexion":4.0}'::jsonb,
    'Travel stiffness eased by the evening.',
    null,
    now() - interval '23 hours'
  )
on conflict (id) do nothing;

insert into public.recovery_graph (
  id,
  client_id,
  clinic_id,
  body_region,
  metric_type,
  value,
  source,
  source_id,
  recorded_at,
  created_at
)
values
  ('rg111111-1111-1111-1111-111111111111', 'c1111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'overall', 'recovery_score', 68, 'assessment', 'as111111-1111-1111-1111-111111111111', now() - interval '2 days', now() - interval '2 days'),
  ('rg111112-1111-1111-1111-111111111111', 'c1111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'overall', 'recovery_score', 74, 'outcome', 'ou111111-1111-1111-1111-111111111111', now() - interval '2 days' + interval '90 minutes', now() - interval '2 days' + interval '90 minutes'),
  ('rg222221-2222-2222-2222-222222222222', 'c2222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'overall', 'recovery_score', 71, 'assessment', 'as222222-2222-2222-2222-222222222222', now() - interval '1 day', now() - interval '1 day'),
  ('rg222222-2222-2222-2222-222222222222', 'c2222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'neck', 'rom_delta', 4, 'outcome', 'ou333333-3333-3333-3333-333333333333', now() - interval '23 hours', now() - interval '23 hours'),
  ('rg333331-3333-3333-3333-333333333333', 'd1111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'overall', 'recovery_score', 62, 'assessment', 'as333333-3333-3333-3333-333333333333', now() - interval '20 hours', now() - interval '20 hours'),
  ('rg333332-3333-3333-3333-333333333333', 'd1111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'left_shoulder', 'rom_delta', -10, 'assessment', 'as333333-3333-3333-3333-333333333333', now() - interval '20 hours', now() - interval '20 hours')
on conflict (id) do nothing;

insert into public.daily_checkins (
  id,
  client_id,
  clinic_id,
  checkin_type,
  overall_feeling,
  target_regions,
  activity_since_last,
  recovery_score,
  created_at
)
values
  (
    'ch111111-1111-1111-1111-111111111111',
    'c1111111-1111-1111-1111-111111111111',
    '11111111-1111-1111-1111-111111111111',
    'daily',
    4,
    '[{"region":"lower_back","status":"looser"},{"region":"right_hip","status":"steady"}]'::jsonb,
    'Easy recovery walk and mobility work.',
    74,
    now() - interval '1 day'
  ),
  (
    'ch222222-2222-2222-2222-222222222222',
    'c2222222-2222-2222-2222-222222222222',
    '11111111-1111-1111-1111-111111111111',
    'daily',
    3,
    '[{"region":"neck","status":"improving"}]'::jsonb,
    'Long travel day with extra desk time.',
    70,
    now() - interval '12 hours'
  ),
  (
    'ch333333-3333-3333-3333-333333333333',
    'd1111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222222',
    'daily',
    4,
    '[{"region":"left_shoulder","status":"warming up"}]'::jsonb,
    'Upper-body training prep.',
    64,
    now() - interval '6 hours'
  )
on conflict (id) do nothing;

insert into public.clinic_hw_tokens (
  id,
  clinic_id,
  access_token,
  refresh_token,
  access_token_expires_at,
  refresh_token_expires_at
)
values
  ('tk111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'phoenix-access-token', 'phoenix-refresh-token', now() + interval '1 hour', now() + interval '30 days'),
  ('tk222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222', 'scottsdale-access-token', 'scottsdale-refresh-token', now() + interval '1 hour', now() + interval '30 days')
on conflict (clinic_id) do update
set access_token = excluded.access_token,
    refresh_token = excluded.refresh_token,
    access_token_expires_at = excluded.access_token_expires_at,
    refresh_token_expires_at = excluded.refresh_token_expires_at,
    updated_at = now();

insert into public.mqtt_command_log (
  id,
  clinic_id,
  device_id,
  command,
  payload,
  mqtt_response_status,
  error_details,
  simulated,
  created_by,
  created_at
)
values
  (
    'mq111111-1111-1111-1111-111111111111',
    '11111111-1111-1111-1111-111111111111',
    'de111111-1111-1111-1111-111111111111',
    'start',
    '{"mac":"AA:BB:CC:11:22:33","playCmd":1,"totalDuration":1200}'::jsonb,
    200,
    null,
    true,
    'aaaaaaaa-2222-2222-2222-222222222222',
    now() - interval '2 days' + interval '1 hour'
  ),
  (
    'mq222222-2222-2222-2222-222222222222',
    '22222222-2222-2222-2222-222222222222',
    'de333333-3333-3333-3333-333333333333',
    'start',
    '{"mac":"DD:EE:FF:55:66:77","playCmd":1,"totalDuration":1020}'::jsonb,
    200,
    null,
    false,
    'bbbbbbbb-2222-2222-2222-222222222222',
    now() - interval '10 minutes'
  )
on conflict (id) do nothing;

insert into public.clinic_invites (
  id,
  clinic_id,
  role,
  invite_code,
  email,
  invited_by,
  expires_at
)
values
  ('iv111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'client', 'PHXCLIENT', null, 'aaaaaaaa-1111-1111-1111-111111111111', now() + interval '30 days'),
  ('iv222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'practitioner', 'PHXPRACT', 'next-prac@phoenixrecovery.test', 'aaaaaaaa-1111-1111-1111-111111111111', now() + interval '14 days'),
  ('iv333333-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222', 'client', 'SCOTTSDALE1', null, 'bbbbbbbb-1111-1111-1111-111111111111', now() + interval '30 days')
on conflict (id) do nothing;
