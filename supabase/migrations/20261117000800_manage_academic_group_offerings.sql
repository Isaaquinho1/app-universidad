
BEGIN;

-- Verificar que la estructura del paso 9.2 está instalada.
DO $$
BEGIN
  IF to_regclass('public.academic_group_offerings') IS NULL
     OR to_regclass('public.academic_groups') IS NULL THEN
    RAISE EXCEPTION 'Falta la estructura del paso 9.2';
  END IF;

  IF to_regclass('public.academic_group_offering_audit')
     IS NOT NULL THEN
    RAISE EXCEPTION 'La tabla de auditoría ya existe';
  END IF;
END;
$$;

-- Historial de cambios de la oferta académica.
CREATE TABLE public.academic_group_offering_audit (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

  academic_period_id uuid NOT NULL
    REFERENCES public.academic_periods(id),

  group_id text NOT NULL
    REFERENCES public.academic_groups(id),

  previous_is_offered boolean,
  new_is_offered boolean NOT NULL,

  changed_by uuid NOT NULL
    REFERENCES auth.users(id),

  changed_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX academic_group_offering_audit_lookup_idx
ON public.academic_group_offering_audit (
  academic_period_id,
  group_id,
  changed_at DESC
);

ALTER TABLE public.academic_group_offering_audit
ENABLE ROW LEVEL SECURITY;

REVOKE ALL
ON public.academic_group_offering_audit
FROM PUBLIC, anon, authenticated;

-- ======================================================
-- Crear grupo base o paralelo.
-- Ejemplos: T21, T22, T23, G32, E42, A12.
-- La creación NO lo habilita para registro.
-- ======================================================

CREATE OR REPLACE FUNCTION
public.admin_create_academic_group(
  p_career_id text,
  p_semester integer,
  p_parallel integer
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  normalized_career text;
  prefix text;
  new_group_id text;
  existing_group public.academic_groups;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.profiles AS profile
    WHERE profile.id = (SELECT auth.uid())
      AND profile.active = true
      AND profile.role IN ('admin', 'superAdmin')
  ) THEN
    RAISE EXCEPTION 'Not authorized'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  normalized_career := lower(trim(coalesce(p_career_id, '')));

  prefix := CASE normalized_career
    WHEN 'itic-2010-225' THEN 'T'
    WHEN 'igem-2009-201' THEN 'G'
    WHEN 'ielc-2010-211' THEN 'E'
    WHEN 'ladm-2010-234' THEN 'A'
    ELSE NULL
  END;

  IF prefix IS NULL OR NOT EXISTS (
    SELECT 1
    FROM public.careers
    WHERE id = normalized_career
      AND active = true
  ) THEN
    RAISE EXCEPTION 'Invalid academic career'
      USING ERRCODE = 'invalid_parameter_value';
  END IF;

  -- Nomenclatura institucional ordinaria.
  -- Los semestres extraordinarios se definirán aparte.
  IF p_semester IS NULL OR p_semester NOT BETWEEN 1 AND 9
     OR p_parallel IS NULL OR p_parallel NOT BETWEEN 1 AND 9
  THEN
    RAISE EXCEPTION 'Invalid semester or parallel group'
      USING ERRCODE = 'invalid_parameter_value';
  END IF;

  new_group_id :=
    prefix || p_semester::text || p_parallel::text;

  INSERT INTO public.academic_groups (
    id, career_id, name, semester, active
  )
  VALUES (
    new_group_id,
    normalized_career,
    new_group_id,
    p_semester::smallint,
    false
  )
  ON CONFLICT (id) DO NOTHING;

  SELECT *
  INTO existing_group
  FROM public.academic_groups
  WHERE id = new_group_id;

  IF existing_group.id IS NULL
     OR existing_group.career_id
          IS DISTINCT FROM normalized_career
     OR existing_group.semester
          IS DISTINCT FROM p_semester THEN
    RAISE EXCEPTION 'Conflicting academic group'
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN new_group_id;
END;
$function$;

REVOKE ALL
ON FUNCTION public.admin_create_academic_group(
  text, integer, integer
)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.admin_create_academic_group(
  text, integer, integer
)
TO authenticated;

-- ======================================================
-- Habilitar/deshabilitar una oferta por periodo.
-- No altera la matrícula ni academic_groups.active.
-- ======================================================

CREATE OR REPLACE FUNCTION
public.admin_set_academic_group_offering(
  p_period_code text,
  p_group_id text,
  p_is_offered boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  normalized_code text;
  normalized_group text;
  selected_period public.academic_periods;
  previous_value boolean;
  offering_exists boolean;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.profiles AS profile
    WHERE profile.id = (SELECT auth.uid())
      AND profile.active = true
      AND profile.role IN ('admin', 'superAdmin')
  ) THEN
    RAISE EXCEPTION 'Not authorized'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  normalized_code := trim(coalesce(p_period_code, ''));
  normalized_group := upper(trim(coalesce(p_group_id, '')));

  IF normalized_code = ''
     OR normalized_group = ''
     OR p_is_offered IS NULL THEN
    RAISE EXCEPTION 'Invalid offering parameters'
      USING ERRCODE = 'invalid_parameter_value';
  END IF;

  SELECT *
  INTO selected_period
  FROM public.academic_periods
  WHERE code = normalized_code;

  IF selected_period.id IS NULL
     OR selected_period.starts_on IS NULL
     OR selected_period.ends_on IS NULL THEN
    RAISE EXCEPTION 'Invalid academic period'
      USING ERRCODE = 'invalid_parameter_value';
  END IF;

  -- No modificar ofertas de periodos ya finalizados.
  IF selected_period.ends_on <
     (now() AT TIME ZONE 'America/Mexico_City')::date THEN
    RAISE EXCEPTION 'Academic period already finished'
      USING ERRCODE = 'check_violation';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.academic_groups AS academic_group
    JOIN public.careers AS career
      ON career.id = academic_group.career_id
    WHERE academic_group.id = normalized_group
      AND career.active = true
  ) THEN
    RAISE EXCEPTION 'Academic group not found'
      USING ERRCODE = 'no_data_found';
  END IF;

  -- Serializar cambios concurrentes de la misma oferta.
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext(
      selected_period.id::text || ':' || normalized_group
    )
  );

  SELECT is_offered, true
  INTO previous_value, offering_exists
  FROM public.academic_group_offerings
  WHERE academic_period_id = selected_period.id
    AND group_id = normalized_group
  FOR UPDATE;

  IF coalesce(offering_exists, false)
     AND previous_value IS NOT DISTINCT FROM p_is_offered THEN
    RETURN;
  END IF;

  INSERT INTO public.academic_group_offerings (
    academic_period_id,
    group_id,
    is_offered,
    updated_by
  )
  VALUES (
    selected_period.id,
    normalized_group,
    p_is_offered,
    (SELECT auth.uid())
  )
  ON CONFLICT (academic_period_id, group_id)
  DO UPDATE SET
    is_offered = excluded.is_offered,
    updated_by = excluded.updated_by,
    updated_at = now();

  INSERT INTO public.academic_group_offering_audit (
    academic_period_id,
    group_id,
    previous_is_offered,
    new_is_offered,
    changed_by
  )
  VALUES (
    selected_period.id,
    normalized_group,
    CASE
      WHEN coalesce(offering_exists, false)
        THEN previous_value
      ELSE NULL
    END,
    p_is_offered,
    (SELECT auth.uid())
  );
END;
$function$;

REVOKE ALL
ON FUNCTION public.admin_set_academic_group_offering(
  text, text, boolean
)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.admin_set_academic_group_offering(
  text, text, boolean
)
TO authenticated;

COMMIT;
