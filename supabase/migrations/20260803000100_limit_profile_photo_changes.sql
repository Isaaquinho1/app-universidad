-- Conecta ITT
-- Academic-period limits and audit history for digital ID photographs.

begin;

-- ============================================================
-- Academic periods
-- ============================================================

create table if not exists public.academic_periods (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  starts_on date,
  ends_on date,
  is_active boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint academic_periods_code_not_blank
    check (length(trim(code)) > 0),
  constraint academic_periods_name_not_blank
    check (length(trim(name)) > 0),
  constraint academic_periods_date_order
    check (
      starts_on is null
      or ends_on is null
      or starts_on <= ends_on
    )
);

create unique index if not exists academic_periods_one_active_idx
  on public.academic_periods ((is_active))
  where is_active = true;

comment on table public.academic_periods is
  'Institutional academic periods used for semester-scoped controls.';

alter table public.academic_periods enable row level security;

drop policy if exists academic_periods_read_authenticated
on public.academic_periods;

create policy academic_periods_read_authenticated
on public.academic_periods
for select
to authenticated
using (true);

insert into public.academic_periods (
  code,
  name,
  starts_on,
  ends_on,
  is_active
)
values (
  '2026-2',
  'Agosto–Diciembre 2026',
  date '2026-08-01',
  date '2026-12-31',
  true
)
on conflict (code) do update
set
  name = excluded.name,
  starts_on = excluded.starts_on,
  ends_on = excluded.ends_on,
  is_active = excluded.is_active,
  updated_at = timezone('utc', now());

-- ============================================================
-- Photograph submission history
-- ============================================================

create table if not exists public.student_profile_photo_submissions (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null
    references public.profiles(id)
    on update cascade
    on delete cascade,
  academic_period_id uuid not null
    references public.academic_periods(id)
    on update cascade
    on delete restrict,
  photo_path text not null,
  status text not null default 'pending',
  is_initial_photo boolean not null default false,
  consumes_change boolean not null default false,
  submitted_at timestamptz not null default timezone('utc', now()),
  reviewed_at timestamptz,
  reviewed_by uuid
    references public.profiles(id)
    on update cascade
    on delete set null,
  rejection_reason text,
  created_at timestamptz not null default timezone('utc', now()),
  constraint student_photo_submission_path_not_blank
    check (length(trim(photo_path)) > 0),
  constraint student_photo_submission_status_valid
    check (status in ('pending', 'approved', 'rejected')),
  constraint student_photo_submission_reason_length
    check (
      rejection_reason is null
      or length(rejection_reason) <= 500
    ),
  constraint student_photo_initial_does_not_consume
    check (not is_initial_photo or not consumes_change)
);

create index if not exists student_photo_submissions_student_period_idx
  on public.student_profile_photo_submissions(
    student_id,
    academic_period_id,
    submitted_at desc
  );

create index if not exists student_photo_submissions_status_idx
  on public.student_profile_photo_submissions(status);

create unique index if not exists student_photo_one_pending_idx
  on public.student_profile_photo_submissions(student_id)
  where status = 'pending';

comment on table public.student_profile_photo_submissions is
  'Immutable audit history of institutional profile photograph submissions.';

alter table public.student_profile_photo_submissions
  enable row level security;

drop policy if exists student_photo_submissions_read_own_or_admin
on public.student_profile_photo_submissions;

create policy student_photo_submissions_read_own_or_admin
on public.student_profile_photo_submissions
for select
to authenticated
using (
  student_id = (select auth.uid())
  or (select public.is_admin())
);

-- Writes are performed only by SECURITY DEFINER RPC functions.
revoke insert, update, delete
on public.student_profile_photo_submissions
from authenticated;

-- ============================================================
-- Active-period helper
-- ============================================================

create or replace function public.get_active_academic_period_id()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  active_period_id uuid;
begin
  select period.id
  into active_period_id
  from public.academic_periods as period
  where period.is_active = true
  limit 1;

  if active_period_id is null then
    raise exception 'No active academic period is configured'
      using errcode = 'object_not_in_prerequisite_state';
  end if;

  return active_period_id;
end;
$$;

revoke all on function public.get_active_academic_period_id()
from public;

grant execute on function public.get_active_academic_period_id()
to authenticated;

-- ============================================================
-- Backfill current profile photographs as initial submissions
-- ============================================================

