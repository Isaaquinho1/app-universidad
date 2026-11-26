
-- ============================================================
-- CONECTA ITT | SUPERADMINISTRACIÓN ACADÉMICA
-- Restricción de grupos y ofertas académicas a SuperAdmin.
--
-- Conserva:
--   - Firmas de las funciones existentes.
--   - Validaciones académicas.
--   - Auditoría de operaciones.
--   - Bloqueos de concurrencia.
--   - Identificadores exactos de grupos.
--   - Historial académico.
-- ============================================================

BEGIN;

DO $migration$
DECLARE
  target RECORD;
  function_oid oid;
  original_definition text;
  updated_definition text;
  actual_hash text;
  occurrences integer;
BEGIN

  -- Verificar la función institucional de autorización.
  IF md5(
    pg_get_functiondef(
      'public.is_super_admin()'::regprocedure
    )
  ) IS DISTINCT FROM '7b82ac6c491b2ff6217174813ef21e9c'
  THEN
    RAISE EXCEPTION
      'La función is_super_admin difiere de la versión auditada';
  END IF;

  FOR target IN
    SELECT *
    FROM (
      VALUES
        (
          'public.admin_create_academic_group(text,integer,integer)',
          '4692a203c06c8ee336c3abaae8bc9d38',
          'profile.role IN (''admin'', ''superAdmin'')',
          'profile.role = ''superAdmin'''
        ),
        (
          'public.admin_get_academic_group_offerings(text,text,smallint)',
          '25b717a9499d6af71529a3fcefb54fe8',
          'public.is_admin()',
          'public.is_super_admin()'
        ),
        (
          'public.admin_set_academic_group_active(text,boolean)',
          '05f9cd2c624a837bf813a99dc1e17d2e',
          'profile.role IN (''admin'', ''superAdmin'')',
          'profile.role = ''superAdmin'''
        ),
        (
          'public.admin_set_academic_group_offering(text,text,boolean)',
          'a6e3e477c6d85221dd56fa92e23f1151',
          'profile.role IN (''admin'', ''superAdmin'')',
          'profile.role = ''superAdmin'''
        )
    ) AS definitions(
      function_signature,
      expected_hash,
      old_condition,
      new_condition
    )
  LOOP

    function_oid := to_regprocedure(
      target.function_signature
    );

    IF function_oid IS NULL THEN
      RAISE EXCEPTION
        'No se encontró la función: %',
        target.function_signature;
    END IF;

    original_definition :=
      pg_get_functiondef(function_oid);

    actual_hash := md5(original_definition);

    -- Impedir modificaciones sobre funciones no auditadas.
    IF actual_hash IS DISTINCT FROM target.expected_hash THEN
      RAISE EXCEPTION
        'Definición inesperada: %. Hash actual: %',
        target.function_signature,
        actual_hash;
    END IF;

    -- La condición debe aparecer exactamente una vez.
    occurrences := (
      length(original_definition)
      - length(
          replace(
            original_definition,
            target.old_condition,
            ''
          )
        )
    ) / length(target.old_condition);

    IF occurrences <> 1 THEN
      RAISE EXCEPTION
        'Condición de autorización inesperada en: %',
        target.function_signature;
    END IF;

    updated_definition := replace(
      original_definition,
      target.old_condition,
      target.new_condition
    );

    updated_definition := replace(
      updated_definition,
      '''Admin privileges required''',
      '''SuperAdmin privileges required'''
    );

    updated_definition := replace(
      updated_definition,
      '''Not authorized''',
      '''SuperAdmin privileges required'''
    );

    EXECUTE updated_definition;

    -- Comprobar que permanece SECURITY DEFINER.
    IF NOT EXISTS (
      SELECT 1
      FROM pg_proc
      WHERE oid = function_oid
        AND prosecdef = true
    ) THEN
      RAISE EXCEPTION
        'SECURITY DEFINER no conservado: %',
        target.function_signature;
    END IF;

    -- Mantener bloqueada la ejecución anónima.
    IF has_function_privilege(
      'anon',
      function_oid,
      'EXECUTE'
    ) THEN
      RAISE EXCEPTION
        'Acceso anónimo inesperado: %',
        target.function_signature;
    END IF;

    -- Los usuarios autenticados deben poder invocar la RPC.
    -- La autorización institucional se comprueba internamente.
    IF NOT has_function_privilege(
      'authenticated',
      function_oid,
      'EXECUTE'
    ) THEN
      RAISE EXCEPTION
        'Privilegio authenticated no conservado: %',
        target.function_signature;
    END IF;

    -- Comprobar que la condición nueva quedó instalada.
    IF strpos(
      pg_get_functiondef(function_oid),
      target.new_condition
    ) = 0 THEN
      RAISE EXCEPTION
        'No se instaló la restricción SuperAdmin: %',
        target.function_signature;
    END IF;

    RAISE NOTICE
      'PASS: acceso exclusivo SuperAdmin en %',
      target.function_signature;

  END LOOP;

  RAISE NOTICE
    'PASS: las cuatro RPC académicas fueron restringidas';

END;
$migration$;

COMMIT;
