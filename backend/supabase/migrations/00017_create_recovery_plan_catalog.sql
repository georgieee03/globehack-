create or replace function public.validate_enum_array(p_values text[], p_allowed text[])
returns boolean
language sql
immutable
as $$
  select coalesce(p_values, '{}'::text[]) <@ p_allowed;
$$;

create table if not exists public.exercise_videos (
  id text primary key,
  source_slug text not null
    check (source_slug in ('hinge_health', 'ask_doctor_jo', 'hospital_for_special_surgery')),
  source_domain text not null
    check (source_domain in ('hingehealth.com', 'askdoctorjo.com', 'hss.edu')),
  canonical_url text not null unique,
  thumbnail_url text,
  playback_mode text not null
    check (playback_mode in ('in_app_browser', 'embedded_web', 'external_browser')),
  content_host text not null
    check (content_host in ('youtube', 'professional_platform')),
  title text not null,
  creator_name text not null,
  creator_credentials text not null,
  source_quality_tier text not null
    check (source_quality_tier in ('academic_medical', 'pt_reviewed_platform', 'licensed_pt_creator', 'fitness_educator')),
  language text not null default 'en',
  duration_sec integer,
  body_regions text[] not null default '{}'::text[],
  symptom_tags text[] not null default '{}'::text[],
  movement_tags text[] not null default '{}'::text[],
  goal_tags text[] not null default '{}'::text[],
  equipment_tags text[] not null default '{}'::text[],
  activity_trigger_tags text[] not null default '{}'::text[],
  level text,
  contraindication_tags text[] not null default '{}'::text[],
  practitioner_notes text,
  hydrawav_pairing jsonb,
  quality_score numeric not null default 0.8,
  confidence_score numeric not null default 0.8,
  human_review_status text not null default 'pending_review'
    check (human_review_status in ('pending_review', 'approved', 'rejected', 'archived')),
  last_reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint exercise_videos_duration_chk
    check (duration_sec is null or duration_sec >= 0),
  constraint exercise_videos_body_regions_chk
    check (
      public.validate_enum_array(
        body_regions,
        array[
          'right_shoulder',
          'left_shoulder',
          'right_hip',
          'left_hip',
          'lower_back',
          'upper_back',
          'right_knee',
          'left_knee',
          'neck',
          'right_calf',
          'left_calf',
          'right_arm',
          'left_arm',
          'right_foot',
          'left_foot'
        ]::text[]
      )
    ),
  constraint exercise_videos_symptom_tags_chk
    check (
      public.validate_enum_array(
        symptom_tags,
        array[
          'stiffness',
          'soreness',
          'tightness',
          'restriction',
          'guarding',
          'post_activity_discomfort'
        ]::text[]
      )
    ),
  constraint exercise_videos_goal_tags_chk
    check (
      public.validate_enum_array(
        goal_tags,
        array[
          'mobility',
          'warm_up',
          'recovery',
          'relaxation',
          'performance_prep'
        ]::text[]
      )
    ),
  constraint exercise_videos_trigger_tags_chk
    check (
      public.validate_enum_array(
        activity_trigger_tags,
        array[
          'morning',
          'after_running',
          'after_lifting',
          'post_travel',
          'post_training',
          'evening',
          'general'
        ]::text[]
      )
    ),
  constraint exercise_videos_quality_score_chk
    check (quality_score between 0 and 1),
  constraint exercise_videos_confidence_score_chk
    check (confidence_score between 0 and 1),
  constraint exercise_videos_pairing_chk
    check (hydrawav_pairing is null or jsonb_typeof(hydrawav_pairing) = 'object')
);

create table if not exists public.exercise_recommendation_rules (
  id text primary key,
  region text not null
    check (public.is_valid_body_region(region)),
  symptom text not null
    check (symptom in ('stiffness', 'soreness', 'tightness', 'restriction', 'guarding', 'post_activity_discomfort')),
  evidence_tier text not null
    check (evidence_tier in ('direct', 'mirrored', 'schema_supported', 'derived')),
  goal_tags text[] not null default '{}'::text[],
  activity_trigger_tags text[] not null default '{}'::text[],
  hydrawav_pairing jsonb,
  practitioner_note text,
  quality_score numeric not null default 0.8,
  confidence_score numeric not null default 0.8,
  human_review_status text not null default 'pending_review'
    check (human_review_status in ('pending_review', 'approved', 'rejected', 'archived')),
  last_reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint exercise_rules_goal_tags_chk
    check (
      public.validate_enum_array(
        goal_tags,
        array[
          'mobility',
          'warm_up',
          'recovery',
          'relaxation',
          'performance_prep'
        ]::text[]
      )
    ),
  constraint exercise_rules_trigger_tags_chk
    check (
      public.validate_enum_array(
        activity_trigger_tags,
        array[
          'morning',
          'after_running',
          'after_lifting',
          'post_travel',
          'post_training',
          'evening',
          'general'
        ]::text[]
      )
    ),
  constraint exercise_rules_quality_score_chk
    check (quality_score between 0 and 1),
  constraint exercise_rules_confidence_score_chk
    check (confidence_score between 0 and 1),
  constraint exercise_rules_pairing_chk
    check (hydrawav_pairing is null or jsonb_typeof(hydrawav_pairing) = 'object')
);

create table if not exists public.exercise_recommendation_rule_items (
  id uuid primary key default gen_random_uuid(),
  rule_id text not null references public.exercise_recommendation_rules(id) on delete cascade,
  exercise_video_id text not null references public.exercise_videos(id) on delete restrict,
  sort_order integer not null default 1,
  display_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint exercise_rule_items_sort_order_chk
    check (sort_order >= 1),
  constraint exercise_rule_items_unique_sort_uidx
    unique (rule_id, sort_order),
  constraint exercise_rule_items_unique_video_uidx
    unique (rule_id, exercise_video_id)
);

create table if not exists public.recovery_plans (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.client_profiles(id) on delete cascade,
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  source_assessment_id uuid references public.assessments(id) on delete set null,
  status text not null default 'active'
    check (status in ('active', 'superseded', 'paused_for_safety', 'completed', 'archived')),
  refresh_reason text not null
    check (refresh_reason in ('initial_intake', 'goal_change', 'signal_change', 'assessment_change', 'stale_plan', 'manual_refresh')),
  summary text not null,
  activity_context text,
  generation_context jsonb not null default '{}'::jsonb,
  safety_pause_reason text,
  paused_for_safety_at timestamptz,
  superseded_at timestamptz,
  superseded_by_plan_id uuid references public.recovery_plans(id) on delete set null,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint recovery_plans_generation_context_chk
    check (jsonb_typeof(generation_context) = 'object')
);

