
BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.academic_periods
    WHERE code = '2026-2'
      AND starts_on = DATE '2026-08-01'
      AND ends_on = DATE '2026-12-31'
  ) THEN
    RAISE EXCEPTION 'Periodo 2026-2 inesperado';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.academic_periods
    WHERE code = '2027-1'
      AND (
        starts_on IS DISTINCT FROM DATE '2027-01-25'
        OR ends_on IS DISTINCT FROM DATE '2027-06-04'
      )
  ) THEN
    RAISE EXCEPTION '2027-1 tiene fechas diferentes';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.academic_periods
    WHERE code <> '2027-1'
      AND starts_on <= DATE '2027-06-04'
      AND ends_on >= DATE '2027-01-25'
  ) THEN
    RAISE EXCEPTION 'Hay periodos superpuestos';
  END IF;
END;
$$;

INSERT INTO public.academic_periods (
  code, name, starts_on, ends_on, is_active
)
VALUES (
  '2027-1',
  'Enero–Junio 2027',
  DATE '2027-01-25',
  DATE '2027-06-04',
  false
)
ON CONFLICT (code) DO NOTHING;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.academic_periods
    WHERE code = '2027-1'
      AND starts_on = DATE '2027-01-25'
      AND ends_on = DATE '2027-06-04'
      AND is_active = false
  ) THEN
    RAISE EXCEPTION 'Configuración 2027-1 inesperada';
  END IF;
END;
$$;

COMMIT;
