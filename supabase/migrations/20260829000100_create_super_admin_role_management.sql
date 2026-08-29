-- ============================================================
-- SuperAdmin role management
-- ============================================================
--
-- Provides a trusted flow for institutional role changes.
--
-- Security rules:
--   * Only active superAdmin accounts may use these RPCs.
--   * The mobile client cannot create superAdmin accounts.
--   * A superAdmin cannot change their own role.
--   * Existing superAdmin accounts cannot be modified here.
--   * Every effective role change is audited.
-- ============================================================

-- ============================================================
-- Immutable role-change audit
-- ============================================================

create table if not exists public.profile_role_change_audit (
  id bigint generated always as identity primary key,

  actor_user_id uuid not null,
  target_user_id uuid not null,

  previous_role text not null,
  new_role text not null,

  changed_at timestamptz not null
    default timezone('utc', now()),

  constraint profile_role_change_audit_previous_role_valid
    check (
      previous_role in (
        'student',
        'teacher',
        'admin',
        'superAdmin'
      )
    ),

  constraint profile_role_change_audit_new_role_valid
    check (
      new_role in (
        'student',
        'teacher',
        'admin',
        'superAdmin'
      )
    )
);

comment on table public.profile_role_change_audit is
  'Immutable audit trail for institutional role changes performed by superAdmin users.';

create index if not exists profile_role_change_audit_actor_idx
  on public.profile_role_change_audit(actor_user_id);

create index if not exists profile_role_change_audit_target_idx
  on public.profile_role_change_audit(target_user_id);

create index if not exists profile_role_change_audit_changed_at_idx
  on public.profile_role_change_audit(changed_at desc);

alter table public.profile_role_change_audit
  enable row level security;

-- No direct client writes are allowed.
revoke all
on table public.profile_role_change_audit
from anon, authenticated;


-- ============================================================
-- Search profiles for role management
-- ============================================================

create or replace function public.search_role_management_profiles(
  p_query text default null,
  p_limit integer default 50
)
returns table (
  id uuid,
  email text,
  display_name text,
  role text,
  account_type text,
  staff_approval_pending boolean,
  active boolean,
  control_number text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  normalized_query text;
  effective_limit integer;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  if not public.is_super_admin() then
    raise exception 'SuperAdmin privileges required'
      using errcode = '42501';
  end if;

  normalized_query := nullif(trim(coalesce(p_query, '')), '');

  effective_limit := greatest(
    1,
    least(coalesce(p_limit, 50), 100)
  );

  return query
  select
    profile.id,
    profile.email,
    profile.display_name,
    profile.role,
    profile.account_type,
    profile.staff_approval_pending,
    profile.active,
    profile.control_number,
    profile.created_at
  from public.profiles as profile
  where
    normalized_query is null
    or profile.email ilike '%' || normalized_query || '%'
    or profile.display_name ilike '%' || normalized_query || '%'
    or profile.control_number ilike '%' || normalized_query || '%'
  order by
    case profile.role
      when 'superAdmin' then 0
      when 'admin' then 1
      when 'teacher' then 2
      else 3
    end,
    profile.display_name nulls last,
    profile.email nulls last
  limit effective_limit;
end;
$$;

revoke all
on function public.search_role_management_profiles(text, integer)
from public;

grant execute
on function public.search_role_management_profiles(text, integer)
to authenticated;

comment on function
  public.search_role_management_profiles(text, integer)
is
  'Searches institutional profiles for role management. Restricted to active superAdmin users.';


-- ============================================================
-- Trusted role update RPC
-- ============================================================

create or replace function public.update_profile_role_as_super_admin(
  p_user_id uuid,
  p_role text
)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  target_profile public.profiles;
  updated_profile public.profiles;
  normalized_role text;
begin
  actor_id := (select auth.uid());

  if actor_id is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  if not public.is_super_admin() then
    raise exception 'SuperAdmin privileges required'
      using errcode = '42501';
  end if;

  if p_user_id is null then
    raise exception 'Target user is required'
      using errcode = '22004';
  end if;

  if p_user_id = actor_id then
    raise exception 'A superAdmin cannot change their own role'
      using errcode = '42501';
  end if;

  normalized_role := trim(coalesce(p_role, ''));

  if normalized_role not in (
    'student',
    'teacher',
    'admin'
  ) then
    raise exception
      'Role must be student, teacher, or admin'
      using errcode = '22023';
  end if;

  select *
  into target_profile
  from public.profiles
  where id = p_user_id
  for update;

  if not found then
    raise exception 'Institutional profile not found'
      using errcode = 'P0002';
  end if;

  if target_profile.role = 'superAdmin' then
    raise exception
      'Existing superAdmin accounts cannot be modified from the mobile role-management flow'
      using errcode = '42501';
  end if;

  if target_profile.role = normalized_role then
    return target_profile;
  end if;

  update public.profiles
  set
    role = normalized_role,

    staff_approval_pending =
      case
        when account_type in ('campusStaff', 'tecnmStaff')
          then normalized_role = 'student'
        else false
      end,

    updated_at = timezone('utc', now())
  where id = p_user_id
  returning *
  into updated_profile;

  insert into public.profile_role_change_audit (
    actor_user_id,
    target_user_id,
    previous_role,
    new_role
  )
  values (
    actor_id,
    p_user_id,
    target_profile.role,
    updated_profile.role
  );

  return updated_profile;
end;
$$;

revoke all
on function public.update_profile_role_as_super_admin(uuid, text)
from public;

grant execute
on function public.update_profile_role_as_super_admin(uuid, text)
to authenticated;

comment on function
  public.update_profile_role_as_super_admin(uuid, text)
is
  'Changes an institutional role through a trusted superAdmin-only flow and records an immutable audit entry.';
