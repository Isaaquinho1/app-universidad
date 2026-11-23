-- Conecta ITT | Student approval-seen state.
-- An FCM notification being sent does not mean it was viewed.

BEGIN;

ALTER TABLE public.profiles
ADD COLUMN photo_approval_seen_reviewed_at timestamptz;

COMMENT ON COLUMN
public.profiles.photo_approval_seen_reviewed_at IS
  'Review timestamp of the approved credential photo '
  'last viewed by the student.';

CREATE FUNCTION public.get_own_photo_approval_unseen()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles AS p
    WHERE p.id = (SELECT auth.uid())
      AND p.role = 'student'
      AND p.active IS TRUE
      AND p.photo_status = 'approved'
      AND p.photo_reviewed_at IS NOT NULL
      AND p.photo_approval_seen_reviewed_at
          IS DISTINCT FROM p.photo_reviewed_at
  );
$function$;

CREATE FUNCTION public.mark_own_photo_approval_seen(
  p_expected_photo_path text,
  p_expected_reviewed_at timestamptz
)
RETURNS boolean
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_updated integer;
BEGIN
  IF p_expected_photo_path IS NULL
     OR btrim(p_expected_photo_path) = ''
     OR p_expected_reviewed_at IS NULL THEN
    RETURN false;
  END IF;

  UPDATE public.profiles AS p
  SET photo_approval_seen_reviewed_at = p.photo_reviewed_at
  WHERE p.id = (SELECT auth.uid())
    AND p.role = 'student'
    AND p.active IS TRUE
    AND p.photo_status = 'approved'
    AND p.photo_path = p_expected_photo_path
    AND p.photo_reviewed_at = p_expected_reviewed_at
    AND p.photo_approval_seen_reviewed_at
        IS DISTINCT FROM p.photo_reviewed_at;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  RETURN v_updated = 1;
END;
$function$;

REVOKE ALL ON FUNCTION
public.get_own_photo_approval_unseen()
FROM PUBLIC, anon;

REVOKE ALL ON FUNCTION
public.mark_own_photo_approval_seen(text, timestamptz)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
public.get_own_photo_approval_unseen()
TO authenticated;

GRANT EXECUTE ON FUNCTION
public.mark_own_photo_approval_seen(text, timestamptz)
TO authenticated;

COMMIT;
