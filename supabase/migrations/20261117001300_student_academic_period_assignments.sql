
-- CONECTA ITT
-- Bloque 9.7C: historial academico por periodo.
-- No realiza backfill ni modifica public.profiles.

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

DO $guard$
BEGIN
  IF to_regclass(
    'public.student_academic_period_assignments'
  ) IS NOT NULL THEN
    RAISE EXCEPTION 'Academic history table already exists';
  END IF;
END;
$guard$;

CREATE TABLE public.student_academic_period_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  user_id uuid NOT NULL
    REFERENCES auth.users(id)
    ON DELETE CASCADE,

  academic_period_id uuid NOT NULL
    REFERENCES public.academic_periods(id)
    ON DELETE RESTRICT,

  career_id text NOT NULL
    REFERENCES public.careers(id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,

  semester smallint NOT NULL
    CHECK (semester BETWEEN 1 AND 14),

  group_id text
    REFERENCES public.academic_groups(id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,

  created_at timestamptz NOT NULL
    DEFAULT timezone('utc', now()),

  updated_at timestamptz NOT NULL
    DEFAULT timezone('utc', now()),

  updated_by uuid
    REFERENCES auth.users(id)
    ON DELETE SET NULL,

  CONSTRAINT student_academic_period_unique
    UNIQUE (user_id, academic_period_id)
);

CREATE INDEX student_academic_period_assignments_period_idx
ON public.student_academic_period_assignments (
  academic_period_id, career_id, semester
);

CREATE INDEX student_academic_period_assignments_group_idx
ON public.student_academic_period_assignments (
  group_id
)
WHERE group_id IS NOT NULL;

ALTER TABLE public.student_academic_period_assignments
ENABLE ROW LEVEL SECURITY;

-- Sin acceso directo desde clientes moviles.
-- Los RPC autorizados se incorporaran posteriormente.
REVOKE ALL
ON TABLE public.student_academic_period_assignments
FROM PUBLIC, anon, authenticated;

DO $verify$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_class
    WHERE oid =
      'public.student_academic_period_assignments'::regclass
      AND relrowsecurity = true
  ) THEN
    RAISE EXCEPTION 'RLS is not enabled';
  END IF;

  IF has_table_privilege(
    'anon',
    'public.student_academic_period_assignments',
    'SELECT'
  ) OR has_table_privilege(
    'authenticated',
    'public.student_academic_period_assignments',
    'SELECT'
  ) THEN
    RAISE EXCEPTION 'Unexpected client SELECT permission';
  END IF;

  IF (
    SELECT count(*)
    FROM public.student_academic_period_assignments
  ) <> 0 THEN
    RAISE EXCEPTION 'History table must start empty';
  END IF;

  RAISE NOTICE 'PASS: academic history table verified';
END;
$verify$;

COMMIT;
