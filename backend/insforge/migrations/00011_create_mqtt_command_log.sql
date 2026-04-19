create table if not exists public.mqtt_command_log (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  device_id uuid not null references public.devices(id) on delete cascade,
  command text not null check (command in ('start', 'pause', 'resume', 'stop', 'maintenance')),
  payload jsonb not null,
  mqtt_response_status integer,
  error_details text,
  simulated boolean not null default false,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint mqtt_command_log_payload_chk
    check (jsonb_typeof(payload) = 'object')
);

create index if not exists mqtt_command_log_clinic_created_at_idx
  on public.mqtt_command_log (clinic_id, created_at desc);

create index if not exists mqtt_command_log_device_created_at_idx
  on public.mqtt_command_log (device_id, created_at desc);

create index if not exists mqtt_command_log_command_created_at_idx
  on public.mqtt_command_log (command, created_at desc);
