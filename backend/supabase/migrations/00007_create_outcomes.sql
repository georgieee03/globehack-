create or replace function public.sync_outcome_scope()
returns trigger
language plpgsql
as $$
declare
  v_session_client_id uuid;
  v_session_clinic_id uuid;
begin
  select client_id, clinic_id
  into v_session_client_id, v_session_clinic_id
  from public.sessions
  where id = new.session_id;

  if v_session_client_id is null or v_session_clinic_id is null then
    raise exception 'Session % was not found for outcome scope validation', new.session_id;
  end if;

  if new.client_id is null then
    new.client_id := v_session_client_id;
  elsif new.client_id <> v_session_client_id then
    raise exception 'Outcome client_id % does not match session client_id %', new.client_id, v_session_client_id;
  end if;

  if new.clinic_id is null then
    new.clinic_id := v_session_clinic_id;
  elsif new.clinic_id <> v_session_clinic_id then
    raise exception 'Outcome clinic_id % does not match session clinic_id %', new.clinic_id, v_session_clinic_id;
  end if;

  if new.recorded_by_user_id is null and auth.uid() is not null then
    new.recorded_by_user_id := auth.uid();
  end if;

  return new;
end;
$$;

create table if not exists public.outcomes (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.sessions(id) on delete cascade,
  client_id uuid not null references public.client_profiles(id) on delete cascade,
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  recorded_by text not null check (recorded_by in ('client', 'practitioner')),
  recorded_by_user_id uuid not null references public.users(id) on delete restrict,
  stiffness_before integer check (stiffness_before between 0 and 10),
  stiffness_after integer check (stiffness_after between 0 and 10),
  soreness_before integer check (soreness_before between 0 and 10),
  soreness_after integer check (soreness_after between 0 and 10),
  mobility_improved text check (mobility_improved in ('yes', 'maybe', 'no')),
  session_effective text check (session_effective in ('yes', 'maybe', 'no')),
  readiness_improved text check (readiness_improved in ('yes', 'maybe', 'no')),
  repeat_intent text check (repeat_intent in ('yes', 'maybe', 'no_try_different')),
  rom_after jsonb,
  rom_delta jsonb,
  client_notes text,
  practitioner_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint outcomes_rom_after_chk
    check (rom_after is null or jsonb_typeof(rom_after) = 'object'),
  constraint outcomes_rom_delta_chk
    check (rom_delta is null or jsonb_typeof(rom_delta) = 'object')
);

create unique index if not exists outcomes_session_recorded_by_uidx
  on public.outcomes (session_id, recorded_by);

create index if not exists outcomes_client_created_at_idx
  on public.outcomes (client_id, created_at desc);

create index if not exists outcomes_clinic_created_at_idx
  on public.outcomes (clinic_id, created_at desc);

create index if not exists outcomes_recorded_by_user_idx
  on public.outcomes (recorded_by_user_id);

drop trigger if exists outcomes_sync_scope on public.outcomes;
create trigger outcomes_sync_scope
before insert or update on public.outcomes
for each row
execute function public.sync_outcome_scope();

drop trigger if exists set_outcomes_updated_at on public.outcomes;
create trigger set_outcomes_updated_at
before update on public.outcomes
for each row
execute function public.set_updated_at();
