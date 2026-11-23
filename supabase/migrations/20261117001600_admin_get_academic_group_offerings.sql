
-- CONECTA ITT
-- Bloque 9.8D: consulta administrativa de ofertas.
-- No altera el catalogo, periodos, ofertas ni perfiles.

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

DO $guard$
BEGIN
  IF to_regprocedure(
    'public.admin_get_academic_group_offerings(text,text,smallint)'
  ) IS NOT NULL THEN
    RAISE EXCEPTION
      'Administrative offerings RPC already exists';
  END IF;
END;
$guard$;

CREATE FUNCTION public.admin_get_academic_group_offerings(
  p_period_code text,
  p_career_id text DEFAULT NULL,
  p_semester smallint DEFAULT NULL
)
RETURNS TABLE (
  academic_period_id uuid,
  period_code text,
  period_name text,
  period_starts_on date,
  period_ends_on date,
  group_id text,
  group_name text,
  career_id text,
  semester smallint,
  group_active boolean,
  offering_registered boolean,
  is_offered boolean,
  offering_updated_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_period public.academic_periods%ROWTYPE;
  v_period_code text;
  v_career_id text;
BEGIN
  -- Las funciones SECURITY DEFINER no deben
  -- basarse en el rol declarado por el cliente.
  IF (SELECT auth.uid()) IS NULL
     OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'Admin privileges required'
      USING ERRCODE = '42501';
  END IF;

  v_period_code := NULLIF(
    trim(coalesce(p_period_code, '')), ''
  );

  v_career_id := NULLIF(
    lower(trim(coalesce(p_career_id, ''))), ''
  );

  IF v_period_code IS NULL THEN
    RAISE EXCEPTION 'Academic period is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_semester IS NOT NULL
     AND p_semester NOT BETWEEN 1 AND 14 THEN
    RAISE EXCEPTION 'Invalid semester'
      USING ERRCODE = '22023';
  END IF;

  SELECT *
  INTO v_period
  FROM public.academic_periods AS period
  WHERE period.code = v_period_code;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Academic period not found'
      USING ERRCODE = 'P0002';
  END IF;

  RETURN QUERY
  SELECT
    period.id,
    period.code,
    period.name,
    period.starts_on,
    period.ends_on,
    academic_group.id,
    academic_group.name,
    academic_group.career_id,
    academic_group.semester,
    academic_group.active,
    offering.academic_period_id IS NOT NULL,
    coalesce(offering.is_offered, false),
    offering.updated_at
  FROM public.academic_groups AS academic_group
  JOIN public.academic_periods AS period
    ON period.id = v_period.id
  LEFT JOIN public.academic_group_offerings AS offering
    ON offering.academic_period_id = period.id
   AND offering.group_id = academic_group.id
  WHERE
    (v_career_id IS NULL
      OR academic_group.career_id = v_career_id)
    AND
    (p_semester IS NULL
      OR academic_group.semester = p_semester)
  ORDER BY
    academic_group.career_id,
    academic_group.semester NULLS LAST,
    academic_group.id;
END;
$function$;

REVOKE ALL
ON FUNCTION
public.admin_get_academic_group_offerings(
  text, text, smallint
)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION
public.admin_get_academic_group_offerings(
  text, text, smallint
)
TO authenticated;

DO $verify$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc
    WHERE oid =
      'public.admin_get_academic_group_offerings(text,text,smallint)'
        ::regprocedure
      AND prosecdef = true
  ) THEN
    RAISE EXCEPTION 'Function must be SECURITY DEFINER';
  END IF;

  IF has_function_privilege(
    'anon',
    'public.admin_get_academic_group_offerings(text,text,smallint)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'Anonymous access is not allowed';
  END IF;

  IF NOT has_function_privilege(
    'authenticated',
    'public.admin_get_academic_group_offerings(text,text,smallint)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'Authenticated role cannot invoke RPC';
  END IF;

  IF has_table_privilege(
    'authenticated',
    'public.academic_group_offerings',
    'SELECT'
  ) THEN
    RAISE EXCEPTION 'Direct offering access must remain restricted';
  END IF;

  RAISE NOTICE 'PASS: administrative offering RPC installed';
END;
$verify$;

COMMIT;
