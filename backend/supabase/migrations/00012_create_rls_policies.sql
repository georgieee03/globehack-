grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant execute on all functions in schema public to authenticated;

alter default privileges in schema public
grant select, insert, update, delete on tables to authenticated;

alter default privileges in schema public
grant execute on functions to authenticated;

create or replace function public.current_user_clinic_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select clinic_id
  from public.users
  where id = auth.uid();
$$;

create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role
  from public.users
  where id = auth.uid();
$$;

create or replace function public.current_user_client_profile_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id
  from public.client_profiles
  where user_id = auth.uid();
$$;

create or replace function public.guard_device_updates()
returns trigger
language plpgsql
as $$
begin
  if auth.uid() is null then
    return new;
  end if;

  if public.current_user_role() <> 'practitioner' then
    return new;
  end if;

  if new.clinic_id <> public.current_user_clinic_id() then
    raise exception 'Practitioners may only update devices in their own clinic';
  end if;

  if new.device_mac is distinct from old.device_mac
    or new.label is distinct from old.label
    or new.room is distinct from old.room
    or new.assigned_practitioner is distinct from old.assigned_practitioner
    or new.firmware is distinct from old.firmware
    or new.clinic_id is distinct from old.clinic_id then
    raise exception 'Practitioners may only update device status fields';
  end if;

  return new;
end;
$$;

drop trigger if exists guard_devices_for_practitioners on public.devices;
create trigger guard_devices_for_practitioners
before update on public.devices
for each row
execute function public.guard_device_updates();

alter table public.clinics enable row level security;
alter table public.users enable row level security;
alter table public.devices enable row level security;
alter table public.client_profiles enable row level security;
alter table public.assessments enable row level security;
alter table public.sessions enable row level security;
alter table public.outcomes enable row level security;
alter table public.recovery_graph enable row level security;
alter table public.daily_checkins enable row level security;
alter table public.clinic_hw_tokens enable row level security;
alter table public.mqtt_command_log enable row level security;

create policy clinics_select_own
on public.clinics
for select
using (id = public.current_user_clinic_id());

create policy clinics_update_admin
on public.clinics
for update
using (
  id = public.current_user_clinic_id()
  and public.current_user_role() = 'admin'
)
with check (
  id = public.current_user_clinic_id()
  and public.current_user_role() = 'admin'
);

create policy users_select_same_clinic
on public.users
for select
using (clinic_id = public.current_user_clinic_id());

create policy users_insert_admin_same_clinic
on public.users
for insert
with check (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() = 'admin'
);

create policy users_update_self
on public.users
for update
using (id = auth.uid())
with check (
  id = auth.uid()
  and clinic_id = public.current_user_clinic_id()
  and role = public.current_user_role()
);

create policy users_update_admin_same_clinic
on public.users
for update
using (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() = 'admin'
)
with check (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() = 'admin'
);

create policy users_delete_admin_same_clinic
on public.users
for delete
using (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() = 'admin'
);

create policy devices_select_same_clinic
on public.devices
for select
using (clinic_id = public.current_user_clinic_id());

create policy devices_insert_admin_same_clinic
on public.devices
for insert
with check (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() = 'admin'
);

create policy devices_update_admin_same_clinic
on public.devices
for update
using (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() = 'admin'
)
with check (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() = 'admin'
);

create policy devices_update_practitioner_same_clinic
on public.devices
for update
using (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() = 'practitioner'
)
with check (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() = 'practitioner'
);

create policy devices_delete_admin_same_clinic
on public.devices
for delete
using (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() = 'admin'
);

create policy client_profiles_select_own
on public.client_profiles
for select
using (user_id = auth.uid());

create policy client_profiles_select_clinic_staff
on public.client_profiles
for select
using (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() in ('practitioner', 'admin')
);

create policy client_profiles_insert_admin_same_clinic
on public.client_profiles
for insert
with check (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() = 'admin'
);

create policy client_profiles_update_own
on public.client_profiles
for update
using (user_id = auth.uid())
with check (
  user_id = auth.uid()
  and clinic_id = public.current_user_clinic_id()
);

