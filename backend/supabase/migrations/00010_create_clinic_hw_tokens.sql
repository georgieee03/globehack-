create table if not exists public.clinic_hw_tokens (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null unique references public.clinics(id) on delete cascade,
  access_token text not null,
  refresh_token text not null,
  access_token_expires_at timestamptz,
  refresh_token_expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint clinic_hw_tokens_access_token_not_blank_chk
    check (btrim(access_token) <> ''),
  constraint clinic_hw_tokens_refresh_token_not_blank_chk
    check (btrim(refresh_token) <> '')
);

drop trigger if exists set_clinic_hw_tokens_updated_at on public.clinic_hw_tokens;
create trigger set_clinic_hw_tokens_updated_at
before update on public.clinic_hw_tokens
for each row
execute function public.set_updated_at();
