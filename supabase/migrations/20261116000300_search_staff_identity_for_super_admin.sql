-- Conecta ITT | SuperAdmin staff identity search.
-- Declared department and position are not verified credentials.
-- Keep the original role-management RPC unchanged.

BEGIN;

CREATE OR REPLACE FUNCTION public.search_role_management_profiles_with_staff_identity(
  p_query text DEFAULT NULL,
  p_limit integer DEFAULT 50
)
RETURNS TABLE (
  id uuid,
  email text,
  display_name text,
  role text,
  account_type text,
  staff_approval_pending boolean,
  active boolean,
  control_number text,
  created_at timestamptz,
  staff_department_declared text,
  staff_position_declared text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_query text;
  v_limit integer;
BEGIN
  IF (SELECT auth.uid()) IS NULL THEN
    RAISE EXCEPTION 'Authentication required'
      USING errcode = '42501';
  END IF;

  IF NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'SuperAdmin privileges required'
      USING errcode = '42501';
  END IF;

  v_query := nullif(btrim(coalesce(p_query, '')), '');
  v_limit := greatest(1, least(coalesce(p_limit, 50), 100));

  RETURN QUERY
  SELECT
    p.id,
    p.email,
    p.display_name,
    p.role,
    p.account_type,
    p.staff_approval_pending,
    p.active,
    p.control_number,
    p.created_at,
    p.staff_department_declared,
    p.staff_position_declared
  FROM public.profiles AS p
  WHERE
    v_query IS NULL
    OR p.email ILIKE '%' || v_query || '%'
    OR p.display_name ILIKE '%' || v_query || '%'
    OR p.control_number ILIKE '%' || v_query || '%'
    OR (
      p.account_type IN ('campusStaff', 'tecnmStaff')
      AND (
        p.staff_department_declared ILIKE '%' || v_query || '%'
        OR p.staff_position_declared ILIKE '%' || v_query || '%'
      )
    )
  ORDER BY
    CASE p.role
      WHEN 'superAdmin' THEN 0
      WHEN 'admin' THEN 1
      WHEN 'teacher' THEN 2
      ELSE 3
    END,
    p.display_name NULLS LAST,
    p.email NULLS LAST
  LIMIT v_limit;
END;
$function$;

REVOKE ALL
ON FUNCTION
public.search_role_management_profiles_with_staff_identity(text, integer)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION
public.search_role_management_profiles_with_staff_identity(text, integer)
TO authenticated;

COMMENT ON FUNCTION
public.search_role_management_profiles_with_staff_identity(text, integer)
IS 'SuperAdmin-only profile search with unverified staff identity fields.';

COMMIT;
