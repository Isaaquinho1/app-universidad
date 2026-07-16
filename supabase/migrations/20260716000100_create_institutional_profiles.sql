-- Conecta ITT
-- Institutional identity and academic segmentation schema.

begin;

create extension if not exists pgcrypto;

-- ============================================================
-- Shared timestamp trigger
-- ============================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

-- ============================================================
-- Careers
-- ============================================================

create table if not exists public.careers (
  id text primary key,
  name text not null,
  short_name text,
  active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint careers_id_format
    check (id ~ '^[a-z0-9][a-z0-9_-]*$'),

  constraint careers_name_not_blank
    check (length(trim(name)) > 0)
);

comment on table public.careers is
  'Academic programs offered by TecNM Campus Tlalpan.';

drop trigger if exists careers_set_updated_at on public.careers;

create trigger careers_set_updated_at
before update on public.careers
for each row
execute function public.set_updated_at();

-- ============================================================
-- Academic groups
-- ============================================================

create table if not exists public.academic_groups (
  id text primary key,
  career_id text references public.careers(id)
    on update cascade
    on delete restrict,
  name text not null,
  semester smallint,
  active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint academic_groups_id_format
    check (id ~ '^[A-Za-z0-9][A-Za-z0-9_-]*$'),

  constraint academic_groups_name_not_blank
    check (length(trim(name)) > 0),

  constraint academic_groups_semester_range
    check (semester is null or semester between 1 and 14)
);

comment on table public.academic_groups is
  'Academic groups available for announcement segmentation.';

create index if not exists academic_groups_career_id_idx
  on public.academic_groups(career_id);

create index if not exists academic_groups_semester_idx
  on public.academic_groups(semester);

drop trigger if exists academic_groups_set_updated_at
  on public.academic_groups;

create trigger academic_groups_set_updated_at
before update on public.academic_groups
for each row
execute function public.set_updated_at();

-- ============================================================
-- Institutional profiles
-- ============================================================

create table if not exists public.profiles (
  id uuid primary key references auth.users(id)
    on update cascade
    on delete cascade,

  email text,
  display_name text,

  role text not null default 'student',

  career_id text references public.careers(id)
    on update cascade
    on delete set null,

  semester smallint,

  group_id text references public.academic_groups(id)
    on update cascade
    on delete set null,

  control_number text,

  account_type text not null default 'student',
  staff_approval_pending boolean not null default false,

  profile_completed boolean not null default false,
  active boolean not null default true,

  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint profiles_role_valid
    check (
      role in (
        'student',
        'teacher',
        'admin',
        'superAdmin'
      )
    ),

  constraint profiles_account_type_valid
    check (
      account_type in (
        'student',
        'campusStaff',
        'tecnmStaff'
      )
    ),

  constraint profiles_semester_range
    check (semester is null or semester between 1 and 14),

  constraint profiles_control_number_format
    check (
      control_number is null
      or control_number ~ '^[0-9]{9}$'
    ),

  constraint profiles_email_lowercase
    check (email is null or email = lower(email))
);

comment on table public.profiles is
  'Institutional application profile linked one-to-one with auth.users.';

comment on column public.profiles.role is
  'Authoritative application role. Never trusted from client registration metadata.';

comment on column public.profiles.account_type is
  'Initial institutional account classification inferred from the email format.';

comment on column public.profiles.staff_approval_pending is
  'Indicates that a staff-like account still requires manual authorization.';

create unique index if not exists profiles_email_unique_idx
  on public.profiles(lower(email))
  where email is not null;

create unique index if not exists profiles_control_number_unique_idx
  on public.profiles(control_number)
  where control_number is not null;

create index if not exists profiles_role_idx
  on public.profiles(role);

create index if not exists profiles_career_id_idx
  on public.profiles(career_id);

create index if not exists profiles_semester_idx
  on public.profiles(semester);

create index if not exists profiles_group_id_idx
  on public.profiles(group_id);

create index if not exists profiles_active_idx
  on public.profiles(active);

drop trigger if exists profiles_set_updated_at on public.profiles;

create trigger profiles_set_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

-- ============================================================
-- FCM tokens
-- ============================================================

create table if not exists public.user_fcm_tokens (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null references public.profiles(id)
    on update cascade
    on delete cascade,

  device_id text not null,
  token text not null,
  platform text,
  active boolean not null default true,

  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  last_seen_at timestamptz not null default timezone('utc', now()),

  constraint user_fcm_tokens_device_id_not_blank
    check (length(trim(device_id)) > 0),

  constraint user_fcm_tokens_token_not_blank
    check (length(trim(token)) > 0),

  constraint user_fcm_tokens_platform_valid
    check (
      platform is null
      or platform in ('android', 'ios', 'web', 'macos', 'windows')
    ),

  constraint user_fcm_tokens_user_device_unique
    unique (user_id, device_id)
);

