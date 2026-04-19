create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  clinic_id uuid not null references public.clinics(id) on delete restrict,
  role text not null check (role in ('client', 'practitioner', 'admin')),
  email text not null,
  full_name text not null,
  phone text,
  date_of_birth date,
  auth_provider text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint users_email_format_chk check (position('@' in email) > 1),
  constraint users_full_name_not_blank_chk check (btrim(full_name) <> '')
);

create unique index if not exists users_email_lower_uidx
  on public.users (lower(email));

create index if not exists users_clinic_idx
  on public.users (clinic_id);

create index if not exists users_clinic_role_idx
  on public.users (clinic_id, role);

drop trigger if exists set_users_updated_at on public.users;
create trigger set_users_updated_at
before update on public.users
for each row
execute function public.set_updated_at();
