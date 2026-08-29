-- ============================================================
-- Administrative academic profile management
-- ============================================================
--
-- Academic identity is established during registration.
-- Subsequent career, semester and group changes are performed
-- only by authenticated admin or superAdmin accounts.
--
-- Every effective change is audited.
-- ============================================================

-- ============================================================
-- Audit history
-- ============================================================

create table if not exists public.student_academic_profile_change_audit (
  id bigint generated always as identity primary key,

  actor_user_id uuid not null,
  target_user_id uuid not null,

  previous_career_id text,
  new_career_id text,

  previous_semester smallint,
  new_semester smallint,

  previous_group_id text,
  new_group_id text,

  changed_at timestamptz not null
    default timezone('utc', now()),

  constraint student_academic_profile_change_audit_previous_semester_range
    check (
      previous_semester is null
      or previous_semester between 1 and 14
    ),

  constraint student_academic_profile_change_audit_new_semester_range
    check (
      new_semester is null
      or new_semester between 1 and 14
    )
);

comment on table public.student_academic_profile_change_audit is
  'Immutable audit trail for administrative changes to student academic identity.';

create index if not exists student_academic_profile_change_audit_actor_idx
  on public.student_academic_profile_change_audit(actor_user_id);

create index if not exists student_academic_profile_change_audit_target_idx
  on public.student_academic_profile_change_audit(target_user_id);

create index if not exists student_academic_profile_change_audit_changed_at_idx
  on public.student_academic_profile_change_audit(changed_at desc);

alter table public.student_academic_profile_change_audit
  enable row level security;

revoke all
on table public.student_academic_profile_change_audit
from anon, authenticated;


-- ============================================================
-- Administrative student academic profile update
-- ============================================================

create or replace function public.update_student_academic_profile_as_admin(
  p_user_id uuid,
  p_career_id text,
  p_semester smallint,
  p_group_id text default null
)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  target_profile public.profiles;
  selected_group public.academic_groups;
  updated_profile public.profiles;
  normalized_career_id text;
  normalized_group_id text;
begin
  actor_id := (select auth.uid());

  if actor_id is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  if not public.is_admin() then
    raise exception 'Admin privileges required'
      using errcode = '42501';
  end if;

  if p_user_id is null then
    raise exception 'Target user is required'
      using errcode = '22004';
  end if;

  normalized_career_id := nullif(trim(coalesce(p_career_id, '')), '');
  normalized_group_id := nullif(trim(coalesce(p_group_id, '')), '');

  if normalized_career_id is null then
    raise exception 'Career is required'
      using errcode = '22023';
  end if;

  if p_semester is null or p_semester < 1 or p_semester > 14 then
    raise exception 'Semester must be between 1 and 14'
      using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public.careers
    where id = normalized_career_id
      and active = true
  ) then
    raise exception 'Invalid or inactive career'
      using errcode = '23503';
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

  if target_profile.role <> 'student' then
    raise exception
      'Academic identity can only be changed for student accounts'
      using errcode = '42501';
  end if;

  if not target_profile.active then
    raise exception 'Student profile is inactive'
      using errcode = '42501';
  end if;

  if normalized_group_id is not null then
    select *
    into selected_group
    from public.academic_groups
    where id = normalized_group_id
      and active = true;

    if not found then
      raise exception 'Invalid or inactive academic group'
        using errcode = '23503';
    end if;

    if selected_group.career_id is distinct from normalized_career_id then
      raise exception
        'Academic group does not belong to selected career'
        using errcode = '23514';
    end if;

    if selected_group.semester is distinct from p_semester then
      raise exception
        'Academic group does not belong to selected semester'
        using errcode = '23514';
    end if;
  end if;

  if target_profile.career_id is not distinct from normalized_career_id
     and target_profile.semester is not distinct from p_semester
     and target_profile.group_id is not distinct from normalized_group_id then
    return target_profile;
  end if;

  update public.profiles
  set
    career_id = normalized_career_id,
    semester = p_semester,
    group_id = normalized_group_id,
    profile_completed = true,
    updated_at = timezone('utc', now())
  where id = p_user_id
  returning *
  into updated_profile;

  insert into public.student_academic_profile_change_audit (
    actor_user_id,
    target_user_id,
    previous_career_id,
    new_career_id,
    previous_semester,
    new_semester,
    previous_group_id,
    new_group_id
  )
  values (
    actor_id,
    p_user_id,
    target_profile.career_id,
    updated_profile.career_id,
    target_profile.semester,
    updated_profile.semester,
    target_profile.group_id,
    updated_profile.group_id
  );

  return updated_profile;
end;
$$;

revoke all
on function public.update_student_academic_profile_as_admin(
  uuid,
  text,
  smallint,
  text
)
from public;

grant execute
on function public.update_student_academic_profile_as_admin(
  uuid,
  text,
  smallint,
  text
)
to authenticated;

comment on function public.update_student_academic_profile_as_admin(
  uuid,
  text,
  smallint,
  text
) is
  'Updates student academic identity through an audited admin-only flow with career, semester and group consistency validation.';
