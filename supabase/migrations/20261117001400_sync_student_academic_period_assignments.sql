
-- CONECTA ITT
-- Bloque 9.7D: sincronizacion del historial academico.
-- Alcance: PostgreSQL local durante desarrollo.
-- No modifica funciones existentes ni realiza backfill.

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

DO $guard$
BEGIN
  IF to_regprocedure(
    'public.sync_student_academic_period_assignment()'
  ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Academic period sync function already exists';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgrelid = 'public.profiles'::regclass
      AND tgname =
        'sync_student_academic_period_assignment'
  ) THEN
    RAISE EXCEPTION
      'Academic period sync trigger already exists';
  END IF;
END;
$guard$;

CREATE FUNCTION
public.sync_student_academic_period_assignment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  matching_periods integer;
  current_period_id uuid;
  actor_user_id uuid;
BEGIN
  -- Solo estudiantes.
  IF NEW.account_type IS DISTINCT FROM 'student' THEN
    RETURN NEW;
  END IF;

  -- La identidad academica puede estar pendiente.
  IF NEW.career_id IS NULL OR NEW.semester IS NULL THEN
    RETURN NEW;
  END IF;

  -- Se resuelve por fechas, no por is_active.
  -- is_active representa el estado administrativo,
  -- pero el historial usa el periodo calendario.
  SELECT
    count(*),
    min(period.id::text)::uuid
  INTO
    matching_periods,
    current_period_id
  FROM public.academic_periods AS period
  WHERE
    (now() AT TIME ZONE 'America/Mexico_City')::date
    BETWEEN period.starts_on AND period.ends_on;

  -- Fuera de periodos: no atribuir uno artificialmente.
  IF matching_periods = 0 THEN
    RETURN NEW;
  END IF;

  -- Periodos superpuestos: impedir asignacion ambigua.
  IF matching_periods <> 1 THEN
    RAISE EXCEPTION
      'Ambiguous academic period for student assignment'
      USING ERRCODE = '23514';
  END IF;

  -- Comprobar consistencia del grupo con la identidad.
  IF NEW.group_id IS NOT NULL AND NOT EXISTS (
    SELECT 1
    FROM public.academic_groups AS academic_group
    WHERE academic_group.id = NEW.group_id
      AND academic_group.career_id = NEW.career_id
      AND academic_group.semester = NEW.semester
  ) THEN
    RAISE EXCEPTION
      'Academic group does not match student identity'
      USING ERRCODE = '23514';
  END IF;

  -- Para registro inicial puede ser NULL.
  -- Para cambios administrativos refleja auth.uid().
  actor_user_id := auth.uid();

  INSERT INTO
    public.student_academic_period_assignments (
      user_id,
      academic_period_id,
      career_id,
      semester,
      group_id,
      updated_by
    )
  VALUES (
    NEW.id,
    current_period_id,
    NEW.career_id,
    NEW.semester,
    NEW.group_id,
    actor_user_id
  )
  ON CONFLICT (user_id, academic_period_id)
  DO UPDATE SET
    career_id = EXCLUDED.career_id,
    semester = EXCLUDED.semester,
    group_id = EXCLUDED.group_id,
    updated_at = timezone('utc', now()),
    updated_by = EXCLUDED.updated_by
  WHERE
    public.student_academic_period_assignments.career_id
      IS DISTINCT FROM EXCLUDED.career_id
    OR
    public.student_academic_period_assignments.semester
      IS DISTINCT FROM EXCLUDED.semester
    OR
    public.student_academic_period_assignments.group_id
      IS DISTINCT FROM EXCLUDED.group_id;

  RETURN NEW;
END;
$function$;

REVOKE ALL
ON FUNCTION
public.sync_student_academic_period_assignment()
FROM PUBLIC, anon, authenticated;

CREATE TRIGGER
sync_student_academic_period_assignment
AFTER INSERT OR UPDATE OF career_id, semester, group_id
ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION
public.sync_student_academic_period_assignment();

DO $verify$
DECLARE
  trigger_count integer;
BEGIN
  SELECT count(*)
  INTO trigger_count
  FROM pg_trigger
  WHERE tgrelid = 'public.profiles'::regclass
    AND tgname =
      'sync_student_academic_period_assignment'
    AND tgenabled = 'O';

  IF trigger_count <> 1 THEN
    RAISE EXCEPTION
      'Academic sync trigger is not enabled';
  END IF;

  IF NOT (
    SELECT prosecdef
    FROM pg_proc
    WHERE oid =
      'public.sync_student_academic_period_assignment()'
      ::regprocedure
  ) THEN
    RAISE EXCEPTION
      'Academic sync function must be SECURITY DEFINER';
  END IF;

  IF has_function_privilege(
    'anon',
    'public.sync_student_academic_period_assignment()',
    'EXECUTE'
  ) OR has_function_privilege(
    'authenticated',
    'public.sync_student_academic_period_assignment()',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Unexpected direct execution permission';
  END IF;

  RAISE NOTICE
    'PASS: academic period sync installed';
END;
$verify$;

COMMIT;