insert into public.student_profile_photo_submissions (
  student_id,
  academic_period_id,
  photo_path,
  status,
  is_initial_photo,
  consumes_change,
  submitted_at,
  reviewed_at,
  reviewed_by,
  rejection_reason
)
select
  profile.id,
  public.get_active_academic_period_id(),
  profile.photo_path,
  case
    when profile.photo_status in ('pending', 'approved', 'rejected')
      then profile.photo_status
    else 'pending'
  end,
  true,
  false,
  coalesce(profile.photo_updated_at, timezone('utc', now())),
  profile.photo_reviewed_at,
  profile.photo_reviewed_by,
  profile.photo_rejection_reason
from public.profiles as profile
where profile.photo_path is not null
  and length(trim(profile.photo_path)) > 0
  and not exists (
    select 1
    from public.student_profile_photo_submissions as submission
    where submission.student_id = profile.id
      and submission.photo_path = profile.photo_path
  );

-- ============================================================
-- Student allowance RPC
-- ============================================================

create or replace function public.get_own_profile_photo_allowance()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_user_id uuid;
  active_period public.academic_periods;
  used_changes integer;
  pending_exists boolean;
  has_ever_submitted boolean;
  extra_changes integer;
begin
  current_user_id := (select auth.uid());

  if current_user_id is null then
    raise exception 'Authentication required'
      using errcode = 'insufficient_privilege';
  end if;

  select period.*
  into active_period
  from public.academic_periods as period
  where period.is_active = true
  limit 1;

  if active_period.id is null then
    raise exception 'No active academic period is configured'
      using errcode = 'object_not_in_prerequisite_state';
  end if;

  select
    count(*) filter (where submission.consumes_change),
    bool_or(submission.status = 'pending')
  into
    used_changes,
    pending_exists
  from public.student_profile_photo_submissions as submission
  where submission.student_id = current_user_id
    and submission.academic_period_id = active_period.id;

  select exists (
    select 1
    from public.student_profile_photo_submissions as submission
    where submission.student_id = current_user_id
  )
  into has_ever_submitted;

  -- Reserved for audited administrative exceptions.
  extra_changes := 0;

  return jsonb_build_object(
    'academic_period_id', active_period.id,
    'academic_period_code', active_period.code,
    'academic_period_name', active_period.name,
    'base_limit', 3,
    'extra_changes', extra_changes,
    'total_limit', 3 + extra_changes,
    'used_changes', coalesce(used_changes, 0),
    'remaining_changes',
      greatest((3 + extra_changes) - coalesce(used_changes, 0), 0),
    'has_pending_submission', coalesce(pending_exists, false),
    'has_initial_submission', has_ever_submitted,
    'can_submit',
      not coalesce(pending_exists, false)
      and (
        not has_ever_submitted
        or coalesce(used_changes, 0) < (3 + extra_changes)
      )
  );
end;
$$;

comment on function public.get_own_profile_photo_allowance() is
  'Returns the authenticated student photograph-change allowance for the active academic period.';

revoke all on function public.get_own_profile_photo_allowance()
from public;

grant execute on function public.get_own_profile_photo_allowance()
to authenticated;

-- ============================================================
-- Replace student submission RPC
-- ============================================================

create or replace function public.submit_own_profile_photo(
  p_photo_path text
)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid;
  active_period_id uuid;
  normalized_path text;
  current_profile public.profiles;
  updated_profile public.profiles;
  has_initial_submission boolean;
  used_changes integer;
  consumes_change boolean;
