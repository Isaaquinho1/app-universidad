-- ============================================================
-- Conecta ITT
-- Institutional teacher academic assignments
-- ============================================================

begin;

-- ============================================================
-- Institutional subject catalog
-- ============================================================

create table if not exists public.institutional_subjects (
  id uuid primary key default gen_random_uuid(),

  code text,
  name text not null,

  active boolean not null default true,

  created_at timestamptz not null
    default timezone('utc', now()),

  updated_at timestamptz not null
    default timezone('utc', now()),

  constraint institutional_subjects_code_not_blank
    check (
      code is null
      or length(trim(code)) > 0
    ),

  constraint institutional_subjects_name_not_blank
    check (length(trim(name)) > 0)
);

create unique index if not exists institutional_subjects_code_unique_idx
  on public.institutional_subjects(lower(code))
  where code is not null;

create index if not exists institutional_subjects_active_idx
  on public.institutional_subjects(active);

comment on table public.institutional_subjects is
  'Authoritative institutional subject catalog used for teacher assignments.';

alter table public.institutional_subjects
  enable row level security;

-- ============================================================
-- Teacher assignments
-- ============================================================

create table if not exists public.teacher_assignments (
  id uuid primary key default gen_random_uuid(),

  teacher_id uuid not null
    references public.profiles(id)
    on update cascade
    on delete restrict,

  subject_id uuid not null
    references public.institutional_subjects(id)
    on update cascade
    on delete restrict,

  academic_group_id text not null
    references public.academic_groups(id)
    on update cascade
    on delete restrict,

  academic_period_id uuid not null
    references public.academic_periods(id)
    on update cascade
    on delete restrict,

  active boolean not null default true,

  created_at timestamptz not null
    default timezone('utc', now()),

  updated_at timestamptz not null
    default timezone('utc', now())
);

create unique index if not exists teacher_assignments_unique_idx
  on public.teacher_assignments(
    teacher_id,
    subject_id,
    academic_group_id,
    academic_period_id
  );

create index if not exists teacher_assignments_teacher_idx
  on public.teacher_assignments(teacher_id);

create index if not exists teacher_assignments_group_idx
  on public.teacher_assignments(academic_group_id);

create index if not exists teacher_assignments_period_idx
  on public.teacher_assignments(academic_period_id);

create index if not exists teacher_assignments_active_idx
  on public.teacher_assignments(active);

comment on table public.teacher_assignments is
  'Institutional teacher-to-subject-to-group assignments scoped to an academic period.';

alter table public.teacher_assignments
  enable row level security;

-- ============================================================
-- Teacher assignment schedule sessions
-- ============================================================

create table if not exists public.teacher_assignment_sessions (
  id uuid primary key default gen_random_uuid(),

  assignment_id uuid not null
    references public.teacher_assignments(id)
    on update cascade
    on delete cascade,

  weekday smallint not null,

  starts_at time not null,
  ends_at time not null,

  building text,
  room text,

  created_at timestamptz not null
    default timezone('utc', now()),

  updated_at timestamptz not null
    default timezone('utc', now()),

  constraint teacher_assignment_sessions_weekday_range
    check (weekday between 1 and 7),

  constraint teacher_assignment_sessions_time_order
    check (starts_at < ends_at),

  constraint teacher_assignment_sessions_building_not_blank
    check (
      building is null
      or length(trim(building)) > 0
    ),

  constraint teacher_assignment_sessions_room_not_blank
    check (
      room is null
      or length(trim(room)) > 0
    )
);

create index if not exists teacher_assignment_sessions_assignment_idx
  on public.teacher_assignment_sessions(assignment_id);

create index if not exists teacher_assignment_sessions_weekday_idx
  on public.teacher_assignment_sessions(weekday);

comment on table public.teacher_assignment_sessions is
  'Institutional class schedule sessions attached to teacher assignments.';

alter table public.teacher_assignment_sessions
  enable row level security;

-- ============================================================
-- Updated-at triggers
-- ============================================================

drop trigger if exists institutional_subjects_set_updated_at
on public.institutional_subjects;

