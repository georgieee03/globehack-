create table if not exists public.sessions (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.client_profiles(id) on delete cascade,
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  practitioner_id uuid not null references public.users(id) on delete restrict,
  device_id uuid not null references public.devices(id) on delete restrict,
  assessment_id uuid references public.assessments(id) on delete set null,
  session_config jsonb not null,
  recommended_config jsonb,
  practitioner_edits jsonb,
  recommendation_rationale text,
  confidence_score numeric,
  status text not null default 'pending'
    check (status in ('pending', 'active', 'paused', 'completed', 'cancelled', 'error')),
  started_at timestamptz,
  paused_at timestamptz,
  resumed_at timestamptz,
  completed_at timestamptz,
  total_duration_s integer,
  outcome jsonb,
  practitioner_notes text,
  retest_values jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint sessions_session_config_chk
    check (jsonb_typeof(session_config) = 'object'),
  constraint sessions_recommended_config_chk
    check (recommended_config is null or jsonb_typeof(recommended_config) = 'object'),
  constraint sessions_practitioner_edits_chk
    check (practitioner_edits is null or jsonb_typeof(practitioner_edits) = 'object'),
  constraint sessions_confidence_score_chk
    check (confidence_score is null or confidence_score between 0 and 1),
  constraint sessions_total_duration_s_chk
    check (total_duration_s is null or total_duration_s >= 0),
  constraint sessions_outcome_chk
    check (outcome is null or jsonb_typeof(outcome) = 'object'),
  constraint sessions_retest_values_chk
    check (retest_values is null or jsonb_typeof(retest_values) = 'object')
);

create or replace function public.ensure_session_relations_match_clinic()
returns trigger
language plpgsql
as $$
declare
  v_practitioner_clinic_id uuid;
  v_device_clinic_id uuid;
  v_assessment_client_id uuid;
  v_assessment_clinic_id uuid;
begin
  select clinic_id
  into v_practitioner_clinic_id
  from public.users
  where id = new.practitioner_id;

  if v_practitioner_clinic_id is null then
    raise exception 'Practitioner % was not found for session scope validation', new.practitioner_id;
  end if;

  if v_practitioner_clinic_id <> new.clinic_id then
    raise exception 'Session practitioner clinic % does not match session clinic %', v_practitioner_clinic_id, new.clinic_id;
  end if;

  select clinic_id
  into v_device_clinic_id
  from public.devices
  where id = new.device_id;

  if v_device_clinic_id is null then
    raise exception 'Device % was not found for session scope validation', new.device_id;
  end if;

  if v_device_clinic_id <> new.clinic_id then
    raise exception 'Session device clinic % does not match session clinic %', v_device_clinic_id, new.clinic_id;
  end if;

  if new.assessment_id is not null then
    select client_id, clinic_id
    into v_assessment_client_id, v_assessment_clinic_id
    from public.assessments
    where id = new.assessment_id;

    if v_assessment_clinic_id is null then
      raise exception 'Assessment % was not found for session scope validation', new.assessment_id;
    end if;

    if v_assessment_clinic_id <> new.clinic_id then
      raise exception 'Assessment clinic % does not match session clinic %', v_assessment_clinic_id, new.clinic_id;
    end if;

    if v_assessment_client_id <> new.client_id then
      raise exception 'Assessment client % does not match session client %', v_assessment_client_id, new.client_id;
    end if;
  end if;

  return new;
end;
$$;

create index if not exists sessions_client_created_at_idx
  on public.sessions (client_id, created_at desc);

create index if not exists sessions_clinic_status_idx
  on public.sessions (clinic_id, status, created_at desc);

create index if not exists sessions_device_created_at_idx
  on public.sessions (device_id, created_at desc);

create unique index if not exists sessions_active_device_uidx
  on public.sessions (device_id)
  where status in ('active', 'paused');

drop trigger if exists sessions_sync_clinic_id on public.sessions;
create trigger sessions_sync_clinic_id
before insert or update on public.sessions
for each row
execute function public.sync_clinic_id_from_client_profile();

drop trigger if exists sessions_validate_relations on public.sessions;
create trigger sessions_validate_relations
before insert or update on public.sessions
for each row
execute function public.ensure_session_relations_match_clinic();

drop trigger if exists set_sessions_updated_at on public.sessions;
create trigger set_sessions_updated_at
before update on public.sessions
for each row
execute function public.set_updated_at();

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'devices_last_session_id_fkey'
  ) then
    alter table public.devices
      add constraint devices_last_session_id_fkey
      foreign key (last_session_id)
      references public.sessions(id)
      on delete set null;
  end if;
end
$$;
