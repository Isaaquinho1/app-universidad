-- Conecta ITT | Bloque 9.8G.32B
-- Orden de bloqueos: grupo antes de oferta.
-- Conserva autorizacion y auditoria existentes.
-- No modifica datos academicos.

BEGIN;

DO $preflight$
BEGIN
  IF md5(pg_get_functiondef(
    'public.admin_set_academic_group_offering(text,text,boolean)'::regprocedure
  )) <> '7bd5b7291f8d8e11f14ec87458aa6292' THEN
    RAISE EXCEPTION
      'Installed offering RPC differs from audited version';
  END IF;
END;
$preflight$;

CREATE OR REPLACE FUNCTION public.admin_set_academic_group_offering(p_period_code text, p_group_id text, p_is_offered boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
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
  -- Bloquear primero el grupo y despues su oferta.
  -- Mantener el mismo orden que las asignaciones.
  PERFORM 1
  FROM public.academic_groups
  WHERE id = normalized_group
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Academic group not found'
      USING ERRCODE = 'P0002';
  END IF;

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

COMMIT;