create trigger institutional_subjects_set_updated_at
before update on public.institutional_subjects
for each row
execute function public.set_updated_at();

drop trigger if exists teacher_assignments_set_updated_at
on public.teacher_assignments;

create trigger teacher_assignments_set_updated_at
before update on public.teacher_assignments
for each row
execute function public.set_updated_at();

drop trigger if exists teacher_assignment_sessions_set_updated_at
on public.teacher_assignment_sessions;

create trigger teacher_assignment_sessions_set_updated_at
before update on public.teacher_assignment_sessions
for each row
execute function public.set_updated_at();

-- ============================================================
-- Teacher identity helper
-- ============================================================

create or replace function public.is_teacher()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select role = 'teacher'
      from public.profiles
      where id = (select auth.uid())
        and active = true
        and staff_approval_pending = false
    ),
    false
  );
$$;

revoke all on function public.is_teacher()
from public;

grant execute on function public.is_teacher()
to authenticated;

-- ============================================================
-- Validation trigger for assignments
-- ============================================================

create or replace function public.validate_teacher_assignment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  teacher_profile public.profiles;
  subject_record public.institutional_subjects;
  group_record public.academic_groups;
  period_record public.academic_periods;
begin
  select *
  into teacher_profile
  from public.profiles
  where id = new.teacher_id;

  if not found then
    raise exception 'Teacher profile not found'
      using errcode = '23503';
  end if;

  if teacher_profile.role <> 'teacher' then
    raise exception 'Assigned profile must have teacher role'
      using errcode = '23514';
  end if;

  if not teacher_profile.active then
    raise exception 'Assigned teacher profile is inactive'
      using errcode = '23514';
  end if;

  if teacher_profile.staff_approval_pending then
    raise exception 'Assigned teacher still requires institutional approval'
      using errcode = '23514';
  end if;

  select *
  into subject_record
  from public.institutional_subjects
  where id = new.subject_id;

  if not found or not subject_record.active then
    raise exception 'Institutional subject is invalid or inactive'
      using errcode = '23514';
  end if;

  select *
  into group_record
  from public.academic_groups
  where id = new.academic_group_id;

  if not found or not group_record.active then
    raise exception 'Academic group is invalid or inactive'
      using errcode = '23514';
  end if;

  select *
  into period_record
  from public.academic_periods
  where id = new.academic_period_id;

  if not found then
    raise exception 'Academic period not found'
      using errcode = '23503';
  end if;

  return new;
end;
$$;

drop trigger if exists teacher_assignments_validate
on public.teacher_assignments;

create trigger teacher_assignments_validate
before insert or update
on public.teacher_assignments
for each row
execute function public.validate_teacher_assignment();

-- ============================================================
-- Read policies
-- ============================================================

drop policy if exists institutional_subjects_read_authenticated
on public.institutional_subjects;

create policy institutional_subjects_read_authenticated
on public.institutional_subjects
for select
to authenticated
using (
  (active = true and (select public.is_teacher()))
  or (select public.is_admin())
);

drop policy if exists teacher_assignments_read_own_or_admin
on public.teacher_assignments;

create policy teacher_assignments_read_own_or_admin
on public.teacher_assignments
for select
to authenticated
using (
  teacher_id = (select auth.uid())
  or (select public.is_admin())
);

drop policy if exists teacher_assignment_sessions_read_own_or_admin
on public.teacher_assignment_sessions;

create policy teacher_assignment_sessions_read_own_or_admin
on public.teacher_assignment_sessions
for select
to authenticated
using (
  exists (
    select 1
    from public.teacher_assignments as assignment
    where assignment.id = assignment_id
      and (
        assignment.teacher_id = (select auth.uid())
        or (select public.is_admin())
      )
  )
);

-- ============================================================
-- Direct writes are forbidden
-- ============================================================

revoke insert, update, delete
on public.institutional_subjects
from authenticated;

revoke insert, update, delete
on public.teacher_assignments
from authenticated;

revoke insert, update, delete
on public.teacher_assignment_sessions
from authenticated;

commit;
