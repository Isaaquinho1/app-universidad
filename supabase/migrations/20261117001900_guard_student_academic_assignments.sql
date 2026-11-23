-- Conecta ITT | 9.8G.18
-- Validacion de asignaciones nuevas y consulta de ofertas.
-- Conserva asignaciones historicas sin cambios.
-- No modifica datos existentes.

BEGIN;


DO $preflight$
BEGIN
  IF to_regprocedure(
    'public.guard_student_academic_group_assignment()'
  ) IS NOT NULL
  OR EXISTS (
    SELECT 1
    FROM pg_catalog.pg_trigger
    WHERE tgrelid = 'public.profiles'::regclass
      AND tgname = 'conecta_guard_student_academic_assignment'
  ) THEN
    RAISE EXCEPTION
      'Student assignment guard already exists';
  END IF;

  IF md5(pg_get_functiondef(
    'public.get_registration_offered_groups(text,smallint)'::regprocedure
  )) <> '22900cbb17c923e5dc9f2fe221eb4f6f' THEN
    RAISE EXCEPTION
      'Registration group query differs from inspected version';
  END IF;

  IF to_regprocedure(
    'public.guard_academic_group_offering_active()'
  ) IS NULL
  OR to_regprocedure(
    'public.guard_academic_group_deactivation()'
  ) IS NULL THEN
    RAISE EXCEPTION
      'Catalog and offering protections are missing';
  END IF;
END;
$preflight$;


CREATE FUNCTION public.guard_student_academic_group_assignment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_group public.academic_groups%ROWTYPE;
  v_today date;
  v_period_count integer;
  v_period_id uuid;
  v_offering_group text;
BEGIN
  -- Esta proteccion aplica exclusivamente a estudiantes.
  IF NEW.role IS DISTINCT FROM 'student' THEN
    RETURN NEW;
  END IF;

  -- Se permite registrar estudiantes pendientes de grupo.
  IF NEW.group_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Conservar ubicaciones academicas historicas sin cambios.
  IF TG_OP = 'UPDATE' THEN
    IF OLD.group_id IS NOT DISTINCT FROM NEW.group_id
       AND OLD.career_id IS NOT DISTINCT FROM NEW.career_id
       AND OLD.semester IS NOT DISTINCT FROM NEW.semester
       AND OLD.role IS NOT DISTINCT FROM NEW.role THEN
      RETURN NEW;
    END IF;
  END IF;

  -- Bloquear el grupo mientras se verifica su disponibilidad.
  SELECT academic_group.*
  INTO v_group
  FROM public.academic_groups AS academic_group
  WHERE academic_group.id = NEW.group_id
  FOR SHARE;

  IF NOT FOUND OR v_group.active IS DISTINCT FROM true THEN
    RAISE EXCEPTION
      'Academic group is missing or inactive'
      USING ERRCODE = '23514';
  END IF;

  IF NEW.career_id IS DISTINCT FROM v_group.career_id
     OR NEW.semester IS DISTINCT FROM v_group.semester THEN
    RAISE EXCEPTION
      'Academic group does not match career and semester'
      USING ERRCODE = '23514';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.careers AS career
    WHERE career.id = NEW.career_id
      AND career.active = true
  ) THEN
    RAISE EXCEPTION
      'Academic career is inactive'
      USING ERRCODE = '23514';
  END IF;

  v_today :=
    (now() AT TIME ZONE 'America/Mexico_City')::date;

  SELECT count(*), min(period.id::text)::uuid
  INTO v_period_count, v_period_id
  FROM public.academic_periods AS period
  WHERE v_today BETWEEN period.starts_on AND period.ends_on;

  IF v_period_count <> 1 THEN
    RAISE EXCEPTION
      'No unique academic offering period is configured'
      USING ERRCODE = '23514';
  END IF;

  -- Bloquear la oferta para evitar retirarla mientras
  -- esta asignacion se confirma.
  SELECT offering.group_id
  INTO v_offering_group
  FROM public.academic_group_offerings AS offering
  WHERE offering.academic_period_id = v_period_id
    AND offering.group_id = NEW.group_id
    AND offering.is_offered = true
  FOR SHARE;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'Academic group is not offered in current period'
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$function$;

CREATE TRIGGER conecta_guard_student_academic_assignment
BEFORE INSERT OR UPDATE OF career_id, semester, group_id
ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.guard_student_academic_group_assignment();

REVOKE ALL ON FUNCTION
public.guard_student_academic_group_assignment()
FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_registration_offered_groups(
  p_career_id text,
  p_semester smallint
)
RETURNS TABLE (
  id text,
  career_id text,
  name text,
  semester smallint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  current_period_id uuid;
  today_local date;
  matching_periods integer;
BEGIN
  IF p_career_id IS NULL
     OR length(trim(p_career_id)) = 0
     OR p_semester IS NULL
     OR p_semester NOT BETWEEN 1 AND 12 THEN
    RETURN;
  END IF;

  today_local :=
    (now() AT TIME ZONE 'America/Mexico_City')::date;

  SELECT count(*), min(period.id::text)::uuid
  INTO matching_periods, current_period_id
  FROM public.academic_periods AS period
  WHERE today_local BETWEEN period.starts_on AND period.ends_on;

  -- No exponer ofertas si el calendario no es inequívoco.
  IF matching_periods <> 1 THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    academic_group.id,
    academic_group.career_id,
    academic_group.name,
    academic_group.semester
  FROM public.academic_group_offerings AS offering
  JOIN public.academic_groups AS academic_group
    ON academic_group.id = offering.group_id
  JOIN public.careers AS career
    ON career.id = academic_group.career_id
  WHERE offering.academic_period_id = current_period_id
    AND offering.is_offered = true
    AND academic_group.career_id = lower(trim(p_career_id))
    AND academic_group.semester = p_semester
    AND academic_group.active = true
    AND career.active = true
  ORDER BY academic_group.id;
END;
$function$;

COMMIT;
