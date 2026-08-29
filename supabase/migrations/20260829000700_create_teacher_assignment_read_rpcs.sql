-- ============================================================
-- Conecta ITT
-- Read RPCs for institutional teaching assignments
-- ============================================================

begin;

-- ============================================================
-- Current teacher assignments
-- ============================================================

create or replace function public.get_my_teacher_assignments()
returns table (
  assignment_id uuid,

  teacher_id uuid,
  teacher_email text,
  teacher_display_name text,

  subject_id uuid,
  subject_code text,
  subject_name text,

  academic_group_id text,
  group_name text,
  career_id text,
  career_name text,
  semester smallint,

  academic_period_id uuid,
  academic_period_code text,
  academic_period_name text,
  period_starts_on date,
  period_ends_on date,

  sessions jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_user_id uuid;
  active_period_id uuid;
begin
  current_user_id := (select auth.uid());

  if current_user_id is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  if not public.is_teacher() then
    raise exception 'Teacher privileges required'
      using errcode = '42501';
  end if;

  active_period_id := public.get_active_academic_period_id();

  return query
  select
    assignment.id as assignment_id,

    teacher.id as teacher_id,
    teacher.email as teacher_email,
    teacher.display_name as teacher_display_name,

    subject.id as subject_id,
    subject.code as subject_code,
    subject.name as subject_name,

    academic_group.id as academic_group_id,
    academic_group.name as group_name,
    academic_group.career_id as career_id,
    career.name as career_name,
    academic_group.semester as semester,

    period.id as academic_period_id,
    period.code as academic_period_code,
    period.name as academic_period_name,
    period.starts_on as period_starts_on,
    period.ends_on as period_ends_on,

    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', session.id,
            'weekday', session.weekday,
            'starts_at', session.starts_at,
            'ends_at', session.ends_at,
            'building', session.building,
            'room', session.room
          )
          order by
            session.weekday,
            session.starts_at,
            session.ends_at
        )
        from public.teacher_assignment_sessions as session
        where session.assignment_id = assignment.id
      ),
      '[]'::jsonb
    ) as sessions

  from public.teacher_assignments as assignment

  join public.profiles as teacher
    on teacher.id = assignment.teacher_id

  join public.institutional_subjects as subject
    on subject.id = assignment.subject_id

  join public.academic_groups as academic_group
    on academic_group.id = assignment.academic_group_id

  left join public.careers as career
    on career.id = academic_group.career_id

  join public.academic_periods as period
    on period.id = assignment.academic_period_id

  where assignment.teacher_id = current_user_id
    and assignment.academic_period_id = active_period_id
    and assignment.active = true
    and subject.active = true
    and academic_group.active = true

  order by
    subject.name,
    academic_group.name,
    assignment.created_at;
end;
$$;

revoke all
on function public.get_my_teacher_assignments()
from public;

grant execute
on function public.get_my_teacher_assignments()
to authenticated;

comment on function public.get_my_teacher_assignments() is
  'Returns the authenticated teacher active assignments for the current academic period, including institutional subject, group and schedule information.';


-- ============================================================
-- Administrative assignment search
-- ============================================================

create or replace function public.search_teacher_assignments_as_admin(
  p_query text default null,
  p_academic_period_id uuid default null,
  p_include_inactive boolean default false,
  p_limit integer default 100
)
returns table (
  assignment_id uuid,
  assignment_active boolean,

  teacher_id uuid,
  teacher_email text,
  teacher_display_name text,

  subject_id uuid,
  subject_code text,
  subject_name text,
  subject_active boolean,

  academic_group_id text,
  group_name text,
  career_id text,
  career_name text,
  semester smallint,

  academic_period_id uuid,
  academic_period_code text,
  academic_period_name text,
  period_is_active boolean,

  sessions jsonb,

  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  normalized_query text;
  effective_period_id uuid;
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

  effective_period_id :=
    coalesce(
      p_academic_period_id,
      public.get_active_academic_period_id()
    );

  effective_limit :=
    greatest(
      1,
      least(coalesce(p_limit, 100), 250)
    );

  return query
  select
    assignment.id as assignment_id,
    assignment.active as assignment_active,

    teacher.id as teacher_id,
    teacher.email as teacher_email,
    teacher.display_name as teacher_display_name,

    subject.id as subject_id,
    subject.code as subject_code,
    subject.name as subject_name,
    subject.active as subject_active,

    academic_group.id as academic_group_id,
    academic_group.name as group_name,
    academic_group.career_id as career_id,
    career.name as career_name,
    academic_group.semester as semester,

    period.id as academic_period_id,
    period.code as academic_period_code,
    period.name as academic_period_name,
    period.is_active as period_is_active,

    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', session.id,
            'weekday', session.weekday,
            'starts_at', session.starts_at,
            'ends_at', session.ends_at,
            'building', session.building,
            'room', session.room
          )
          order by
            session.weekday,
            session.starts_at,
            session.ends_at
        )
        from public.teacher_assignment_sessions as session
        where session.assignment_id = assignment.id
      ),
      '[]'::jsonb
    ) as sessions,

    assignment.created_at,
    assignment.updated_at

  from public.teacher_assignments as assignment

  join public.profiles as teacher
    on teacher.id = assignment.teacher_id

  join public.institutional_subjects as subject
    on subject.id = assignment.subject_id

  join public.academic_groups as academic_group
    on academic_group.id = assignment.academic_group_id

  left join public.careers as career
    on career.id = academic_group.career_id

  join public.academic_periods as period
    on period.id = assignment.academic_period_id

  where assignment.academic_period_id = effective_period_id

    and (
      p_include_inactive
      or assignment.active = true
    )

    and (
      normalized_query is null
      or teacher.email ilike '%' || normalized_query || '%'
      or teacher.display_name ilike '%' || normalized_query || '%'
      or subject.code ilike '%' || normalized_query || '%'
      or subject.name ilike '%' || normalized_query || '%'
      or academic_group.id ilike '%' || normalized_query || '%'
      or academic_group.name ilike '%' || normalized_query || '%'
    )

  order by
    teacher.display_name nulls last,
    subject.name,
    academic_group.name,
    assignment.created_at

  limit effective_limit;
end;
$$;

revoke all
on function public.search_teacher_assignments_as_admin(
  text,
  uuid,
  boolean,
  integer
)
from public;

grant execute
on function public.search_teacher_assignments_as_admin(
  text,
  uuid,
  boolean,
  integer
)
to authenticated;

comment on function public.search_teacher_assignments_as_admin(
  text,
  uuid,
  boolean,
  integer
) is
  'Searches institutional teaching assignments for admin and superAdmin users, including subject, group, period and schedule details.';

commit;
