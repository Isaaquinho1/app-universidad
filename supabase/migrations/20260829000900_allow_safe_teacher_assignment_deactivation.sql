-- ============================================================
-- Conecta ITT
-- Allow safe deactivation of stale teacher assignments
-- ============================================================

begin;

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
  -- An existing assignment must always be possible to deactivate,
  -- even if its teacher, subject or group is no longer eligible.
  if tg_op = 'UPDATE'
     and old.active = true
     and new.active = false then
    return new;
  end if;

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

comment on function public.validate_teacher_assignment() is
  'Validates creation and activation of institutional teacher assignments while always allowing existing assignments to be deactivated safely.';

commit;