comment on table public.user_fcm_tokens is
  'Firebase Cloud Messaging tokens registered per user device.';

create unique index if not exists user_fcm_tokens_token_unique_idx
  on public.user_fcm_tokens(token);

create index if not exists user_fcm_tokens_user_id_idx
  on public.user_fcm_tokens(user_id);

create index if not exists user_fcm_tokens_active_idx
  on public.user_fcm_tokens(active);

drop trigger if exists user_fcm_tokens_set_updated_at
  on public.user_fcm_tokens;

create trigger user_fcm_tokens_set_updated_at
before update on public.user_fcm_tokens
for each row
execute function public.set_updated_at();

-- ============================================================
-- Profile creation from auth.users
-- ============================================================

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_email text;
  local_part text;
  detected_account_type text;
  detected_control_number text;
  approval_pending boolean;
begin
  normalized_email := lower(trim(coalesce(new.email, '')));
  local_part := split_part(normalized_email, '@', 1);

  if normalized_email ~ '^l[0-9]{9}@tlalpan\.tecnm\.mx$' then
    detected_account_type := 'student';
    detected_control_number := substring(local_part from 2);
    approval_pending := false;

  elsif normalized_email ~ '^[a-z0-9._%+-]+@tlalpan\.tecnm\.mx$' then
    detected_account_type := 'campusStaff';
    detected_control_number := null;
    approval_pending := true;

  elsif normalized_email ~ '^[a-z0-9._%+-]+@tecnm\.mx$' then
    detected_account_type := 'tecnmStaff';
    detected_control_number := null;
    approval_pending := true;

  else
    raise exception
      'Unsupported institutional email domain: %',
      normalized_email
      using errcode = 'check_violation';
  end if;

  insert into public.profiles (
    id,
    email,
    display_name,
    role,
    control_number,
    account_type,
    staff_approval_pending,
    profile_completed,
    active
  )
  values (
    new.id,
    nullif(normalized_email, ''),
    nullif(
      trim(
        coalesce(
          new.raw_user_meta_data ->> 'display_name',
          new.raw_user_meta_data ->> 'name',
          ''
        )
      ),
      ''
    ),
    'student',
    detected_control_number,
    detected_account_type,
    approval_pending,
    false,
    true
  )
  on conflict (id) do update
  set
    email = excluded.email,
    display_name = coalesce(
      public.profiles.display_name,
      excluded.display_name
    ),
    control_number = coalesce(
      public.profiles.control_number,
      excluded.control_number
    ),
    account_type = excluded.account_type,
    staff_approval_pending =
      public.profiles.staff_approval_pending
      or excluded.staff_approval_pending,
    updated_at = timezone('utc', now());

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_auth_user();

-- ============================================================
-- Backfill existing institutional auth users
-- ============================================================

insert into public.profiles (
  id,
  email,
  display_name,
  role,
  control_number,
  account_type,
  staff_approval_pending,
  profile_completed,
  active
)
select
  auth_user.id,
  lower(trim(auth_user.email)),
  nullif(
    trim(
      coalesce(
        auth_user.raw_user_meta_data ->> 'display_name',
        auth_user.raw_user_meta_data ->> 'name',
        ''
      )
    ),
    ''
  ),
  'student',
  case
    when lower(trim(auth_user.email))
      ~ '^l[0-9]{9}@tlalpan\.tecnm\.mx$'
    then substring(
      split_part(lower(trim(auth_user.email)), '@', 1)
      from 2
    )
    else null
  end,
  case
    when lower(trim(auth_user.email))
      ~ '^l[0-9]{9}@tlalpan\.tecnm\.mx$'
    then 'student'

    when lower(trim(auth_user.email))
      ~ '^[a-z0-9._%+-]+@tlalpan\.tecnm\.mx$'
    then 'campusStaff'

    when lower(trim(auth_user.email))
      ~ '^[a-z0-9._%+-]+@tecnm\.mx$'
    then 'tecnmStaff'
  end,
  lower(trim(auth_user.email))
    !~ '^l[0-9]{9}@tlalpan\.tecnm\.mx$',
  false,
  true
from auth.users as auth_user
where auth_user.email is not null
  and (
    lower(trim(auth_user.email))
      ~ '^l[0-9]{9}@tlalpan\.tecnm\.mx$'
    or lower(trim(auth_user.email))
      ~ '^[a-z0-9._%+-]+@tlalpan\.tecnm\.mx$'
    or lower(trim(auth_user.email))
      ~ '^[a-z0-9._%+-]+@tecnm\.mx$'
  )
on conflict (id) do update
set
  email = excluded.email,
  display_name = coalesce(
    public.profiles.display_name,
    excluded.display_name
  ),
  control_number = coalesce(
    public.profiles.control_number,
    excluded.control_number
  ),
  account_type = excluded.account_type,
  staff_approval_pending =
    public.profiles.staff_approval_pending
    or excluded.staff_approval_pending,
  updated_at = timezone('utc', now());