create table if not exists public.recovery_plan_items (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.recovery_plans(id) on delete cascade,
  exercise_video_id text not null references public.exercise_videos(id) on delete restrict,
  position integer not null,
  item_role text not null
    check (item_role in ('required', 'optional_support')),
  region text not null
    check (public.is_valid_body_region(region)),
  symptom text not null
    check (symptom in ('stiffness', 'soreness', 'tightness', 'restriction', 'guarding', 'post_activity_discomfort')),
  cadence text not null
    check (cadence in ('daily', 'post_activity', 'morning', 'evening')),
  weekly_target_count integer not null default 7,
  rationale text not null,
  display_notes text,
  hydrawav_pairing jsonb not null,
  source_slug text not null
    check (source_slug in ('hinge_health', 'ask_doctor_jo', 'hospital_for_special_surgery')),
  source_domain text not null
    check (source_domain in ('hingehealth.com', 'askdoctorjo.com', 'hss.edu')),
  title text not null,
  canonical_url text not null,
  thumbnail_url text,
  playback_mode text not null
    check (playback_mode in ('in_app_browser', 'embedded_web', 'external_browser')),
  content_host text not null
    check (content_host in ('youtube', 'professional_platform')),
  creator_name text not null,
  creator_credentials text not null,
  source_quality_tier text not null
    check (source_quality_tier in ('academic_medical', 'pt_reviewed_platform', 'licensed_pt_creator', 'fitness_educator')),
  language text not null default 'en',
  duration_sec integer,
  level text,
  body_regions text[] not null default '{}'::text[],
  symptom_tags text[] not null default '{}'::text[],
  movement_tags text[] not null default '{}'::text[],
  goal_tags text[] not null default '{}'::text[],
  equipment_tags text[] not null default '{}'::text[],
  activity_trigger_tags text[] not null default '{}'::text[],
  contraindication_tags text[] not null default '{}'::text[],
  practitioner_notes text,
  quality_score numeric not null default 0.8,
  confidence_score numeric not null default 0.8,
  human_review_status text not null default 'approved'
    check (human_review_status in ('pending_review', 'approved', 'rejected', 'archived')),
  last_reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint recovery_plan_items_position_chk
    check (position >= 1),
  constraint recovery_plan_items_weekly_target_chk
    check (weekly_target_count >= 0),
  constraint recovery_plan_items_pairing_chk
    check (jsonb_typeof(hydrawav_pairing) = 'object'),
  constraint recovery_plan_items_duration_chk
    check (duration_sec is null or duration_sec >= 0),
  constraint recovery_plan_items_body_regions_chk
    check (
      public.validate_enum_array(
        body_regions,
        array[
          'right_shoulder',
          'left_shoulder',
          'right_hip',
          'left_hip',
          'lower_back',
          'upper_back',
          'right_knee',
          'left_knee',
          'neck',
          'right_calf',
          'left_calf',
          'right_arm',
          'left_arm',
          'right_foot',
          'left_foot'
        ]::text[]
      )
    ),
  constraint recovery_plan_items_symptom_tags_chk
    check (
      public.validate_enum_array(
        symptom_tags,
        array[
          'stiffness',
          'soreness',
          'tightness',
          'restriction',
          'guarding',
          'post_activity_discomfort'
        ]::text[]
      )
    ),
  constraint recovery_plan_items_goal_tags_chk
    check (
      public.validate_enum_array(
        goal_tags,
        array[
          'mobility',
          'warm_up',
          'recovery',
          'relaxation',
          'performance_prep'
        ]::text[]
      )
    ),
  constraint recovery_plan_items_trigger_tags_chk
    check (
      public.validate_enum_array(
        activity_trigger_tags,
        array[
          'morning',
          'after_running',
          'after_lifting',
          'post_travel',
          'post_training',
          'evening',
          'general'
        ]::text[]
      )
    ),
  constraint recovery_plan_items_quality_score_chk
    check (quality_score between 0 and 1),
  constraint recovery_plan_items_confidence_score_chk
    check (confidence_score between 0 and 1),
  constraint recovery_plan_items_plan_position_uidx
    unique (plan_id, position)
);

create table if not exists public.recovery_plan_completion_logs (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.recovery_plans(id) on delete cascade,
  plan_item_id uuid not null references public.recovery_plan_items(id) on delete cascade,
  status text not null
    check (status in ('started', 'completed', 'skipped', 'stopped')),
  tolerance_rating integer,
  difficulty_rating integer,
  symptom_response text
    check (symptom_response in ('better', 'same', 'worse')),
  notes text,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint recovery_plan_completion_logs_tolerance_chk
    check (tolerance_rating is null or tolerance_rating between 1 and 5),
  constraint recovery_plan_completion_logs_difficulty_chk
    check (difficulty_rating is null or difficulty_rating between 1 and 5)
);

create index if not exists exercise_videos_review_status_idx
  on public.exercise_videos (human_review_status, confidence_score desc);

create index if not exists exercise_videos_source_slug_idx
  on public.exercise_videos (source_slug, source_domain);

create index if not exists exercise_videos_body_regions_gin_idx
  on public.exercise_videos
  using gin (body_regions);

create index if not exists exercise_videos_symptom_tags_gin_idx
  on public.exercise_videos
  using gin (symptom_tags);

create index if not exists exercise_rules_lookup_idx
  on public.exercise_recommendation_rules (region, symptom, human_review_status, confidence_score desc);

create index if not exists recovery_plans_client_status_idx
  on public.recovery_plans (client_id, status, created_at desc);

create unique index if not exists recovery_plans_active_client_uidx
  on public.recovery_plans (client_id)
  where status = 'active';

create index if not exists recovery_plan_items_plan_idx
  on public.recovery_plan_items (plan_id, position);

create index if not exists recovery_plan_completion_logs_plan_idx
  on public.recovery_plan_completion_logs (plan_id, created_at desc);

create index if not exists recovery_plan_completion_logs_item_idx
  on public.recovery_plan_completion_logs (plan_item_id, created_at desc);

drop trigger if exists set_exercise_videos_updated_at on public.exercise_videos;
create trigger set_exercise_videos_updated_at
before update on public.exercise_videos
for each row
execute function public.set_updated_at();

drop trigger if exists set_exercise_recommendation_rules_updated_at on public.exercise_recommendation_rules;
create trigger set_exercise_recommendation_rules_updated_at
before update on public.exercise_recommendation_rules
for each row
execute function public.set_updated_at();

drop trigger if exists set_exercise_recommendation_rule_items_updated_at on public.exercise_recommendation_rule_items;
create trigger set_exercise_recommendation_rule_items_updated_at
before update on public.exercise_recommendation_rule_items
for each row
execute function public.set_updated_at();

drop trigger if exists recovery_plans_sync_clinic_id on public.recovery_plans;
create trigger recovery_plans_sync_clinic_id
before insert or update on public.recovery_plans
for each row
execute function public.sync_clinic_id_from_client_profile();

drop trigger if exists set_recovery_plans_updated_at on public.recovery_plans;
create trigger set_recovery_plans_updated_at
before update on public.recovery_plans
for each row
execute function public.set_updated_at();

drop trigger if exists set_recovery_plan_items_updated_at on public.recovery_plan_items;
create trigger set_recovery_plan_items_updated_at
before update on public.recovery_plan_items
for each row
execute function public.set_updated_at();

drop trigger if exists set_recovery_plan_completion_logs_updated_at on public.recovery_plan_completion_logs;
create trigger set_recovery_plan_completion_logs_updated_at
before update on public.recovery_plan_completion_logs
for each row
execute function public.set_updated_at();

alter table public.exercise_videos enable row level security;
alter table public.exercise_recommendation_rules enable row level security;
alter table public.exercise_recommendation_rule_items enable row level security;
alter table public.recovery_plans enable row level security;
alter table public.recovery_plan_items enable row level security;
alter table public.recovery_plan_completion_logs enable row level security;

create policy exercise_videos_select_admin
on public.exercise_videos
for select
using (public.current_user_role() = 'admin');

create policy exercise_videos_insert_admin
on public.exercise_videos
for insert
with check (public.current_user_role() = 'admin');

create policy exercise_videos_update_admin
on public.exercise_videos
for update
using (public.current_user_role() = 'admin')
with check (public.current_user_role() = 'admin');

create policy exercise_videos_delete_admin
on public.exercise_videos
for delete
using (public.current_user_role() = 'admin');

create policy exercise_rules_select_admin
on public.exercise_recommendation_rules
for select
using (public.current_user_role() = 'admin');

