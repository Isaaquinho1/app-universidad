BEGIN;

-- Conecta ITT: periodo de foto resuelto por fecha.
-- No modifica el periodo global usado por docentes.


CREATE OR REPLACE FUNCTION
public.get_photo_academic_period_id_for_date(p_date date)
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  matching_count integer;
  matching_id uuid;
BEGIN
  IF p_date IS NULL THEN
    RAISE EXCEPTION 'Academic date is required'
      USING ERRCODE = 'invalid_parameter_value';
  END IF;

  SELECT count(*), min(period.id::text)::uuid
  INTO matching_count, matching_id
  FROM public.academic_periods AS period
  WHERE period.starts_on IS NOT NULL
    AND period.ends_on IS NOT NULL
    AND p_date BETWEEN period.starts_on AND period.ends_on;

  IF matching_count = 0 THEN
    RAISE EXCEPTION 'No academic period configured for this date'
      USING ERRCODE = 'object_not_in_prerequisite_state';
  END IF;

  IF matching_count > 1 THEN
    RAISE EXCEPTION 'Overlapping academic periods'
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN matching_id;
END;
$function$;

REVOKE ALL ON FUNCTION
public.get_photo_academic_period_id_for_date(date)
FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION
public.get_current_photo_academic_period_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT public.get_photo_academic_period_id_for_date(
    (now() AT TIME ZONE 'America/Mexico_City')::date
  );
$function$;

REVOKE ALL ON FUNCTION
public.get_current_photo_academic_period_id()
FROM PUBLIC, anon, authenticated;


CREATE OR REPLACE FUNCTION public.get_own_profile_photo_allowance()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  WHERE period.id = public.get_current_photo_academic_period_id();

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
$function$;

CREATE OR REPLACE FUNCTION public.submit_own_profile_photo(p_photo_path text)
 RETURNS profiles
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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

  active_period_id := public.get_current_photo_academic_period_id();

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
$function$;

COMMIT;
