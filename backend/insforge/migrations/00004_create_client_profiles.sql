create or replace function public.is_valid_body_region(p_region text)
returns boolean
language sql
immutable
as $$
  select p_region = any (
    array[
      'right_shoulder',
      'left_shoulder',
      'lower_back',
      'upper_back',
      'right_hip',
      'left_hip',
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
  );
$$;

create or replace function public.validate_body_regions_json(p_regions jsonb)
returns boolean
language sql
immutable
as $$
  select jsonb_typeof(coalesce(p_regions, '[]'::jsonb)) = 'array'
    and not exists (
      select 1
      from jsonb_array_elements(coalesce(p_regions, '[]'::jsonb)) as region_value(value)
      where jsonb_typeof(region_value.value) <> 'string'
        or not public.is_valid_body_region(trim(both '"' from region_value.value::text))
    );
$$;

create or replace function public.validate_recovery_signals_json(p_signals jsonb)
returns boolean
language plpgsql
immutable
as $$
declare
  signal_key text;
  signal_value jsonb;
  signal_severity integer;
begin
  if p_signals is null then
    return true;
  end if;

  if jsonb_typeof(p_signals) <> 'object' then
    return false;
  end if;

  for signal_key, signal_value in
    select key, value
    from jsonb_each(p_signals)
  loop
    if not public.is_valid_body_region(signal_key) then
      return false;
    end if;

    if jsonb_typeof(signal_value) <> 'object' then
      return false;
    end if;

    if coalesce(signal_value ->> 'type', '') not in (
      'stiffness',
      'soreness',
      'tightness',
      'restriction',
      'guarding'
    ) then
      return false;
    end if;

    if coalesce(signal_value ->> 'trigger', '') not in (
      'morning',
      'after_running',
      'after_lifting',
      'post_travel',
      'post_training',
      'evening',
      'general'
    ) then
      return false;
    end if;

    begin
      signal_severity := (signal_value ->> 'severity')::integer;
    exception
      when others then
        return false;
    end;

    if signal_severity < 1 or signal_severity > 10 then
      return false;
    end if;
  end loop;

  return true;
end;
$$;

create or replace function public.sync_client_profile_clinic_from_user()
returns trigger
language plpgsql
as $$
declare
  v_user_clinic_id uuid;
begin
  select clinic_id
  into v_user_clinic_id
  from public.users
  where id = new.user_id;

  if v_user_clinic_id is null then
    raise exception 'User % was not found for client profile scope validation', new.user_id;
  end if;

  if new.clinic_id is null then
    new.clinic_id := v_user_clinic_id;
  elsif new.clinic_id <> v_user_clinic_id then
    raise exception 'Client profile clinic_id % does not match user clinic_id %', new.clinic_id, v_user_clinic_id;
  end if;

  return new;
end;
$$;

create table if not exists public.client_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.users(id) on delete cascade,
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  primary_regions jsonb not null default '[]'::jsonb,
  recovery_signals jsonb not null default '{}'::jsonb,
  goals text[] not null default '{}'::text[],
  activity_context text,
  sensitivities text[] not null default '{}'::text[],
  notes text,
  wearable_hrv numeric,
  wearable_strain numeric,
  wearable_sleep_score numeric,
  wearable_last_sync timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint client_profiles_primary_regions_chk
    check (public.validate_body_regions_json(primary_regions)),
  constraint client_profiles_recovery_signals_chk
    check (public.validate_recovery_signals_json(recovery_signals)),
  constraint client_profiles_goals_chk
    check (
      goals <@ array[
        'mobility',
        'warm_up',
        'recovery',
        'relaxation',
        'performance_prep'
      ]::text[]
    ),
  constraint client_profiles_wearable_hrv_chk
    check (wearable_hrv is null or wearable_hrv >= 0),
  constraint client_profiles_wearable_strain_chk
    check (wearable_strain is null or wearable_strain >= 0),
  constraint client_profiles_wearable_sleep_score_chk
    check (wearable_sleep_score is null or wearable_sleep_score between 0 and 100)
);

create index if not exists client_profiles_clinic_idx
  on public.client_profiles (clinic_id);

create index if not exists client_profiles_clinic_user_idx
  on public.client_profiles (clinic_id, user_id);

create index if not exists client_profiles_primary_regions_gin_idx
  on public.client_profiles
  using gin (primary_regions);

create index if not exists client_profiles_recovery_signals_gin_idx
  on public.client_profiles
  using gin (recovery_signals);

drop trigger if exists client_profiles_sync_clinic_id on public.client_profiles;
create trigger client_profiles_sync_clinic_id
before insert or update on public.client_profiles
for each row
execute function public.sync_client_profile_clinic_from_user();

drop trigger if exists set_client_profiles_updated_at on public.client_profiles;
create trigger set_client_profiles_updated_at
before update on public.client_profiles
for each row
execute function public.set_updated_at();
