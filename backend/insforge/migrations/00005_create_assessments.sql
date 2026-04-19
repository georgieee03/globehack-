create or replace function public.sync_clinic_id_from_client_profile()
returns trigger
language plpgsql
as $$
declare
  v_client_clinic_id uuid;
begin
  select clinic_id
  into v_client_clinic_id
  from public.client_profiles
  where id = new.client_id;

  if v_client_clinic_id is null then
    raise exception 'Client profile % was not found for %', new.client_id, tg_table_name;
  end if;

  if new.clinic_id is null then
    new.clinic_id := v_client_clinic_id;
  elsif new.clinic_id <> v_client_clinic_id then
    raise exception 'Clinic mismatch for %: expected %, got %', tg_table_name, v_client_clinic_id, new.clinic_id;
  end if;

  return new;
end;
$$;

create or replace function public.ensure_assessment_practitioner_matches_clinic()
returns trigger
language plpgsql
as $$
declare
  v_practitioner_clinic_id uuid;
begin
  if new.practitioner_id is null then
    return new;
  end if;

  select clinic_id
  into v_practitioner_clinic_id
  from public.users
  where id = new.practitioner_id;

  if v_practitioner_clinic_id is null then
    raise exception 'Practitioner % was not found for assessment scope validation', new.practitioner_id;
  end if;

  if v_practitioner_clinic_id <> new.clinic_id then
    raise exception 'Assessment practitioner clinic % does not match assessment clinic %', v_practitioner_clinic_id, new.clinic_id;
  end if;

  return new;
end;
$$;

create table if not exists public.assessments (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.client_profiles(id) on delete cascade,
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  practitioner_id uuid references public.users(id) on delete set null,
  assessment_type text not null
    check (assessment_type in ('intake', 'pre_session', 'follow_up', 'reassessment')),
  quickpose_data jsonb,
  rom_values jsonb,
  asymmetry_scores jsonb,
  movement_quality_scores jsonb,
  gait_metrics jsonb,
  heart_rate numeric,
  breath_rate numeric,
  hrv_rmssd numeric,
  body_zones jsonb,
  recovery_goal text,
  subjective_baseline jsonb,
  recovery_map jsonb,
  recovery_graph_delta jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint assessments_quickpose_data_chk
    check (quickpose_data is null or jsonb_typeof(quickpose_data) = 'object'),
  constraint assessments_rom_values_chk
    check (rom_values is null or jsonb_typeof(rom_values) = 'object'),
  constraint assessments_asymmetry_scores_chk
    check (asymmetry_scores is null or jsonb_typeof(asymmetry_scores) = 'object'),
  constraint assessments_movement_quality_scores_chk
    check (movement_quality_scores is null or jsonb_typeof(movement_quality_scores) = 'object'),
  constraint assessments_gait_metrics_chk
    check (gait_metrics is null or jsonb_typeof(gait_metrics) = 'object'),
  constraint assessments_heart_rate_chk
    check (heart_rate is null or heart_rate >= 0),
  constraint assessments_breath_rate_chk
    check (breath_rate is null or breath_rate >= 0),
  constraint assessments_hrv_rmssd_chk
    check (hrv_rmssd is null or hrv_rmssd >= 0),
  constraint assessments_body_zones_chk
    check (body_zones is null or jsonb_typeof(body_zones) = 'array'),
  constraint assessments_recovery_goal_chk
    check (
      recovery_goal is null
      or recovery_goal in ('mobility', 'warm_up', 'recovery', 'relaxation', 'performance_prep')
    ),
  constraint assessments_subjective_baseline_chk
    check (subjective_baseline is null or jsonb_typeof(subjective_baseline) = 'object'),
  constraint assessments_recovery_map_chk
    check (recovery_map is null or jsonb_typeof(recovery_map) = 'object'),
  constraint assessments_recovery_graph_delta_chk
    check (recovery_graph_delta is null or jsonb_typeof(recovery_graph_delta) = 'object')
);

create index if not exists assessments_client_created_at_idx
  on public.assessments (client_id, created_at desc);

create index if not exists assessments_clinic_type_created_at_idx
  on public.assessments (clinic_id, assessment_type, created_at desc);

create index if not exists assessments_practitioner_created_at_idx
  on public.assessments (practitioner_id, created_at desc);

drop trigger if exists assessments_sync_clinic_id on public.assessments;
create trigger assessments_sync_clinic_id
before insert or update on public.assessments
for each row
execute function public.sync_clinic_id_from_client_profile();

drop trigger if exists assessments_validate_practitioner_scope on public.assessments;
create trigger assessments_validate_practitioner_scope
before insert or update on public.assessments
for each row
execute function public.ensure_assessment_practitioner_matches_clinic();

drop trigger if exists set_assessments_updated_at on public.assessments;
create trigger set_assessments_updated_at
before update on public.assessments
for each row
execute function public.set_updated_at();
