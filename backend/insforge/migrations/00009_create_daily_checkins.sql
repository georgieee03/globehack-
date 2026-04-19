create table if not exists public.daily_checkins (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.client_profiles(id) on delete cascade,
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  checkin_type text not null
    check (checkin_type in ('daily', 'post_activity', 'pre_visit')),
  overall_feeling integer not null check (overall_feeling between 1 and 5),
  target_regions jsonb not null default '[]'::jsonb,
  activity_since_last text,
  recovery_score numeric check (recovery_score is null or recovery_score between 0 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint daily_checkins_target_regions_chk
    check (jsonb_typeof(target_regions) = 'array')
);

create index if not exists daily_checkins_client_created_at_idx
  on public.daily_checkins (client_id, created_at desc);

create index if not exists daily_checkins_clinic_type_created_at_idx
  on public.daily_checkins (clinic_id, checkin_type, created_at desc);

drop trigger if exists daily_checkins_sync_clinic_id on public.daily_checkins;
create trigger daily_checkins_sync_clinic_id
before insert or update on public.daily_checkins
for each row
execute function public.sync_clinic_id_from_client_profile();

drop trigger if exists set_daily_checkins_updated_at on public.daily_checkins;
create trigger set_daily_checkins_updated_at
before update on public.daily_checkins
for each row
execute function public.set_updated_at();
