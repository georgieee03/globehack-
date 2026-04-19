create table if not exists public.devices (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  device_mac text not null,
  label text not null,
  room text,
  assigned_practitioner uuid references public.users(id) on delete set null,
  status text not null default 'idle'
    check (status in ('idle', 'in_session', 'paused', 'maintenance', 'offline')),
  last_session_id uuid,
  firmware text,
  last_seen_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint devices_device_mac_format_chk
    check (device_mac ~* '^([0-9A-F]{2}[:-]){5}[0-9A-F]{2}$'),
  constraint devices_label_not_blank_chk check (btrim(label) <> '')
);

create or replace function public.ensure_device_practitioner_matches_clinic()
returns trigger
language plpgsql
as $$
declare
  v_practitioner_clinic_id uuid;
begin
  if new.assigned_practitioner is null then
    return new;
  end if;

  select clinic_id
  into v_practitioner_clinic_id
  from public.users
  where id = new.assigned_practitioner;

  if v_practitioner_clinic_id is null then
    raise exception 'Assigned practitioner % was not found', new.assigned_practitioner;
  end if;

  if v_practitioner_clinic_id <> new.clinic_id then
    raise exception 'Assigned practitioner clinic % does not match device clinic %', v_practitioner_clinic_id, new.clinic_id;
  end if;

  return new;
end;
$$;

create unique index if not exists devices_clinic_device_mac_uidx
  on public.devices (clinic_id, lower(device_mac));

create index if not exists devices_clinic_status_idx
  on public.devices (clinic_id, status);

create index if not exists devices_assigned_practitioner_idx
  on public.devices (assigned_practitioner);

drop trigger if exists devices_validate_practitioner_scope on public.devices;
create trigger devices_validate_practitioner_scope
before insert or update on public.devices
for each row
execute function public.ensure_device_practitioner_matches_clinic();

drop trigger if exists set_devices_updated_at on public.devices;
create trigger set_devices_updated_at
before update on public.devices
for each row
execute function public.set_updated_at();
