-- ============================================================
-- Conecta ITT
-- Administrative RPCs for institutional teaching assignments
-- ============================================================

begin;

-- ============================================================
-- Search approved teachers
-- ============================================================

create or replace function public.search_teachers_as_admin(
  p_query text default null,
  p_limit integer default 50
)
returns table (
  id uuid,
  email text,
  display_name text,
  account_type text,
  active boolean
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

  if not public.is_admin() then
    raise exception 'Admin privileges required'
      using errcode = '42501';
  end if;

  normalized_query :=
    nullif(trim(coalesce(p_query, '')), '');

  effective_limit :=
    greatest(1, least(coalesce(p_limit, 50), 100));

  return query
  select
    profile.id,
    profile.email,
    profile.display_name,
    profile.account_type,
    profile.active
  from public.profiles as profile
  where profile.role = 'teacher'
    and profile.staff_approval_pending = false
    and (
      normalized_query is null
      or profile.email ilike '%' || normalized_query || '%'
      or profile.display_name ilike '%' || normalized_query || '%'
    )
  order by
    profile.active desc,
    profile.display_name nulls last,
    profile.email nulls last
  limit effective_limit;
end;
$$;

revoke all
on function public.search_teachers_as_admin(text, integer)
from public;

grant execute
on function public.search_teachers_as_admin(text, integer)
to authenticated;


-- ============================================================
-- Create institutional subject
-- ============================================================

create or replace function public.create_institutional_subject_as_admin(
  p_name text,
  p_code text default null
)
returns public.institutional_subjects
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_name text;
  normalized_code text;
  created_subject public.institutional_subjects;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  if not public.is_admin() then
    raise exception 'Admin privileges required'
      using errcode = '42501';
  end if;

  normalized_name := nullif(trim(coalesce(p_name, '')), '');
  normalized_code := nullif(upper(trim(coalesce(p_code, ''))), '');

  if normalized_name is null then
    raise exception 'Subject name is required'
      using errcode = '22023';
  end if;

  insert into public.institutional_subjects (
    code,
    name
  )
  values (
    normalized_code,
    normalized_name
  )
  returning *
  into created_subject;

  return created_subject;
end;
$$;

revoke all
on function public.create_institutional_subject_as_admin(text, text)
from public;

grant execute
on function public.create_institutional_subject_as_admin(text, text)
to authenticated;


-- ============================================================
-- Set subject active state
-- ============================================================

create or replace function public.set_institutional_subject_active_as_admin(
  p_subject_id uuid,
  p_active boolean
)
returns public.institutional_subjects
language plpgsql
security definer
set search_path = ''
as $$
declare
  updated_subject public.institutional_subjects;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  if not public.is_admin() then
    raise exception 'Admin privileges required'
      using errcode = '42501';
  end if;

  if p_subject_id is null then
    raise exception 'Subject is required'
      using errcode = '22004';
  end if;

  update public.institutional_subjects
  set active = p_active
  where id = p_subject_id
  returning *
  into updated_subject;

  if updated_subject.id is null then
    raise exception 'Institutional subject not found'
      using errcode = 'P0002';
  end if;

  return updated_subject;
end;
$$;

revoke all
on function public.set_institutional_subject_active_as_admin(uuid, boolean)
from public;

grant execute
on function public.set_institutional_subject_active_as_admin(uuid, boolean)
to authenticated;


-- ============================================================
-- Create teacher assignment
-- ============================================================

create or replace function public.create_teacher_assignment_as_admin(
  p_teacher_id uuid,
  p_subject_id uuid,
  p_academic_group_id text,
  p_academic_period_id uuid default null
)
returns public.teacher_assignments
language plpgsql
security definer
set search_path = ''
as $$
declare
  effective_period_id uuid;
  normalized_group_id text;
  created_assignment public.teacher_assignments;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  if not public.is_admin() then
    raise exception 'Admin privileges required'
      using errcode = '42501';
  end if;

  if p_teacher_id is null or p_subject_id is null then
    raise exception 'Teacher and subject are required'
      using errcode = '22004';
  end if;

  normalized_group_id :=
    nullif(trim(coalesce(p_academic_group_id, '')), '');

  if normalized_group_id is null then
    raise exception 'Academic group is required'
      using errcode = '22023';
  end if;

  effective_period_id :=
    coalesce(
      p_academic_period_id,
      public.get_active_academic_period_id()
    );

  insert into public.teacher_assignments (
    teacher_id,
    subject_id,
    academic_group_id,
    academic_period_id
  )
  values (
    p_teacher_id,
    p_subject_id,
    normalized_group_id,
    effective_period_id
  )
  returning *
  into created_assignment;

  return created_assignment;
end;
$$;

revoke all
on function public.create_teacher_assignment_as_admin(
  uuid,
  uuid,
  text,
  uuid
)
from public;

grant execute
on function public.create_teacher_assignment_as_admin(
  uuid,
  uuid,
  text,
  uuid
)
to authenticated;


-- ============================================================
-- Set assignment active state
-- ============================================================

create or replace function public.set_teacher_assignment_active_as_admin(
  p_assignment_id uuid,
  p_active boolean
)
returns public.teacher_assignments
language plpgsql
security definer
set search_path = ''
as $$
declare
  updated_assignment public.teacher_assignments;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  if not public.is_admin() then
    raise exception 'Admin privileges required'
      using errcode = '42501';
  end if;

  update public.teacher_assignments
  set active = p_active
  where id = p_assignment_id
  returning *
  into updated_assignment;

  if updated_assignment.id is null then
    raise exception 'Teacher assignment not found'
      using errcode = 'P0002';
  end if;

  return updated_assignment;
end;
$$;

revoke all
on function public.set_teacher_assignment_active_as_admin(uuid, boolean)
from public;

grant execute
on function public.set_teacher_assignment_active_as_admin(uuid, boolean)
to authenticated;


-- ============================================================
-- Create schedule session
-- ============================================================

create or replace function public.create_teacher_assignment_session_as_admin(
  p_assignment_id uuid,
  p_weekday smallint,
  p_starts_at time,
  p_ends_at time,
  p_building text default null,
  p_room text default null
)
returns public.teacher_assignment_sessions
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_assignment public.teacher_assignments;
  created_session public.teacher_assignment_sessions;
  normalized_building text;
  normalized_room text;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  if not public.is_admin() then
    raise exception 'Admin privileges required'
      using errcode = '42501';
  end if;

  if p_weekday is null or p_weekday < 1 or p_weekday > 7 then
    raise exception 'Weekday must be between 1 and 7'
      using errcode = '22023';
  end if;

  if p_starts_at is null or p_ends_at is null
     or p_starts_at >= p_ends_at then
    raise exception 'Invalid class session time range'
      using errcode = '22023';
  end if;

  select *
  into target_assignment
  from public.teacher_assignments
  where id = p_assignment_id
    and active = true;

  if not found then
    raise exception 'Active teacher assignment not found'
      using errcode = 'P0002';
  end if;

  -- Prevent overlapping sessions for the same teacher
  -- within the same academic period.
  if exists (
    select 1
    from public.teacher_assignment_sessions as session
    join public.teacher_assignments as assignment
      on assignment.id = session.assignment_id
    where assignment.teacher_id = target_assignment.teacher_id
      and assignment.academic_period_id =
        target_assignment.academic_period_id
      and assignment.active = true
      and session.weekday = p_weekday
      and session.starts_at < p_ends_at
      and session.ends_at > p_starts_at
  ) then
    raise exception 'Teacher schedule conflict'
      using errcode = '23514';
  end if;

  -- Prevent overlapping sessions for the same academic group
  -- within the same academic period.
  if exists (
    select 1
    from public.teacher_assignment_sessions as session
    join public.teacher_assignments as assignment
      on assignment.id = session.assignment_id
    where assignment.academic_group_id =
        target_assignment.academic_group_id
      and assignment.academic_period_id =
        target_assignment.academic_period_id
      and assignment.active = true
      and session.weekday = p_weekday
      and session.starts_at < p_ends_at
      and session.ends_at > p_starts_at
  ) then
    raise exception 'Academic group schedule conflict'
      using errcode = '23514';
  end if;

  normalized_building :=
    nullif(trim(coalesce(p_building, '')), '');

  normalized_room :=
    nullif(trim(coalesce(p_room, '')), '');

  insert into public.teacher_assignment_sessions (
    assignment_id,
    weekday,
    starts_at,
    ends_at,
    building,
    room
  )
  values (
    p_assignment_id,
    p_weekday,
    p_starts_at,
    p_ends_at,
    normalized_building,
    normalized_room
  )
  returning *
  into created_session;

  return created_session;
end;
$$;

revoke all
on function public.create_teacher_assignment_session_as_admin(
  uuid,
  smallint,
  time,
  time,
  text,
  text
)
from public;

grant execute
on function public.create_teacher_assignment_session_as_admin(
  uuid,
  smallint,
  time,
  time,
  text,
  text
)
to authenticated;


-- ============================================================
-- Delete schedule session
-- ============================================================

create or replace function public.delete_teacher_assignment_session_as_admin(
  p_session_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  if not public.is_admin() then
    raise exception 'Admin privileges required'
      using errcode = '42501';
  end if;

  delete from public.teacher_assignment_sessions
  where id = p_session_id;

  if not found then
    raise exception 'Teacher assignment session not found'
      using errcode = 'P0002';
  end if;
end;
$$;

revoke all
on function public.delete_teacher_assignment_session_as_admin(uuid)
from public;

grant execute
on function public.delete_teacher_assignment_session_as_admin(uuid)
to authenticated;

commit;