create policy exercise_rules_insert_admin
on public.exercise_recommendation_rules
for insert
with check (public.current_user_role() = 'admin');

create policy exercise_rules_update_admin
on public.exercise_recommendation_rules
for update
using (public.current_user_role() = 'admin')
with check (public.current_user_role() = 'admin');

create policy exercise_rules_delete_admin
on public.exercise_recommendation_rules
for delete
using (public.current_user_role() = 'admin');

create policy exercise_rule_items_select_admin
on public.exercise_recommendation_rule_items
for select
using (public.current_user_role() = 'admin');

create policy exercise_rule_items_insert_admin
on public.exercise_recommendation_rule_items
for insert
with check (public.current_user_role() = 'admin');

create policy exercise_rule_items_update_admin
on public.exercise_recommendation_rule_items
for update
using (public.current_user_role() = 'admin')
with check (public.current_user_role() = 'admin');

create policy exercise_rule_items_delete_admin
on public.exercise_recommendation_rule_items
for delete
using (public.current_user_role() = 'admin');

create policy recovery_plans_select_own
on public.recovery_plans
for select
using (client_id = public.current_user_client_profile_id());

create policy recovery_plans_select_clinic_staff
on public.recovery_plans
for select
using (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() in ('practitioner', 'admin')
);

create policy recovery_plan_items_select_own
on public.recovery_plan_items
for select
using (
  exists (
    select 1
    from public.recovery_plans
    where recovery_plans.id = recovery_plan_items.plan_id
      and recovery_plans.client_id = public.current_user_client_profile_id()
  )
);

create policy recovery_plan_items_select_clinic_staff
on public.recovery_plan_items
for select
using (
  exists (
    select 1
    from public.recovery_plans
    where recovery_plans.id = recovery_plan_items.plan_id
      and recovery_plans.clinic_id = public.current_user_clinic_id()
      and public.current_user_role() in ('practitioner', 'admin')
  )
);

create policy recovery_plan_completion_logs_select_own
on public.recovery_plan_completion_logs
for select
using (
  exists (
    select 1
    from public.recovery_plans
    where recovery_plans.id = recovery_plan_completion_logs.plan_id
      and recovery_plans.client_id = public.current_user_client_profile_id()
  )
);

create policy recovery_plan_completion_logs_select_clinic_staff
on public.recovery_plan_completion_logs
for select
using (
  exists (
    select 1
    from public.recovery_plans
    where recovery_plans.id = recovery_plan_completion_logs.plan_id
      and recovery_plans.clinic_id = public.current_user_clinic_id()
      and public.current_user_role() in ('practitioner', 'admin')
  )
);