begin
  current_user_id := (select auth.uid());

  if current_user_id is null then
    raise exception 'Authentication required'
      using errcode = 'insufficient_privilege';
  end if;

  normalized_path := trim(coalesce(p_photo_path, ''));

  if normalized_path = '' then
    raise exception 'A profile photo path is required'
      using errcode = 'not_null_violation';
  end if;

  if public.profile_photo_owner_from_storage_path(normalized_path)
       <> current_user_id then
    raise exception 'The photograph path does not belong to the current user'
      using errcode = 'insufficient_privilege';
  end if;

  if not exists (
    select 1
    from storage.objects
    where bucket_id = 'student-profile-photos'
      and name = normalized_path
      and owner_id = current_user_id::text
  ) then
    raise exception 'The uploaded profile photograph was not found'
      using errcode = 'no_data_found';
  end if;

  select profile.*
  into current_profile
  from public.profiles as profile
  where profile.id = current_user_id
    and profile.active = true
  for update;

  if current_profile.id is null then
    raise exception 'Active profile not found'
      using errcode = 'no_data_found';
  end if;

  active_period_id := public.get_active_academic_period_id();

  if exists (
    select 1
    from public.student_profile_photo_submissions as submission
    where submission.student_id = current_user_id
      and submission.status = 'pending'
  ) then
    raise exception
      'Ya existe una fotografía pendiente de revisión'
      using errcode = 'object_in_use';
  end if;

  select exists (
    select 1
    from public.student_profile_photo_submissions as submission
    where submission.student_id = current_user_id
  )
  into has_initial_submission;

  if not has_initial_submission
     and current_profile.photo_path is not null
     and length(trim(current_profile.photo_path)) > 0 then
    has_initial_submission := true;
  end if;

  select count(*) filter (where submission.consumes_change)
  into used_changes
  from public.student_profile_photo_submissions as submission
  where submission.student_id = current_user_id
    and submission.academic_period_id = active_period_id;

  consumes_change := has_initial_submission;

  if consumes_change and coalesce(used_changes, 0) >= 3 then
    raise exception
      'Has utilizado los 3 cambios de fotografía disponibles para este periodo académico'
      using errcode = 'check_violation';
  end if;

  insert into public.student_profile_photo_submissions (
    student_id,
    academic_period_id,
    photo_path,
    status,
    is_initial_photo,
    consumes_change,
    submitted_at
  )
  values (
    current_user_id,
    active_period_id,
    normalized_path,
    'pending',
    not has_initial_submission,
    consumes_change,
    timezone('utc', now())
  );

  update public.profiles
  set
    photo_path = normalized_path,
    photo_status = 'pending',
    photo_updated_at = timezone('utc', now()),
    photo_reviewed_at = null,
    photo_reviewed_by = null,
    photo_rejection_reason = null,
    updated_at = timezone('utc', now())
  where id = current_user_id
  returning *
  into updated_profile;

  return updated_profile;
end;
$$;

revoke all on function public.submit_own_profile_photo(text)
from public;

grant execute on function public.submit_own_profile_photo(text)
to authenticated;

-- ============================================================
-- Replace administrative review RPC
-- ============================================================

create or replace function public.review_profile_photo(
  p_profile_id uuid,
  p_decision text,
  p_rejection_reason text default null
)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  reviewer_id uuid;
  normalized_decision text;
  normalized_reason text;
  pending_submission public.student_profile_photo_submissions;
  reviewed_profile public.profiles;
begin
  reviewer_id := (select auth.uid());

  if reviewer_id is null then
    raise exception 'Authentication required'
      using errcode = 'insufficient_privilege';
  end if;

  if not public.is_admin() then
    raise exception 'Only administrators can review profile photographs'
      using errcode = 'insufficient_privilege';
  end if;

  normalized_decision := lower(trim(coalesce(p_decision, '')));
  normalized_reason := nullif(trim(coalesce(p_rejection_reason, '')), '');

  if normalized_decision not in ('approved', 'rejected') then
    raise exception 'The decision must be approved or rejected'
      using errcode = 'invalid_parameter_value';
  end if;

  if normalized_decision = 'rejected'
     and normalized_reason is null then
    raise exception 'A rejection reason is required'
      using errcode = 'not_null_violation';
  end if;

  if normalized_reason is not null
     and length(normalized_reason) > 500 then
    raise exception 'The rejection reason cannot exceed 500 characters'
      using errcode = 'string_data_right_truncation';
  end if;

  select submission.*
  into pending_submission
  from public.student_profile_photo_submissions as submission
  where submission.student_id = p_profile_id
    and submission.status = 'pending'
  order by submission.submitted_at desc
  limit 1
  for update;

  if pending_submission.id is null then
    raise exception
      'The photograph is no longer pending or the profile was not found'
      using errcode = 'no_data_found';
  end if;

  update public.student_profile_photo_submissions
  set
    status = normalized_decision,
    reviewed_at = timezone('utc', now()),
    reviewed_by = reviewer_id,
    rejection_reason =
      case
        when normalized_decision = 'rejected'
          then normalized_reason
        else null
      end
  where id = pending_submission.id;

  update public.profiles
  set
    photo_status = normalized_decision,
    photo_reviewed_at = timezone('utc', now()),
    photo_reviewed_by = reviewer_id,
    photo_rejection_reason =
      case
        when normalized_decision = 'rejected'
          then normalized_reason
        else null
      end,
    updated_at = timezone('utc', now())
  where id = p_profile_id
    and photo_path = pending_submission.photo_path
    and photo_status = 'pending'
  returning *
  into reviewed_profile;

  if reviewed_profile.id is null then
    raise exception
      'The photograph profile state changed during review'
      using errcode = 'serialization_failure';
  end if;

  return reviewed_profile;
end;
$$;

revoke all on function public.review_profile_photo(uuid, text, text)
from public;

grant execute on function public.review_profile_photo(uuid, text, text)
to authenticated;

commit;
