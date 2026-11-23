BEGIN;

-- Conecta ITT: bloqueos pendientes entre periodos.
-- Conserva el conteo semestral y las fotografias historicas.

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

    -- Una solicitud pendiente bloquea nuevos envios,
    -- incluso cuando pertenece a un periodo anterior.
    select exists (
      select 1
      from public.student_profile_photo_submissions as submission
      where submission.student_id = current_user_id
        and submission.status = 'pending'
    )
    into pending_exists;

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

COMMIT;