insert into public.exercise_videos (
  id, source_slug, source_domain, canonical_url, playback_mode, content_host, title, creator_name, creator_credentials,
  source_quality_tier, language, duration_sec, body_regions, symptom_tags, movement_tags,
  goal_tags, equipment_tags, activity_trigger_tags, level, contraindication_tags,
  practitioner_notes, hydrawav_pairing, quality_score, confidence_score, human_review_status,
  last_reviewed_at
) values
  ('V01', 'hinge_health', 'hingehealth.com', 'https://www.hingehealth.com/resources/articles/wall-slides/', 'in_app_browser', 'professional_platform', 'Wall Slides', 'Hinge Health Learning Center', 'PT-reviewed, doctorate-level physical therapy team', 'pt_reviewed_platform', 'en', null, array['right_shoulder','left_shoulder','upper_back'], array['stiffness','restriction','tightness'], array['wall_slide','scapular_upward_rotation','shoulder_mobility'], array['mobility','warm_up','recovery'], array[]::text[], array['general','post_training'], 'beginner', array['acute_dislocation','instability','sharp_overhead_pain'], 'Use after low-load shoulder mobility or as a guided warm-up.', null, 0.92, 0.91, 'approved', now()),
  ('V02', 'hinge_health', 'hingehealth.com', 'https://www.hingehealth.com/gb/en/resources/articles/scapular-squeezes/', 'in_app_browser', 'professional_platform', 'Scapular Squeezes', 'Hinge Health Learning Center', 'PT-reviewed, doctorate-level physical therapy team', 'pt_reviewed_platform', 'en', null, array['right_shoulder','left_shoulder','upper_back','neck'], array['stiffness','tightness','guarding'], array['scapular_retraction','posture','upper_back_control'], array['mobility','recovery','relaxation'], array[]::text[], array['general','morning','evening'], 'beginner', array['acute_shoulder_trauma','sharp_posterior_shoulder_pain'], 'Strong support movement for shoulder, neck, and upper-back tension patterns.', null, 0.9, 0.89, 'approved', now()),
  ('V03', 'ask_doctor_jo', 'askdoctorjo.com', 'https://www.askdoctorjo.com/codman-pendulum-circles/', 'in_app_browser', 'professional_platform', 'Codman Pendulum Circles', 'Ask Doctor Jo', 'Physical Therapist, Doctor of Physical Therapy', 'licensed_pt_creator', 'en', null, array['right_shoulder','left_shoulder'], array['stiffness','guarding','post_activity_discomfort'], array['passive_rom','pendulum','low_load_shoulder_motion'], array['mobility','recovery'], array[]::text[], array['post_training','after_lifting','general'], 'beginner', array['suspected_fracture','dislocation','acute_inflammation'], 'Best as the lowest-load shoulder option when guarding is high.', null, 0.9, 0.91, 'approved', now()),
  ('V04', 'hinge_health', 'hingehealth.com', 'https://www.hingehealth.com/resources/articles/shoulder-mobility-exercises/', 'in_app_browser', 'professional_platform', 'Open Book Rotation', 'Hinge Health Learning Center', 'PT-reviewed, doctorate-level physical therapy team', 'pt_reviewed_platform', 'en', null, array['right_shoulder','left_shoulder','upper_back','lower_back'], array['stiffness','tightness','restriction'], array['thoracic_rotation','spine_mobility','chest_opening'], array['mobility','recovery','relaxation'], array[]::text[], array['general','evening'], 'beginner', array['acute_rib_injury','dizziness_with_rotation'], 'Useful when shoulder or back limitation is partly thoracic.', null, 0.88, 0.87, 'approved', now()),
  ('V05', 'hinge_health', 'hingehealth.com', 'https://www.hingehealth.com/resources/articles/thread-the-needle/', 'in_app_browser', 'professional_platform', 'Thread the Needle', 'Hinge Health Learning Center', 'PT-reviewed, doctorate-level physical therapy team', 'pt_reviewed_platform', 'en', null, array['right_shoulder','left_shoulder','upper_back','neck'], array['tightness','guarding','stiffness'], array['thoracic_rotation','shoulder_stretch','upper_back_mobility'], array['mobility','recovery','relaxation'], array[]::text[], array['general','evening'], 'beginner', array['wrist_intolerance','acute_shoulder_flare'], 'Great companion option when shoulder symptoms include upper-back tightness.', null, 0.88, 0.86, 'approved', now()),
  ('V06', 'hinge_health', 'hingehealth.com', 'https://www.hingehealth.com/resources/articles/hip-flexor-stretch/', 'in_app_browser', 'professional_platform', 'Hip Flexor Stretch', 'Hinge Health Learning Center', 'PT-reviewed, doctorate-level physical therapy team', 'pt_reviewed_platform', 'en', null, array['right_hip','left_hip','lower_back'], array['tightness','restriction','post_activity_discomfort'], array['split_stance','front_hip_stretch','mobility'], array['mobility','warm_up','recovery'], array[]::text[], array['after_running','post_training','general'], 'beginner', array['recent_hip_replacement','front_hip_pinching'], 'High-yield option for front-hip tightness and post-run stiffness.', null, 0.93, 0.93, 'approved', now()),
  ('V07', 'hinge_health', 'hingehealth.com', 'https://www.hingehealth.com/resources/articles/kneeling-hip-flexor-stretch', 'in_app_browser', 'professional_platform', 'Kneeling Hip Flexor Stretch', 'Hinge Health Learning Center', 'PT-reviewed, doctorate-level physical therapy team', 'pt_reviewed_platform', 'en', null, array['right_hip','left_hip','lower_back'], array['tightness','restriction'], array['half_kneeling','pelvic_tuck','front_hip_stretch'], array['mobility','warm_up'], array['pad','mat'], array['after_running','post_training'], 'beginner', array['kneeling_intolerance','recent_hip_surgery'], 'Use when the user tolerates floor work and needs deeper front-hip opening.', null, 0.9, 0.89, 'approved', now()),
  ('V08', 'hinge_health', 'hingehealth.com', 'https://www.hingehealth.com/resources/articles/figure-four/', 'in_app_browser', 'professional_platform', 'Figure Four Stretch', 'Hinge Health Learning Center', 'PT-reviewed, doctorate-level physical therapy team', 'pt_reviewed_platform', 'en', null, array['right_hip','left_hip','lower_back'], array['tightness','soreness','post_activity_discomfort'], array['piriformis','glute_stretch','hip_mobility'], array['mobility','recovery','relaxation'], array[]::text[], array['after_running','evening','general'], 'beginner', array['hip_impingement','crossed_leg_knee_pain'], 'Strong glute and lateral-hip option for back-linked tension.', null, 0.92, 0.9, 'approved', now()),
  ('V09', 'hinge_health', 'hingehealth.com', 'https://www.hingehealth.com/resources/articles/bridge-exercise/', 'in_app_browser', 'professional_platform', 'Bridge Exercise', 'Hinge Health Learning Center', 'PT-reviewed, doctorate-level physical therapy team', 'pt_reviewed_platform', 'en', null, array['right_hip','left_hip','lower_back','right_knee','left_knee'], array['soreness','restriction','post_activity_discomfort'], array['glute_strength','posterior_chain_support','bridge'], array['recovery','performance_prep','warm_up'], array['mat'], array['general','post_training'], 'beginner', array['hamstring_cramping','lumbar_extension_intolerance'], 'Support movement when hip or back symptoms also need low-load strength.', null, 0.86, 0.84, 'approved', now()),
  ('V10', 'hinge_health', 'hingehealth.com', 'https://www.hingehealth.com/resources/articles/hip-hinge/', 'in_app_browser', 'professional_platform', 'Hip Hinge', 'Hinge Health Learning Center', 'PT-reviewed, doctorate-level physical therapy team', 'pt_reviewed_platform', 'en', null, array['right_hip','left_hip','lower_back'], array['restriction','stiffness','guarding'], array['hip_hinge','neutral_spine','movement_pattern'], array['warm_up','performance_prep','mobility'], array[]::text[], array['after_lifting','post_training','general'], 'beginner_to_intermediate', array['acute_lumbar_flare','dizziness_forward_bending'], 'Patterning option when the limitation is movement control rather than pure stretching.', null, 0.84, 0.82, 'approved', now()),
  ('V11', 'hinge_health', 'hingehealth.com', 'https://www.hingehealth.com/resources/articles/mcl-exercises/', 'in_app_browser', 'professional_platform', 'Heel Slide', 'Hinge Health Learning Center', 'PT-guided exercise recommendation', 'pt_reviewed_platform', 'en', null, array['right_knee','left_knee'], array['restriction','stiffness','post_activity_discomfort'], array['knee_rom','heel_slide','flexion_recovery'], array['mobility','recovery'], array['towel'], array['after_running','general'], 'beginner', array['hot_swollen_knee','mechanical_locking'], 'Start here when knee ROM is the limiting factor.', null, 0.89, 0.88, 'approved', now()),
  ('V12', 'hinge_health', 'hingehealth.com', 'https://www.hingehealth.com/resources/articles/knee-extension/', 'in_app_browser', 'professional_platform', 'Seated Knee Extension', 'Hinge Health Learning Center', 'PT-reviewed content', 'pt_reviewed_platform', 'en', null, array['right_knee','left_knee'], array['restriction','soreness'], array['quad_activation','terminal_extension','non_weight_bearing'], array['mobility','recovery','warm_up'], array['chair'], array['general','after_running'], 'beginner', array['patellar_compression_pain','post_op_restrictions'], 'Low-load extension option for stiff or sore knees.', null, 0.88, 0.86, 'approved', now()),
  ('V13', 'hinge_health', 'hingehealth.com', 'https://www.hingehealth.com/resources/articles/knee-mobility-exercises/#standing-calf-stretch', 'in_app_browser', 'professional_platform', 'Standing Calf Stretch', 'Hinge Health Learning Center', 'PT-reviewed content', 'pt_reviewed_platform', 'en', null, array['right_knee','left_knee','right_calf','left_calf'], array['tightness','restriction','post_activity_discomfort'], array['calf_stretch','posterior_chain','ankle_mobility'], array['mobility','recovery','warm_up'], array['wall'], array['after_running','post_training'], 'beginner', array['acute_calf_strain','achilles_flare'], 'Use when knee stiffness is partly tied to the calf or ankle complex.', null, 0.86, 0.85, 'approved', now()),
  ('V14', 'hinge_health', 'hingehealth.com', 'https://www.hingehealth.com/resources/articles/knee-mobility-exercises/#quadruped-sit-back', 'in_app_browser', 'professional_platform', 'Quadruped Sit Back', 'Hinge Health Learning Center', 'PT-reviewed content', 'pt_reviewed_platform', 'en', null, array['right_knee','left_knee'], array['restriction','stiffness'], array['end_range_flexion','kneeling_control','functional_crouch'], array['mobility','recovery'], array['mat'], array['general','post_training'], 'beginner_to_intermediate', array['kneeling_intolerance','acute_effusion'], 'Useful for functional knee flexion if the user tolerates kneeling.', null, 0.87, 0.86, 'approved', now()),
  ('V15', 'ask_doctor_jo', 'askdoctorjo.com', 'https://www.askdoctorjo.com/video/5-knee-pain-relief-stretches-exercises-you-can-do-in-bed/', 'in_app_browser', 'professional_platform', 'Knee Pain Relief Stretches and Exercises You Can Do in Bed', 'Ask Doctor Jo', 'Physical Therapist, Doctor of Physical Therapy', 'licensed_pt_creator', 'en', null, array['right_knee','left_knee'], array['stiffness','soreness','post_activity_discomfort'], array['hamstring_stretch','heel_slide','quad_set','bed_routine'], array['recovery','relaxation'], array['bed'], array['evening','general'], 'beginner', array['hot_swollen_knee','recent_traumatic_injury'], 'Low-friction bundle for irritated knees and bedtime recovery.', null, 0.84, 0.82, 'approved', now()),
  ('V16', 'hinge_health', 'hingehealth.com', 'https://www.hingehealth.com/resources/articles/cat-cow/', 'in_app_browser', 'professional_platform', 'Cat Cow', 'Hinge Health Learning Center', 'PT-reviewed, doctorate-level physical therapy team', 'pt_reviewed_platform', 'en', null, array['lower_back','upper_back','neck'], array['stiffness','guarding','post_activity_discomfort'], array['spinal_flexion_extension','mobility','back_tension_relief'], array['mobility','recovery','relaxation'], array['mat'], array['morning','evening','general'], 'beginner', array['wrist_intolerance','strong_flexion_extension_sensitivity'], 'Go-to gentle mobility routine for lower back and neck tension.', null, 0.92, 0.9, 'approved', now()),
  ('V17', 'hinge_health', 'hingehealth.com', 'https://www.hingehealth.com/resources/articles/chin-tucks/', 'in_app_browser', 'professional_platform', 'Chin Tucks', 'Hinge Health Learning Center', 'PT-reviewed, doctorate-level physical therapy team', 'pt_reviewed_platform', 'en', null, array['neck','upper_back'], array['tightness','guarding'], array['deep_neck_flexor','posture','low_load_activation'], array['mobility','recovery','relaxation'], array[]::text[], array['morning','general','evening'], 'beginner', array['dizziness','facial_or_arm_symptoms','recent_cervical_trauma'], 'Primary neck option when the goal is gentle posture and support.', null, 0.9, 0.84, 'approved', now()),
  ('V18', 'ask_doctor_jo', 'askdoctorjo.com', 'https://www.askdoctorjo.com/real-time-back-pain-relief/', 'in_app_browser', 'professional_platform', 'Back Pain Relief Stretches - 5 Minute Real Time Routine', 'Ask Doctor Jo', 'Physical Therapist, Doctor of Physical Therapy', 'licensed_pt_creator', 'en', 300, array['lower_back','upper_back'], array['stiffness','guarding','post_activity_discomfort'], array['pelvic_tilt','trunk_rotation','child_pose','cat_cow'], array['recovery','relaxation','mobility'], array['mat'], array['after_lifting','after_running','evening'], 'beginner', array['progressive_neurologic_symptoms','rapidly_worsening_pain'], 'Short guided routine for loaded or tight lower-back days.', null, 0.9, 0.88, 'approved', now()),
  ('V19', 'ask_doctor_jo', 'askdoctorjo.com', 'https://www.askdoctorjo.com/hip-pain-relief/', 'in_app_browser', 'professional_platform', 'Hip Pain Relief Stretches - 5 Minute Real Time Routine', 'Ask Doctor Jo', 'Physical Therapist, Doctor of Physical Therapy', 'licensed_pt_creator', 'en', 300, array['right_hip','left_hip','lower_back'], array['tightness','soreness','post_activity_discomfort'], array['hip_flexor','glute','groin','hamstring','it_band'], array['mobility','recovery'], array['mat'], array['after_running','post_training','general'], 'beginner', array['acute_hip_injury','recent_replacement_precautions'], 'Efficient hip routine when the user wants one guided follow-along.', null, 0.89, 0.87, 'approved', now()),
  ('V20', 'hospital_for_special_surgery', 'hss.edu', 'https://www.hss.edu/health-library/move-better/back-neck-stretches', 'in_app_browser', 'professional_platform', 'Neck Retraction and Neck Rotation', 'Hospital for Special Surgery Rehabilitation and Performance', 'Orthopedic rehab institution', 'academic_medical', 'en', null, array['neck','upper_back'], array['tightness','guarding','stiffness'], array['neck_retraction','cervical_rotation','gentle_mobility'], array['mobility','recovery','relaxation'], array[]::text[], array['morning','general'], 'beginner', array['dizziness','vision_changes','arm_numbness','recent_cervical_trauma'], 'Institutional neck mobility option for careful cervical guidance.', null, 0.9, 0.84, 'approved', now())
