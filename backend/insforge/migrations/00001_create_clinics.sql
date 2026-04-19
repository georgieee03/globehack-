create table if not exists public.clinics (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address text,
  timezone text not null default 'America/Phoenix',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint clinics_name_not_blank_chk check (btrim(name) <> ''),
  constraint clinics_timezone_not_blank_chk check (btrim(timezone) <> '')
);

create index if not exists clinics_name_idx
  on public.clinics (lower(name));

drop trigger if exists set_clinics_updated_at on public.clinics;
create trigger set_clinics_updated_at
before update on public.clinics
for each row
execute function public.set_updated_at();
