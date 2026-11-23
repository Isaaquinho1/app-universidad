-- Conecta ITT | Require institutional approval for asset management.
-- Applies to both publication_assets RLS and Storage policies.
-- Do not require account_type = campusStaff: legitimate superAdmins
-- may have another account type.

BEGIN;

CREATE OR REPLACE FUNCTION public.can_manage_publication_assets(
  p_user_id uuid,
  p_publication_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT
    p_user_id IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM public.profiles AS profile
      WHERE profile.id = p_user_id
        AND profile.active IS TRUE
        AND profile.role IN ('admin', 'superAdmin')
        AND profile.staff_approval_pending IS FALSE
    )
    AND EXISTS (
      SELECT 1
      FROM public.announcements AS publication
      WHERE publication.id = p_publication_id
    );
$function$;

COMMIT;