on conflict (id) do update set
  source_slug = excluded.source_slug,
  source_domain = excluded.source_domain,
  canonical_url = excluded.canonical_url,
  thumbnail_url = excluded.thumbnail_url,
  playback_mode = excluded.playback_mode,
  content_host = excluded.content_host,
  title = excluded.title,
  creator_name = excluded.creator_name,
  creator_credentials = excluded.creator_credentials,
  source_quality_tier = excluded.source_quality_tier,
  language = excluded.language,
  duration_sec = excluded.duration_sec,
  body_regions = excluded.body_regions,
  symptom_tags = excluded.symptom_tags,
  movement_tags = excluded.movement_tags,
  goal_tags = excluded.goal_tags,
  equipment_tags = excluded.equipment_tags,
  activity_trigger_tags = excluded.activity_trigger_tags,
  level = excluded.level,
  contraindication_tags = excluded.contraindication_tags,
  practitioner_notes = excluded.practitioner_notes,
  hydrawav_pairing = excluded.hydrawav_pairing,
  quality_score = excluded.quality_score,
  confidence_score = excluded.confidence_score,
  human_review_status = excluded.human_review_status,
  last_reviewed_at = excluded.last_reviewed_at,
  updated_at = now();

insert into public.exercise_recommendation_rules (
  id, region, symptom, evidence_tier, goal_tags, activity_trigger_tags,
  hydrawav_pairing, practitioner_note, quality_score, confidence_score,
  human_review_status, last_reviewed_at
) values
  (
    'right_shoulder_stiffness',
    'right_shoulder',
    'stiffness',
    'direct',
    array['mobility','recovery'],
    array['general','after_lifting'],
    jsonb_build_object(
      'sun_pad', 'right anterior shoulder',
      'moon_pad', 'right upper back / posterior shoulder',
      'intensity', 'gentle_to_moderate',
      'duration_min', 7,
      'practitioner_note', 'If guarding is high, start with pendulum and squeezes before wall slides.'
    ),
    'Prioritize low-load shoulder motion before heavier mobility work.',
    0.92,
    0.91,
    'approved',
    now()
  ),
  (
    'right_hip_tightness',
    'right_hip',
    'tightness',
    'direct',
    array['mobility','recovery'],
    array['after_running','post_training'],
    jsonb_build_object(
      'sun_pad', 'right lateral/anterior hip',
      'moon_pad', 'left lower back',
      'intensity', 'moderate',
      'duration_min', 9,
      'practitioner_note', 'Best fit for runner-type profile with front-hip tightness and lumbar compensation.'
    ),
    'Pair hip-opening content with lumbar support when front-hip tightness is prominent.',
    0.93,
    0.93,
    'approved',
    now()
  ),
  (
    'lower_back_stiffness',
    'lower_back',
    'stiffness',
    'direct',
    array['mobility','recovery','relaxation'],
    array['general','morning','evening'],
    jsonb_build_object(
      'sun_pad', 'lumbar region',
      'moon_pad', 'abdomen / hip flexor',
      'intensity', 'gentle_to_moderate',
      'duration_min', 9,
      'practitioner_note', 'Downgrade intensity if symptoms behave like guarding rather than general stiffness.'
    ),
    'Favor spinal mobility and tension-reduction content first.',
    0.9,
    0.9,
    'approved',
    now()
  ),
  (
    'right_knee_restriction',
    'right_knee',
    'restriction',
    'direct',
    array['mobility','recovery'],
    array['after_running','general'],
    jsonb_build_object(
      'sun_pad', 'right peri-knee / anterior knee',
      'moon_pad', 'right calf or distal hamstring line',
      'intensity', 'gentle',
      'duration_min', 7,
      'practitioner_note', 'Prioritize heel slides first if ROM is the main problem; keep sit-back shallow initially.'
    ),
    'Emphasize ROM restoration before more functional flexion drills.',
    0.88,
    0.88,
    'approved',
    now()
  ),
  (
    'neck_guarding',
    'neck',
    'guarding',
    'schema_supported',
    array['mobility','recovery','relaxation'],
    array['morning','general','evening'],
    jsonb_build_object(
      'sun_pad', 'posterior-lateral neck / upper trap',
      'moon_pad', 'upper thoracic / shoulder girdle',
      'intensity', 'gentle',
      'duration_min', 5,
      'practitioner_note', 'Use the most conservative neck settings and stop immediately if dizziness or arm symptoms appear.'
    ),
    'Keep neck content conservative and pair with scapular support work.',
    0.84,
    0.84,
    'approved',
    now()
  ),
  (
    'lower_back_post_activity_discomfort',
    'lower_back',
    'post_activity_discomfort',
    'direct',
    array['recovery','relaxation'],
    array['after_running','after_lifting','post_training'],
    jsonb_build_object(
      'sun_pad', 'lumbar region',
      'moon_pad', 'abdomen / front-hip',
      'intensity', 'gentle',
      'duration_min', 7,
      'practitioner_note', 'Use especially after running or lifting when the back feels tight and loaded rather than acutely injured.'
    ),
    'Position this bundle for loaded post-activity back discomfort.',
    0.89,
    0.89,
    'approved',
    now()
  )