-- ============================================================
-- Authorization helpers
-- ============================================================

create or replace function public.current_profile_role()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select role
  from public.profiles
  where id = (select auth.uid())
    and active = true;
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select role in ('admin', 'superAdmin')
      from public.profiles
      where id = (select auth.uid())
        and active = true
    ),
    false
  );
$$;

create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select role = 'superAdmin'
      from public.profiles
      where id = (select auth.uid())
        and active = true
    ),
    false
  );
$$;

revoke all on function public.current_profile_role() from public;
revoke all on function public.is_admin() from public;
revoke all on function public.is_super_admin() from public;

grant execute on function public.current_profile_role() to authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_super_admin() to authenticated;

-- ============================================================
-- Controlled profile update RPC
-- ============================================================

create or replace function public.update_own_profile(
  p_display_name text default null,
  p_career_id text default null,
  p_semester smallint default null,
  p_group_id text default null,
  p_profile_completed boolean default null
)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  updated_profile public.profiles;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required'
      using errcode = 'insufficient_privilege';
  end if;

  if p_semester is not null and (p_semester < 1 or p_semester > 14) then
    raise exception 'Semester must be between 1 and 14'
      using errcode = 'check_violation';
  end if;

  if p_career_id is not null
     and not exists (
       select 1
       from public.careers
       where id = p_career_id
         and active = true
     ) then
    raise exception 'Invalid or inactive career'
      using errcode = 'foreign_key_violation';
  end if;

  if p_group_id is not null
     and not exists (
       select 1
       from public.academic_groups
       where id = p_group_id
         and active = true
     ) then
    raise exception 'Invalid or inactive academic group'
      using errcode = 'foreign_key_violation';
  end if;

  update public.profiles
  set
    display_name = coalesce(
      nullif(trim(p_display_name), ''),
      display_name
    ),
    career_id = coalesce(p_career_id, career_id),
    semester = coalesce(p_semester, semester),
    group_id = coalesce(p_group_id, group_id),
    profile_completed = coalesce(
      p_profile_completed,
      profile_completed
    ),
    updated_at = timezone('utc', now())
  where id = (select auth.uid())
    and active = true
  returning *
  into updated_profile;

  if updated_profile.id is null then
    raise exception 'Active profile not found'
      using errcode = 'no_data_found';
  end if;

  return updated_profile;
end;
$$;

revoke all on function public.update_own_profile(
  text,
  text,
  smallint,
  text,
  boolean
) from public;

grant execute on function public.update_own_profile(
  text,
  text,
  smallint,
  text,
  boolean
) to authenticated;

-- ============================================================
-- Row Level Security
-- ============================================================

alter table public.careers enable row level security;
alter table public.academic_groups enable row level security;
alter table public.profiles enable row level security;
alter table public.user_fcm_tokens enable row level security;

drop policy if exists careers_authenticated_read
  on public.careers;

create policy careers_authenticated_read
on public.careers
for select
to authenticated
using (active = true or (select public.is_admin()));

drop policy if exists academic_groups_authenticated_read
  on public.academic_groups;

create policy academic_groups_authenticated_read
on public.academic_groups
for select
to authenticated
using (active = true or (select public.is_admin()));

drop policy if exists profiles_read_own
  on public.profiles;

create policy profiles_read_own
on public.profiles
for select
to authenticated
using ((select auth.uid()) = id);

drop policy if exists profiles_admin_read
  on public.profiles;

create policy profiles_admin_read
on public.profiles
for select
to authenticated
using ((select public.is_admin()));

-- Direct profile inserts are performed by the auth trigger.
-- Direct student updates are intentionally denied.
-- Students must use public.update_own_profile().
-- Role changes will later use a dedicated superAdmin RPC.

drop policy if exists user_fcm_tokens_read_own
  on public.user_fcm_tokens;

create policy user_fcm_tokens_read_own
on public.user_fcm_tokens
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists user_fcm_tokens_insert_own
  on public.user_fcm_tokens;

create policy user_fcm_tokens_insert_own
on public.user_fcm_tokens
for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists user_fcm_tokens_update_own
  on public.user_fcm_tokens;

create policy user_fcm_tokens_update_own
on public.user_fcm_tokens
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists user_fcm_tokens_delete_own
  on public.user_fcm_tokens;

create policy user_fcm_tokens_delete_own
on public.user_fcm_tokens
for delete
to authenticated
using ((select auth.uid()) = user_id);

-- ============================================================
-- Data API privileges
-- ============================================================

revoke all on table public.profiles from anon;
revoke all on table public.careers from anon;
revoke all on table public.academic_groups from anon;
revoke all on table public.user_fcm_tokens from anon;

grant select on table public.profiles to authenticated;
grant select on table public.careers to authenticated;
grant select on table public.academic_groups to authenticated;

grant select, insert, update, delete
  on table public.user_fcm_tokens
  to authenticated;

commit;
