
-- CONECTA ITT
-- Bloque 9.7H: consulta protegida del historial.
-- No modifica datos academicos ni perfiles.

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

DO $guard$
BEGIN
  IF to_regprocedure(
    'public.get_student_academic_period_history(uuid)'
  ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Academic history RPC already exists';
  END IF;
END;
$guard$;

CREATE FUNCTION
public.get_student_academic_period_history(
  p_user_id uuid DEFAULT NULL
)
RETURNS TABLE (
  academic_period_id uuid,
  period_code text,
  period_name text,
  starts_on date,
  ends_on date,
  career_id text,
  semester smallint,
  group_id text,
  assigned_at timestamptz,
  updated_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_actor uuid;
  v_target uuid;
BEGIN
  v_actor := (SELECT auth.uid());

  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Authentication required'
      USING ERRCODE = '42501';
  END IF;

  v_target := COALESCE(p_user_id, v_actor);

  -- Consultar otro usuario requiere permisos
  -- administrativos verificados en PostgreSQL.
  IF v_target IS DISTINCT FROM v_actor
     AND NOT public.is_admin() THEN
    RAISE EXCEPTION
      'Admin privileges required for other students'
      USING ERRCODE = '42501';
  END IF;

  -- Solo se consultan perfiles estudiantiles activos.
  IF NOT EXISTS (
    SELECT 1
    FROM public.profiles AS profile
    WHERE profile.id = v_target
      AND profile.role = 'student'
      AND profile.account_type = 'student'
      AND profile.active = true
  ) THEN
    RAISE EXCEPTION
      'Active student profile not found'
      USING ERRCODE = 'P0002';
  END IF;

  RETURN QUERY
  SELECT
    assignment.academic_period_id,
    period.code,
    period.name,
    period.starts_on,
    period.ends_on,
    assignment.career_id,
    assignment.semester,
    assignment.group_id,
    assignment.created_at,
    assignment.updated_at
  FROM public.student_academic_period_assignments
    AS assignment
  JOIN public.academic_periods AS period
    ON period.id = assignment.academic_period_id
  WHERE assignment.user_id = v_target
  ORDER BY
    period.starts_on DESC NULLS LAST,
    period.code DESC;
END;
$function$;

-- Restringir la invocacion directa.
REVOKE ALL
ON FUNCTION
public.get_student_academic_period_history(uuid)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION
public.get_student_academic_period_history(uuid)
TO authenticated;

DO $verify$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc
    WHERE oid =
      'public.get_student_academic_period_history(uuid)'
      ::regprocedure
      AND prosecdef = true
  ) THEN
    RAISE EXCEPTION
      'RPC must be SECURITY DEFINER';
  END IF;

  IF has_function_privilege(
    'anon',
    'public.get_student_academic_period_history(uuid)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Anonymous execution unexpectedly allowed';
  END IF;

  IF NOT has_function_privilege(
    'authenticated',
    'public.get_student_academic_period_history(uuid)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Authenticated execution unavailable';
  END IF;

  IF has_table_privilege(
    'authenticated',
    'public.student_academic_period_assignments',
    'SELECT'
  ) THEN
    RAISE EXCEPTION
      'Direct history table access unexpectedly allowed';
  END IF;

  RAISE NOTICE
    'PASS: history RPC permissions verified';
END;
$verify$;

COMMIT;