on conflict (id) do update set
  region = excluded.region,
  symptom = excluded.symptom,
  evidence_tier = excluded.evidence_tier,
  goal_tags = excluded.goal_tags,
  activity_trigger_tags = excluded.activity_trigger_tags,
  hydrawav_pairing = excluded.hydrawav_pairing,
  practitioner_note = excluded.practitioner_note,
  quality_score = excluded.quality_score,
  confidence_score = excluded.confidence_score,
  human_review_status = excluded.human_review_status,
  last_reviewed_at = excluded.last_reviewed_at,
  updated_at = now();

insert into public.exercise_recommendation_rule_items (rule_id, exercise_video_id, sort_order, display_note)
values
  ('right_shoulder_stiffness', 'V03', 1, 'Start with the gentlest option if shoulder guarding is high.'),
  ('right_shoulder_stiffness', 'V01', 2, 'Progress to wall slides once the shoulder is moving more freely.'),
  ('right_shoulder_stiffness', 'V02', 3, 'Use scapular support work to keep the shoulder and upper back coordinated.'),
  ('right_hip_tightness', 'V06', 1, 'Lead with front-hip opening when the runner profile fits.'),
  ('right_hip_tightness', 'V08', 2, 'Add glute and piriformis mobility if the hip also feels loaded laterally.'),
  ('right_hip_tightness', 'V19', 3, 'Use the guided routine when a single follow-along video is easier.'),
  ('lower_back_stiffness', 'V16', 1, 'Cat-cow is the primary low-risk spinal mobility option.'),
  ('lower_back_stiffness', 'V04', 2, 'Open-book rotation supports thoracic contribution to back mobility.'),
  ('lower_back_stiffness', 'V18', 3, 'The guided routine is a practical follow-along option.'),
  ('right_knee_restriction', 'V11', 1, 'Restore ROM first before deeper flexion work.'),
  ('right_knee_restriction', 'V12', 2, 'Add quad activation once motion starts improving.'),
  ('right_knee_restriction', 'V14', 3, 'Only progress to kneeling sit-backs if tolerated.'),
  ('neck_guarding', 'V17', 1, 'Use the lowest-load neck option first.'),
  ('neck_guarding', 'V02', 2, 'Scapular support can reduce cervical overuse.'),
  ('neck_guarding', 'V20', 3, 'Use the institutional neck sequence when more explicit guidance is needed.'),
  ('lower_back_post_activity_discomfort', 'V16', 1, 'Lead with gentle mobility first.'),
  ('lower_back_post_activity_discomfort', 'V08', 2, 'Glute release can help if the back feels loaded by the hips.'),
  ('lower_back_post_activity_discomfort', 'V18', 3, 'Use the guided routine for short post-activity recovery.')
on conflict (rule_id, exercise_video_id) do update set
  sort_order = excluded.sort_order,
  display_note = excluded.display_note,
  updated_at = now();

