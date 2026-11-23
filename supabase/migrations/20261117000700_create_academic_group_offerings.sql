
BEGIN;

-- ============================================================
-- 1. Precondiciones: no sobrescribir una estructura existente.
-- ============================================================

DO $$
BEGIN
  IF to_regclass('public.academic_group_offerings') IS NOT NULL THEN
    RAISE EXCEPTION
      'La tabla de ofertas ya existe: requiere revision';
  END IF;

  IF (
    SELECT count(*)
    FROM public.careers
    WHERE id IN (
      'itic-2010-225',
      'igem-2009-201',
      'ielc-2010-211',
      'ladm-2010-234'
    )
      AND active = true
  ) <> 4 THEN
    RAISE EXCEPTION
      'No estan disponibles las cuatro carreras';
  END IF;
END;
$$;

-- ============================================================
-- 2. Catalogo de grupos base: semestres 1 al 9.
-- Los grupos existentes NO se modifican.
-- Los nuevos grupos comienzan inactivos.
-- ============================================================

WITH carreras(career_id, prefix) AS (
  VALUES
    ('itic-2010-225'::text, 'T'::text),
    ('igem-2009-201'::text, 'G'::text),
    ('ielc-2010-211'::text, 'E'::text),
    ('ladm-2010-234'::text, 'A'::text)
),
grupos AS (
  SELECT
    prefix || semester::text || '1' AS group_id,
    career_id,
    semester::smallint AS semester
  FROM carreras
  CROSS JOIN generate_series(1, 9) AS semester
)
INSERT INTO public.academic_groups (
  id,
  career_id,
  name,
  semester,
  active
)
SELECT
  group_id,
  career_id,
  group_id,
  semester,
  false
FROM grupos
ON CONFLICT (id) DO NOTHING;

-- Comprobar que no hay colisiones de identificadores
-- con carreras o semestres incorrectos.
DO $$
DECLARE
  invalid_count integer;
BEGIN
  WITH carreras(career_id, prefix) AS (
    VALUES
      ('itic-2010-225'::text, 'T'::text),
      ('igem-2009-201'::text, 'G'::text),
      ('ielc-2010-211'::text, 'E'::text),
      ('ladm-2010-234'::text, 'A'::text)
  ),
  esperados AS (
    SELECT
      prefix || semester::text || '1' AS group_id,
      career_id,
      semester
    FROM carreras
    CROSS JOIN generate_series(1, 9) AS semester
  )
  SELECT count(*)
  INTO invalid_count
  FROM esperados e
  LEFT JOIN public.academic_groups g ON g.id = e.group_id
  WHERE g.id IS NULL
     OR g.career_id IS DISTINCT FROM e.career_id
     OR g.semester IS DISTINCT FROM e.semester;

  IF invalid_count <> 0 THEN
    RAISE EXCEPTION
      'Hay grupos base con carrera o semestre incorrectos';
  END IF;
END;
$$;

-- ============================================================
-- 3. Oferta de grupos POR PERIODO academico.
--
-- Un mismo grupo puede ofertarse en 2027-1 y no ofertarse
-- en 2027-2. El historial de periodos se conserva.
-- ============================================================

CREATE TABLE public.academic_group_offerings (
  academic_period_id uuid NOT NULL
    REFERENCES public.academic_periods(id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,

  group_id text NOT NULL
    REFERENCES public.academic_groups(id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,

  is_offered boolean NOT NULL DEFAULT false,

  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  updated_by uuid
    REFERENCES auth.users(id)
    ON DELETE SET NULL,

  PRIMARY KEY (academic_period_id, group_id)
);

CREATE INDEX academic_group_offerings_group_idx
ON public.academic_group_offerings(group_id);

CREATE INDEX academic_group_offerings_enabled_idx
ON public.academic_group_offerings(academic_period_id)
WHERE is_offered = true;

-- Sin acceso directo del cliente hasta instalar
-- funciones administrativas y politicas especificas.
ALTER TABLE public.academic_group_offerings
ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.academic_group_offerings
FROM PUBLIC, anon, authenticated;

COMMENT ON TABLE public.academic_group_offerings IS
  'Oferta institucional de grupos por periodo academico. '
  'No determina ni modifica las asignaciones historicas.';

-- NO insertar ofertas como activas:
-- deben ser confirmadas por administracion.
-- NO modificar academic_groups.active de grupos existentes.
-- NO modificar profiles.group_id.

COMMIT;
