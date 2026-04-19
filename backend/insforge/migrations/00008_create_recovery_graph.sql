create table if not exists public.recovery_graph (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.client_profiles(id) on delete cascade,
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  body_region text not null default 'overall',
  metric_type text not null,
  value numeric not null,
  source text not null,
  source_id uuid,
  recorded_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint recovery_graph_body_region_chk
    check (body_region = 'overall' or public.is_valid_body_region(body_region)),
  constraint recovery_graph_metric_type_not_blank_chk
    check (btrim(metric_type) <> ''),
  constraint recovery_graph_source_not_blank_chk
    check (btrim(source) <> '')
);

create index if not exists recovery_graph_client_region_recorded_at_idx
  on public.recovery_graph (client_id, body_region, recorded_at desc);

create index if not exists recovery_graph_client_metric_recorded_at_idx
  on public.recovery_graph (client_id, metric_type, recorded_at desc);

create index if not exists recovery_graph_clinic_metric_recorded_at_idx
  on public.recovery_graph (clinic_id, metric_type, recorded_at desc);

drop trigger if exists recovery_graph_sync_clinic_id on public.recovery_graph;
create trigger recovery_graph_sync_clinic_id
before insert or update on public.recovery_graph
for each row
execute function public.sync_clinic_id_from_client_profile();