insert into public.exercise_recommendation_rules (
  id, region, symptom, evidence_tier, goal_tags, activity_trigger_tags,
  hydrawav_pairing, practitioner_note, quality_score, confidence_score,
  human_review_status, last_reviewed_at
) values
  (
    'left_shoulder_stiffness',
    'left_shoulder',
    'stiffness',
    'mirrored',
    array['mobility','recovery'],
    array['general','after_lifting'],
    jsonb_build_object(
      'sun_pad', 'left anterior shoulder',
      'moon_pad', 'left upper back / posterior shoulder',
      'intensity', 'gentle_to_moderate',
      'duration_min', 7,
      'practitioner_note', 'Mirror the right-shoulder progression if the left side is the primary driver.'
    ),
    'Use the same low-load progression on the left side when stiffness is the main complaint.',
    0.89,
    0.87,
    'approved',
    now()
  ),
  (
    'right_shoulder_restriction',
    'right_shoulder',
    'restriction',
    'direct',
    array['mobility','recovery'],
    array['general','after_lifting'],
    jsonb_build_object(
      'sun_pad', 'right anterior shoulder',
      'moon_pad', 'right upper back / posterior shoulder',
      'intensity', 'gentle_to_moderate',
      'duration_min', 7,
      'practitioner_note', 'Emphasize low-load ROM before thoracic mobility if overhead range is limited.'
    ),
    'Use pendulum and wall-slide progression before deeper thoracic opening when range is clearly restricted.',
    0.9,
    0.89,
    'approved',
    now()
  ),
  (
    'left_shoulder_restriction',
    'left_shoulder',
    'restriction',
    'mirrored',
    array['mobility','recovery'],
    array['general','after_lifting'],
    jsonb_build_object(
      'sun_pad', 'left anterior shoulder',
      'moon_pad', 'left upper back / posterior shoulder',
      'intensity', 'gentle_to_moderate',
      'duration_min', 7,
      'practitioner_note', 'Use the mirrored restriction progression for the left side.'
    ),
    'Mirrored restriction pathway for left-shoulder ROM limitations.',
    0.88,
    0.86,
    'approved',
    now()
  ),
  (
    'right_shoulder_post_activity_discomfort',
    'right_shoulder',
    'post_activity_discomfort',
    'direct',
    array['recovery','relaxation'],
    array['after_lifting','post_training'],
    jsonb_build_object(
      'sun_pad', 'right anterior shoulder',
      'moon_pad', 'right upper back / posterior shoulder',
      'intensity', 'gentle',
      'duration_min', 7,
      'practitioner_note', 'Use the lowest-load shoulder sequence after lifting or overhead sessions.'
    ),
    'Prioritize gentle shoulder decompression and scapular reset after activity.',
    0.91,
    0.9,
    'approved',
    now()
  ),
  (
    'left_shoulder_post_activity_discomfort',
    'left_shoulder',
    'post_activity_discomfort',
    'mirrored',
    array['recovery','relaxation'],
    array['after_lifting','post_training'],
    jsonb_build_object(
      'sun_pad', 'left anterior shoulder',
      'moon_pad', 'left upper back / posterior shoulder',
      'intensity', 'gentle',
      'duration_min', 7,
      'practitioner_note', 'Mirror the right-side post-activity pathway when the left shoulder is the active complaint.'
    ),
    'Gentle left-shoulder post-activity decompression pathway.',
    0.88,
    0.86,
    'approved',
    now()
  ),
  (
    'left_hip_tightness',
    'left_hip',
    'tightness',
    'mirrored',
    array['mobility','recovery'],
    array['after_running','post_training'],
    jsonb_build_object(
      'sun_pad', 'left lateral/anterior hip',
      'moon_pad', 'right lower back',
      'intensity', 'moderate',
      'duration_min', 9,
      'practitioner_note', 'Mirror the runner-type right-hip pathway when the left side leads.'
    ),
    'Mirrored front-hip opening plan for left-sided tightness with back compensation.',
    0.91,
    0.9,
    'approved',
    now()
  ),
  (
    'right_hip_restriction',
    'right_hip',
    'restriction',
    'direct',
    array['mobility','recovery'],
    array['after_running','post_training','general'],
    jsonb_build_object(
      'sun_pad', 'right lateral/anterior hip',
      'moon_pad', 'left lower back',
      'intensity', 'moderate',
      'duration_min', 9,
      'practitioner_note', 'Favor floor-based front-hip opening and hinge patterning if tolerated.'
    ),
    'Use front-hip opening, hinge patterning, and glute support when right-hip restriction is the main limiter.',
    0.92,
    0.91,
    'approved',
    now()
  ),
  (
    'left_hip_restriction',
    'left_hip',
    'restriction',
    'mirrored',
    array['mobility','recovery'],
    array['after_running','post_training','general'],
    jsonb_build_object(
      'sun_pad', 'left lateral/anterior hip',
      'moon_pad', 'right lower back',
      'intensity', 'moderate',
      'duration_min', 9,
      'practitioner_note', 'Mirror the right-hip restriction set for left-dominant limitation.'
    ),
    'Mirrored restriction pathway for left-hip limitation and compensatory back load.',
    0.9,
    0.89,
    'approved',
    now()
  ),
  (
    'right_hip_post_activity_discomfort',
    'right_hip',
    'post_activity_discomfort',
    'direct',
    array['recovery','relaxation'],
    array['after_running','post_training'],
    jsonb_build_object(
      'sun_pad', 'right lateral/anterior hip',
      'moon_pad', 'left lower back',
      'intensity', 'gentle_to_moderate',
      'duration_min', 9,
      'practitioner_note', 'Use this after running or training when the hip feels tight and loaded.'
    ),
    'Post-activity hip recovery path with front-hip opening and glute support.',
    0.92,
    0.91,
    'approved',
    now()
  ),
  (
    'left_hip_post_activity_discomfort',
    'left_hip',
    'post_activity_discomfort',
    'mirrored',
    array['recovery','relaxation'],
    array['after_running','post_training'],
    jsonb_build_object(
      'sun_pad', 'left lateral/anterior hip',
      'moon_pad', 'right lower back',
      'intensity', 'gentle_to_moderate',
      'duration_min', 9,
      'practitioner_note', 'Mirror the right-hip post-activity path on the left side.'
    ),
    'Mirrored post-activity recovery path for left-hip discomfort.',
    0.89,
    0.88,
    'approved',
    now()
  ),
  (
    'lower_back_guarding',
    'lower_back',
    'guarding',
    'direct',
    array['recovery','relaxation'],
    array['general','evening','after_lifting'],
    jsonb_build_object(
      'sun_pad', 'lumbar region',
      'moon_pad', 'abdomen / hip flexor',
      'intensity', 'gentle',
      'duration_min', 7,
      'practitioner_note', 'Keep the back path gentle and stop if symptoms escalate with flexion or rotation.'
    ),
    'Conservative back path for guarded movement and protective tension.',
    0.9,
    0.89,
    'approved',
    now()
  ),
  (
    'left_knee_restriction',
    'left_knee',
    'restriction',
    'mirrored',
    array['mobility','recovery'],
    array['after_running','general'],
    jsonb_build_object(
      'sun_pad', 'left peri-knee / anterior knee',
      'moon_pad', 'left calf or distal hamstring line',
      'intensity', 'gentle',
      'duration_min', 7,
      'practitioner_note', 'Mirror the right-knee ROM-first sequence on the left side.'
    ),
    'Left-knee ROM restoration path based on the mirrored starter-kit pattern.',
    0.87,
    0.86,
    'approved',
    now()
  ),
  (
    'right_knee_soreness',
    'right_knee',
    'soreness',
    'mirrored',
    array['recovery','relaxation'],
    array['after_running','general','evening'],
    jsonb_build_object(
      'sun_pad', 'right peri-knee / anterior knee',
      'moon_pad', 'right calf or distal hamstring line',
      'intensity', 'gentle',
      'duration_min', 7,
      'practitioner_note', 'Use the most soothing knee options first when soreness is dominant.'
    ),
    'Recovery-first knee path for soreness, emphasizing low-load motion and calf support.',
    0.86,
    0.84,
    'approved',
    now()
  ),
  (
    'left_knee_soreness',
    'left_knee',
    'soreness',
    'mirrored',
    array['recovery','relaxation'],
    array['after_running','general','evening'],
    jsonb_build_object(
      'sun_pad', 'left peri-knee / anterior knee',
      'moon_pad', 'left calf or distal hamstring line',
      'intensity', 'gentle',
      'duration_min', 7,
      'practitioner_note', 'Mirror the knee-soreness sequence on the left side.'
    ),
    'Left-knee soreness recovery path with low-friction mobility choices.',
    0.84,
    0.82,
    'approved',
    now()
  ),
  (
    'right_knee_post_activity_discomfort',
    'right_knee',
    'post_activity_discomfort',
    'direct',
    array['recovery','mobility'],
    array['after_running','post_training'],
    jsonb_build_object(
      'sun_pad', 'right peri-knee / anterior knee',
      'moon_pad', 'right calf or distal hamstring line',
      'intensity', 'gentle',
      'duration_min', 7,
      'practitioner_note', 'Use after running or training when the knee feels loaded but not acutely inflamed.'
    ),
    'Post-activity knee recovery path centered on ROM, calf support, and easy activation.',
    0.89,
    0.88,
    'approved',
    now()
  ),
  (
    'left_knee_post_activity_discomfort',
    'left_knee',
    'post_activity_discomfort',
    'mirrored',
    array['recovery','mobility'],
    array['after_running','post_training'],
    jsonb_build_object(
      'sun_pad', 'left peri-knee / anterior knee',
      'moon_pad', 'left calf or distal hamstring line',
      'intensity', 'gentle',
      'duration_min', 7,
      'practitioner_note', 'Mirror the right-knee post-activity sequence on the left side.'
    ),
    'Mirrored post-activity recovery path for left-knee discomfort.',
    0.87,
    0.86,
    'approved',
    now()
  ),
  (
    'neck_tightness',
    'neck',
    'tightness',
    'schema_supported',
    array['mobility','recovery','relaxation'],
    array['morning','general','evening'],
    jsonb_build_object(
      'sun_pad', 'posterior-lateral neck / upper trap',
      'moon_pad', 'upper thoracic / shoulder girdle',
      'intensity', 'gentle',
      'duration_min', 5,
      'practitioner_note', 'Favor low-load neck and scapular support work; stop immediately if dizziness or arm symptoms occur.'
    ),
    'Conservative neck mobility path for tension and tightness with scapular support.',
    0.86,
    0.84,
    'approved',
    now()
  )
on conflict (id) do update set
  region = excluded.region,
  symptom = excluded.symptom,
  evidence_tier = excluded.evidence_tier,
  goal_tags = excluded.goal_tags,
  activity_trigger_tags = excluded.activity_trigger_tags,
  hydrawav_pairing = excluded.hydrawav_pairing,
  practitioner_note = excluded.practitioner_note,
  quality_score = excluded.quality_score,
  confidence_score = excluded.confidence_score,
  human_review_status = excluded.human_review_status,
  last_reviewed_at = excluded.last_reviewed_at,
  updated_at = now();

