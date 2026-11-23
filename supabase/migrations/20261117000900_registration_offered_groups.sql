
BEGIN;

DO $$
BEGIN
  IF to_regclass('public.academic_group_offerings') IS NULL THEN
    RAISE EXCEPTION 'Falta la tabla de ofertas academicas';
  END IF;

  IF to_regprocedure(
    'public.get_registration_offered_groups(text,smallint)'
  ) IS NOT NULL THEN
    RAISE EXCEPTION 'La funcion ya existe';
  END IF;
END;
$$;

CREATE FUNCTION public.get_registration_offered_groups(
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
    AND career.active = true
  ORDER BY academic_group.id;
END;
$function$;

REVOKE ALL ON FUNCTION
public.get_registration_offered_groups(text,smallint)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION
public.get_registration_offered_groups(text,smallint)
TO anon, authenticated;

COMMIT;