create policy client_profiles_update_clinic_staff
on public.client_profiles
for update
using (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() in ('practitioner', 'admin')
)
with check (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() in ('practitioner', 'admin')
);

create policy client_profiles_delete_admin_same_clinic
on public.client_profiles
for delete
using (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() = 'admin'
);

create policy assessments_select_own
on public.assessments
for select
using (client_id = public.current_user_client_profile_id());

create policy assessments_select_clinic_staff
on public.assessments
for select
using (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() in ('practitioner', 'admin')
);

create policy assessments_insert_own
on public.assessments
for insert
with check (
  client_id = public.current_user_client_profile_id()
  and clinic_id = public.current_user_clinic_id()
);

create policy assessments_insert_clinic_staff
on public.assessments
for insert
with check (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() in ('practitioner', 'admin')
);

create policy assessments_update_clinic_staff
on public.assessments
for update
using (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() in ('practitioner', 'admin')
)
with check (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() in ('practitioner', 'admin')
);

create policy sessions_select_own
on public.sessions
for select
using (client_id = public.current_user_client_profile_id());

create policy sessions_select_clinic_staff
on public.sessions
for select
using (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() in ('practitioner', 'admin')
);

create policy sessions_insert_clinic_staff
on public.sessions
for insert
with check (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() in ('practitioner', 'admin')
);

create policy sessions_update_clinic_staff
on public.sessions
for update
using (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() in ('practitioner', 'admin')
)
with check (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() in ('practitioner', 'admin')
);

create policy outcomes_select_own
on public.outcomes
for select
using (client_id = public.current_user_client_profile_id());

create policy outcomes_select_clinic_staff
on public.outcomes
for select
using (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() in ('practitioner', 'admin')
);

create policy outcomes_insert_own
on public.outcomes
for insert
with check (
  client_id = public.current_user_client_profile_id()
  and clinic_id = public.current_user_clinic_id()
  and recorded_by = 'client'
  and recorded_by_user_id = auth.uid()
);

create policy outcomes_insert_clinic_staff
on public.outcomes
for insert
with check (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() in ('practitioner', 'admin')
  and recorded_by = 'practitioner'
  and recorded_by_user_id = auth.uid()
);

create policy outcomes_update_author
on public.outcomes
for update
using (recorded_by_user_id = auth.uid())
with check (
  recorded_by_user_id = auth.uid()
  and clinic_id = public.current_user_clinic_id()
);

create policy daily_checkins_select_own
on public.daily_checkins
for select
using (client_id = public.current_user_client_profile_id());

create policy daily_checkins_select_clinic_staff
on public.daily_checkins
for select
using (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() in ('practitioner', 'admin')
);

create policy daily_checkins_insert_own
on public.daily_checkins
for insert
with check (
  client_id = public.current_user_client_profile_id()
  and clinic_id = public.current_user_clinic_id()
);

create policy daily_checkins_update_own
on public.daily_checkins
for update
using (client_id = public.current_user_client_profile_id())
with check (
  client_id = public.current_user_client_profile_id()
  and clinic_id = public.current_user_clinic_id()
);

create policy recovery_graph_select_own
on public.recovery_graph
for select
using (client_id = public.current_user_client_profile_id());

create policy recovery_graph_select_clinic_staff
on public.recovery_graph
for select
using (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() in ('practitioner', 'admin')
);

create policy clinic_hw_tokens_select_admin
on public.clinic_hw_tokens
for select
using (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() = 'admin'
);

create policy clinic_hw_tokens_insert_admin
on public.clinic_hw_tokens
for insert
with check (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() = 'admin'
);

create policy clinic_hw_tokens_update_admin
on public.clinic_hw_tokens
for update
using (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() = 'admin'
)
with check (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() = 'admin'
);

create policy clinic_hw_tokens_delete_admin
on public.clinic_hw_tokens
for delete
using (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() = 'admin'
);

create policy mqtt_command_log_select_clinic_staff
on public.mqtt_command_log
for select
using (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() in ('practitioner', 'admin')
);
