create table if not exists public.clinic_invites (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  role text not null check (role in ('client', 'practitioner', 'admin')),
  invite_code text not null unique,
  email text,
  invited_by uuid references public.users(id) on delete set null,
  claimed_by uuid references public.users(id) on delete set null,
  expires_at timestamptz,
  claimed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint clinic_invites_email_format_chk
    check (email is null or position('@' in email) > 1),
  constraint clinic_invites_invite_code_not_blank_chk
    check (btrim(invite_code) <> ''),
  constraint clinic_invites_expires_at_chk
    check (expires_at is null or expires_at > created_at)
);

create index if not exists clinic_invites_clinic_idx
  on public.clinic_invites (clinic_id);

create index if not exists clinic_invites_email_idx
  on public.clinic_invites (lower(email));

drop trigger if exists set_clinic_invites_updated_at on public.clinic_invites;
create trigger set_clinic_invites_updated_at
before update on public.clinic_invites
for each row
execute function public.set_updated_at();

create or replace function public.generate_invite_code(p_length integer default 8)
returns text
language plpgsql
volatile
as $$
begin
  if p_length < 6 then
    raise exception 'Invite codes must be at least 6 characters long';
  end if;

  return upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, p_length));
end;
$$;

create or replace function public.ensure_client_profile_for_client_user()
returns trigger
language plpgsql
as $$
begin
  if new.role = 'client' then
    insert into public.client_profiles (user_id, clinic_id)
    values (new.id, new.clinic_id)
    on conflict (user_id) do update
      set clinic_id = excluded.clinic_id,
          updated_at = now();
  end if;

  return new;
end;
$$;

drop trigger if exists users_ensure_client_profile on public.users;
create trigger users_ensure_client_profile
after insert or update of role, clinic_id on public.users
for each row
execute function public.ensure_client_profile_for_client_user();

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_invite_code text;
  v_invite public.clinic_invites%rowtype;
  v_clinic_id uuid;
  v_role text := coalesce(new.metadata ->> 'role', 'client');
  v_full_name text := coalesce(
    nullif(new.profile ->> 'name', ''),
    nullif(new.metadata ->> 'full_name', ''),
    split_part(coalesce(new.email, 'hydrascan-user@example.com'), '@', 1)
  );
  v_auth_provider text;
begin
  if exists (select 1 from public.users where id = new.id) then
    return new;
  end if;

  select provider
  into v_auth_provider
  from auth.user_providers
  where user_id = new.id
  order by created_at asc
  limit 1;

  v_auth_provider := coalesce(
    v_auth_provider,
    nullif(new.metadata ->> 'auth_provider', ''),
    'email'
  );

  v_invite_code := coalesce(
    nullif(new.metadata ->> 'invite_code', ''),
    nullif(new.metadata ->> 'clinic_invite_code', '')
  );

  if v_invite_code is not null then
    select *
    into v_invite
    from public.clinic_invites
    where invite_code = v_invite_code
      and claimed_at is null
      and (expires_at is null or expires_at > now())
      and (email is null or lower(email) = lower(coalesce(new.email, '')))
    order by created_at desc
    limit 1;
  elsif new.email is not null then
    select *
    into v_invite
    from public.clinic_invites
    where lower(email) = lower(new.email)
      and claimed_at is null
      and (expires_at is null or expires_at > now())
    order by created_at desc
    limit 1;
  end if;

  if v_invite.id is not null then
    v_clinic_id := v_invite.clinic_id;
    v_role := v_invite.role;
  elsif nullif(new.metadata ->> 'clinic_id', '') is not null then
    v_clinic_id := (new.metadata ->> 'clinic_id')::uuid;
  else
    return new;
  end if;

  insert into public.users (
    id,
    clinic_id,
    role,
    email,
    full_name,
    auth_provider,
    avatar_url
  )
  values (
    new.id,
    v_clinic_id,
    v_role,
    coalesce(new.email, new.id::text || '@placeholder.local'),
    v_full_name,
    v_auth_provider,
    coalesce(new.profile ->> 'avatar_url', new.metadata ->> 'avatar_url')
  )
  on conflict (id) do nothing;

  if v_invite.id is not null then
    update public.clinic_invites
    set claimed_by = new.id,
        claimed_at = now(),
        updated_at = now()
    where id = v_invite.id;
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_hydrascan on auth.users;
create trigger on_auth_user_created_hydrascan
after insert on auth.users
for each row
execute function public.handle_new_auth_user();

create or replace function public.sync_user_provider_from_auth_provider()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  update public.users
  set auth_provider = new.provider,
      updated_at = now()
  where id = new.user_id
    and coalesce(auth_provider, '') is distinct from coalesce(new.provider, '');

  return new;
end;
$$;

drop trigger if exists on_auth_user_provider_changed_hydrascan on auth.user_providers;
create trigger on_auth_user_provider_changed_hydrascan
after insert or update of provider on auth.user_providers
for each row
execute function public.sync_user_provider_from_auth_provider();

create or replace function public.create_clinic_for_current_user(
  p_name text,
  p_address text default null,
  p_timezone text default 'America/Phoenix'
)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_auth_email text;
  v_full_name text;
  v_provider text;
  v_avatar_url text;
  v_clinic_id uuid;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if exists (select 1 from public.users where id = v_user_id) then
    raise exception 'Current user is already assigned to a clinic';
  end if;

  select
    email,
    coalesce(
      nullif(profile ->> 'name', ''),
      nullif(metadata ->> 'full_name', ''),
      split_part(coalesce(email, 'hydrascan-admin@example.com'), '@', 1)
    ),
    coalesce(
      (
        select provider
        from auth.user_providers
        where user_id = v_user_id
        order by created_at asc
        limit 1
      ),
      nullif(metadata ->> 'auth_provider', ''),
      'email'
    ),
    coalesce(profile ->> 'avatar_url', metadata ->> 'avatar_url')
  into
    v_auth_email,
    v_full_name,
    v_provider,
    v_avatar_url
  from auth.users
  where id = v_user_id;

  if v_auth_email is null then
    raise exception 'Authenticated user email is required to create a clinic';
  end if;

  insert into public.clinics (name, address, timezone)
  values (p_name, p_address, coalesce(nullif(p_timezone, ''), 'America/Phoenix'))
  returning id into v_clinic_id;

  insert into public.users (
    id,
    clinic_id,
    role,
    email,
    full_name,
    auth_provider,
    avatar_url
  )
  values (
    v_user_id,
    v_clinic_id,
    'admin',
    v_auth_email,
    v_full_name,
    v_provider,
    v_avatar_url
  );

  insert into public.clinic_invites (
    clinic_id,
    role,
    invite_code,
    invited_by
  )
  values (
    v_clinic_id,
    'client',
    public.generate_invite_code(),
    v_user_id
  );

  return v_clinic_id;
end;
$$;

grant execute on function public.create_clinic_for_current_user(text, text, text) to authenticated;

alter table public.clinic_invites enable row level security;

create policy clinic_invites_select_admin_same_clinic
on public.clinic_invites
for select
using (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() = 'admin'
);

create policy clinic_invites_insert_admin_same_clinic
on public.clinic_invites
for insert
with check (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() = 'admin'
);

create policy clinic_invites_update_admin_same_clinic
on public.clinic_invites
for update
using (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() = 'admin'
)
with check (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() = 'admin'
);

create policy clinic_invites_delete_admin_same_clinic
on public.clinic_invites
for delete
using (
  clinic_id = public.current_user_clinic_id()
  and public.current_user_role() = 'admin'
);
