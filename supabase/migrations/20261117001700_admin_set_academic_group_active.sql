-- ============================================================
-- Conecta ITT | Bloque 9.8G
-- Administracion auditada del estado del catalogo de grupos.
-- No modifica ofertas ni asignaciones de estudiantes.
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS
public.academic_group_status_audit (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  group_id text NOT NULL
    REFERENCES public.academic_groups(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  previous_active boolean NOT NULL,
  new_active boolean NOT NULL,
  changed_by uuid NOT NULL
    REFERENCES auth.users(id) ON DELETE RESTRICT,
  changed_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.academic_group_status_audit
ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE
public.academic_group_status_audit
FROM PUBLIC, anon, authenticated;

-- Evitar reemplazar una funcion instalada.
DO $preflight$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'admin_set_academic_group_active'
  ) THEN
    RAISE EXCEPTION
      'La funcion administrativa ya existe';
  END IF;
END;
$preflight$;

CREATE FUNCTION public.admin_set_academic_group_active(
  p_group_id text,
  p_active boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_actor uuid;
  v_group_id text;
  v_previous_active boolean;
BEGIN
  v_actor := (SELECT auth.uid());

  IF v_actor IS NULL OR NOT EXISTS (
    SELECT 1
    FROM public.profiles AS profile
    WHERE profile.id = v_actor
      AND profile.active = true
      AND profile.role IN ('admin', 'superAdmin')
  ) THEN
    RAISE EXCEPTION 'Not authorized'
      USING ERRCODE = '42501';
  END IF;

  v_group_id := upper(trim(coalesce(p_group_id, '')));

  IF v_group_id = '' OR p_active IS NULL THEN
    RAISE EXCEPTION 'Invalid group status parameters'
      USING ERRCODE = '22023';
  END IF;

  SELECT academic_group.active
  INTO v_previous_active
  FROM public.academic_groups AS academic_group
  WHERE academic_group.id = v_group_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Academic group not found'
      USING ERRCODE = 'P0002';
  END IF;

  -- Operacion idempotente: sin cambio, sin nueva auditoria.
  IF v_previous_active IS NOT DISTINCT FROM p_active THEN
    RETURN;
  END IF;

  UPDATE public.academic_groups
  SET
    active = p_active,
    updated_at = now()
  WHERE id = v_group_id;

  INSERT INTO public.academic_group_status_audit (
    group_id,
    previous_active,
    new_active,
    changed_by
  )
  VALUES (
    v_group_id,
    v_previous_active,
    p_active,
    v_actor
  );
END;
$function$;

REVOKE ALL
ON FUNCTION public.admin_set_academic_group_active(
  text, boolean
)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.admin_set_academic_group_active(
  text, boolean
)
TO authenticated;

COMMENT ON FUNCTION
public.admin_set_academic_group_active(text, boolean)
IS
  'Changes academic group catalog status with admin authorization and audit.';

COMMIT;