insert into public.exercise_recommendation_rule_items (rule_id, exercise_video_id, sort_order, display_note)
values
  ('left_shoulder_stiffness', 'V03', 1, 'Start with pendulum work when the left shoulder is guarded or stiff.'),
  ('left_shoulder_stiffness', 'V01', 2, 'Progress into wall slides once movement feels easier.'),
  ('left_shoulder_stiffness', 'V02', 3, 'Use scapular support work to keep the shoulder and upper back coordinated.'),
  ('left_shoulder_stiffness', 'V04', 4, 'Add thoracic opening if stiffness feels tied to chest or upper-back tightness.'),
  ('right_shoulder_restriction', 'V03', 1, 'Start with pendulum work if active ROM is limited.'),
  ('right_shoulder_restriction', 'V01', 2, 'Progress into wall slides as range improves.'),
  ('right_shoulder_restriction', 'V04', 3, 'Use thoracic opening when restriction is partly chest or upper-back driven.'),
  ('right_shoulder_restriction', 'V05', 4, 'Add rotational shoulder and upper-back mobility if tolerated.'),
  ('left_shoulder_restriction', 'V03', 1, 'Start with the gentlest left-side ROM option.'),
  ('left_shoulder_restriction', 'V01', 2, 'Progress to wall slides when movement quality improves.'),
  ('left_shoulder_restriction', 'V04', 3, 'Use thoracic opening when left shoulder range feels chest-limited.'),
  ('left_shoulder_restriction', 'V05', 4, 'Add rotational mobility if floor loading is tolerated.'),
  ('right_shoulder_post_activity_discomfort', 'V03', 1, 'Lead with the gentlest decompression option after activity.'),
  ('right_shoulder_post_activity_discomfort', 'V02', 2, 'Restore scapular support and posture after loading.'),
  ('right_shoulder_post_activity_discomfort', 'V05', 3, 'Use thoracic-shoulder mobility if the upper quarter still feels loaded.'),
  ('left_shoulder_post_activity_discomfort', 'V03', 1, 'Lead with the gentlest left-shoulder decompression option.'),
  ('left_shoulder_post_activity_discomfort', 'V02', 2, 'Restore scapular support after loading.'),
  ('left_shoulder_post_activity_discomfort', 'V05', 3, 'Add rotational mobility if the upper quarter still feels loaded.'),
  ('left_hip_tightness', 'V06', 1, 'Lead with front-hip opening on the left side.'),
  ('left_hip_tightness', 'V07', 2, 'Use the kneeling variation if floor work is comfortable.'),
  ('left_hip_tightness', 'V08', 3, 'Add glute mobility if the hip also feels laterally loaded.'),
  ('left_hip_tightness', 'V19', 4, 'Use the guided routine when a single follow-along video is easier.'),
  ('right_hip_restriction', 'V07', 1, 'Use the deeper front-hip opener first if tolerated.'),
  ('right_hip_restriction', 'V10', 2, 'Add hinge patterning when restriction is partly movement-control based.'),
  ('right_hip_restriction', 'V08', 3, 'Use glute mobility when the hip and back both feel restricted.'),
  ('right_hip_restriction', 'V09', 4, 'Add low-load support strength once motion starts to normalize.'),
  ('left_hip_restriction', 'V07', 1, 'Use the mirrored restriction opener on the left side.'),
  ('left_hip_restriction', 'V10', 2, 'Add hinge patterning once left-hip motion improves.'),
  ('left_hip_restriction', 'V08', 3, 'Use glute mobility if left-hip and back limitation overlap.'),
  ('left_hip_restriction', 'V09', 4, 'Add low-load support strength if tolerated.'),
  ('right_hip_post_activity_discomfort', 'V06', 1, 'Lead with front-hip opening after activity.'),
  ('right_hip_post_activity_discomfort', 'V08', 2, 'Add glute release if the hip feels laterally loaded.'),
  ('right_hip_post_activity_discomfort', 'V09', 3, 'Use bridge support when the posterior chain feels under-recruited.'),
  ('right_hip_post_activity_discomfort', 'V19', 4, 'Use the guided routine for a short follow-along recovery block.'),
  ('left_hip_post_activity_discomfort', 'V06', 1, 'Lead with left front-hip opening after activity.'),
  ('left_hip_post_activity_discomfort', 'V08', 2, 'Add glute release if the left hip feels laterally loaded.'),
  ('left_hip_post_activity_discomfort', 'V09', 3, 'Use bridge support when the posterior chain feels under-recruited.'),
  ('left_hip_post_activity_discomfort', 'V19', 4, 'Use the guided routine for a short follow-along recovery block.'),
  ('lower_back_guarding', 'V16', 1, 'Keep the back path gentle and rhythmic first.'),
  ('lower_back_guarding', 'V05', 2, 'Use upper-back rotation only if it feels calming rather than provocative.'),
  ('lower_back_guarding', 'V18', 3, 'Use the short real-time routine for guided low-friction recovery.'),
  ('left_knee_restriction', 'V11', 1, 'Restore ROM first before deeper flexion work.'),
  ('left_knee_restriction', 'V12', 2, 'Add quad activation once motion starts improving.'),
  ('left_knee_restriction', 'V13', 3, 'Use calf flexibility if the knee still feels blocked.'),
  ('left_knee_restriction', 'V14', 4, 'Only progress to deeper flexion if kneeling is well tolerated.'),
  ('right_knee_soreness', 'V11', 1, 'Keep the first option easy and range-based.'),
  ('right_knee_soreness', 'V13', 2, 'Use calf support when posterior-chain tightness contributes.'),
  ('right_knee_soreness', 'V09', 3, 'Add low-load posterior-chain support if tolerated.'),
  ('right_knee_soreness', 'V15', 4, 'Use the bed routine when a very low-friction recovery option fits best.'),
  ('left_knee_soreness', 'V11', 1, 'Keep the first option easy and range-based.'),
  ('left_knee_soreness', 'V13', 2, 'Use calf support when posterior-chain tightness contributes.'),
  ('left_knee_soreness', 'V09', 3, 'Add low-load posterior-chain support if tolerated.'),
  ('left_knee_soreness', 'V15', 4, 'Use the bed routine when a very low-friction recovery option fits best.'),
  ('right_knee_post_activity_discomfort', 'V11', 1, 'Lead with knee ROM restoration after loading.'),
  ('right_knee_post_activity_discomfort', 'V12', 2, 'Add low-load extension if the knee still feels stiff.'),
  ('right_knee_post_activity_discomfort', 'V13', 3, 'Use calf support when the lower chain still feels loaded.'),
  ('right_knee_post_activity_discomfort', 'V15', 4, 'Use the bed routine if the knee is irritable and needs the easiest path.'),
  ('left_knee_post_activity_discomfort', 'V11', 1, 'Lead with knee ROM restoration after loading.'),
  ('left_knee_post_activity_discomfort', 'V12', 2, 'Add low-load extension if the knee still feels stiff.'),
  ('left_knee_post_activity_discomfort', 'V13', 3, 'Use calf support when the lower chain still feels loaded.'),
  ('left_knee_post_activity_discomfort', 'V15', 4, 'Use the bed routine if the knee is irritable and needs the easiest path.'),
  ('neck_tightness', 'V17', 1, 'Use the lowest-load neck mobility option first.'),
  ('neck_tightness', 'V02', 2, 'Add scapular support to reduce neck overuse.'),
  ('neck_tightness', 'V05', 3, 'Use thoracic/upper-back mobility if neck tightness feels upper-quarter driven.'),
  ('neck_tightness', 'V20', 4, 'Use the institutional neck sequence when more explicit guidance is helpful.')
on conflict (rule_id, exercise_video_id) do update set
  sort_order = excluded.sort_order,
  display_note = excluded.display_note,
  updated_at = now();
