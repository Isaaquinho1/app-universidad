-- Conecta ITT | Declared identity of institutional staff.
-- These fields do not grant permissions or verify employment.

BEGIN;

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS staff_department_declared text,
ADD COLUMN IF NOT EXISTS staff_position_declared text;

ALTER TABLE public.profiles
ADD CONSTRAINT staff_department_declared_length
CHECK (
  staff_department_declared IS NULL
  OR char_length(staff_department_declared) BETWEEN 2 AND 120
),
ADD CONSTRAINT staff_position_declared_length
CHECK (
  staff_position_declared IS NULL
  OR char_length(staff_position_declared) BETWEEN 2 AND 120
);

COMMENT ON COLUMN public.profiles.staff_department_declared IS
  'Department declared by applicant. Not independently verified.';

COMMENT ON COLUMN public.profiles.staff_position_declared IS
  'Job title declared by applicant. Not independently verified.';

CREATE FUNCTION public.capture_declared_staff_identity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_metadata jsonb;
  v_department text;
  v_position text;
BEGIN
  -- Student accounts must never inherit staff identity.
  IF NEW.account_type NOT IN ('campusStaff', 'tecnmStaff') THEN
    NEW.staff_department_declared := NULL;
    NEW.staff_position_declared := NULL;
    RETURN NEW;
  END IF;

  SELECT u.raw_user_meta_data
  INTO v_metadata
  FROM auth.users AS u
  WHERE u.id = NEW.id;

  v_department := nullif(
    btrim(coalesce(v_metadata ->> 'staffDepartment', '')),
    ''
  );

  v_position := nullif(
    btrim(coalesce(v_metadata ->> 'staffPosition', '')),
    ''
  );

  IF v_department IS NULL
     OR char_length(v_department) < 2
     OR char_length(v_department) > 120 THEN
    RAISE EXCEPTION 'Invalid declared staff department'
      USING errcode = 'check_violation';
  END IF;

  IF v_position IS NULL
     OR char_length(v_position) < 2
     OR char_length(v_position) > 120 THEN
    RAISE EXCEPTION 'Invalid declared staff position'
      USING errcode = 'check_violation';
  END IF;

  NEW.staff_department_declared := v_department;
  NEW.staff_position_declared := v_position;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION
public.capture_declared_staff_identity()
FROM PUBLIC, anon, authenticated;

CREATE TRIGGER capture_declared_staff_identity
BEFORE INSERT ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.capture_declared_staff_identity();

COMMIT;
