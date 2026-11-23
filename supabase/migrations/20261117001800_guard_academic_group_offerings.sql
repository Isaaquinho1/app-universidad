-- ============================================================
-- Conecta ITT | Bloque 9.8G.13
-- Consistencia entre grupos activos y ofertas academicas.
--
-- No activa grupos.
-- No crea ofertas.
-- No altera perfiles ni matriculas.
-- ============================================================

BEGIN;

-- Rechazar objetos ya existentes en lugar de sobrescribirlos.
DO $preflight$
BEGIN
  IF to_regprocedure(
    'public.guard_academic_group_offering_active()'
  ) IS NOT NULL
  OR to_regprocedure(
    'public.guard_academic_group_deactivation()'
  ) IS NOT NULL
  OR EXISTS (
    SELECT 1 FROM pg_catalog.pg_trigger
    WHERE tgrelid IN (
      'public.academic_groups'::regclass,
      'public.academic_group_offerings'::regclass
    )
    AND tgname IN (
      'conecta_guard_group_offering_active',
      'conecta_guard_group_deactivation'
    )
  ) THEN
    RAISE EXCEPTION
      'Las protecciones ya existen; revisar antes de aplicar';
  END IF;
END;
$preflight$;

-- ============================================================
-- 1. No habilitar ofertas para grupos inactivos.
--
-- Bloquear la fila del grupo evita que otra transaccion
-- cambie su estado mientras se registra la oferta.
-- ============================================================

CREATE FUNCTION public.guard_academic_group_offering_active()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_group_active boolean;
  v_career_active boolean;
BEGIN
  IF NEW.is_offered IS DISTINCT FROM true THEN
    RETURN NEW;
  END IF;

  SELECT academic_group.active, career.active
  INTO v_group_active, v_career_active
  FROM public.academic_groups AS academic_group
  JOIN public.careers AS career
    ON career.id = academic_group.career_id
  WHERE academic_group.id = NEW.group_id
  FOR UPDATE OF academic_group;

  IF NOT FOUND
     OR v_group_active IS DISTINCT FROM true
     OR v_career_active IS DISTINCT FROM true THEN
    RAISE EXCEPTION
      'Cannot offer an inactive academic group or career'
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$function$;

CREATE TRIGGER conecta_guard_group_offering_active
BEFORE INSERT OR UPDATE
ON public.academic_group_offerings
FOR EACH ROW
EXECUTE FUNCTION public.guard_academic_group_offering_active();

-- ============================================================
-- 2. No desactivar grupos con ofertas vigentes o futuras.
--
-- La fila del grupo ya esta bloqueada por el UPDATE.
-- El trigger anterior utiliza el mismo bloqueo.
-- ============================================================

CREATE FUNCTION public.guard_academic_group_deactivation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF OLD.active IS DISTINCT FROM true
     OR NEW.active IS DISTINCT FROM false THEN
    RETURN NEW;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.academic_group_offerings AS offering
    JOIN public.academic_periods AS period
      ON period.id = offering.academic_period_id
    WHERE offering.group_id = OLD.id
      AND offering.is_offered = true
      AND (
        period.ends_on IS NULL
        OR period.ends_on >=
          (now() AT TIME ZONE 'America/Mexico_City')::date
      )
  ) THEN
    RAISE EXCEPTION
      'Disable current or future offerings before deactivating group'
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$function$;

CREATE TRIGGER conecta_guard_group_deactivation
BEFORE UPDATE OF active
ON public.academic_groups
FOR EACH ROW
EXECUTE FUNCTION public.guard_academic_group_deactivation();

-- No permitir que usuarios de la aplicacion invoquen
-- directamente las funciones auxiliares.
REVOKE ALL ON FUNCTION
public.guard_academic_group_offering_active()
FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION
public.guard_academic_group_deactivation()
FROM PUBLIC, anon, authenticated;

COMMIT;
