-- Conecta ITT
-- Bloque 15.4AK: restringir helpers de autorizacion.
--
-- Revocar exclusivamente EXECUTE para anon.
-- Conservar authenticated, postgres y service_role.
-- No modificar las implementaciones ni las politicas RLS.

begin;

revoke execute on function
  public.announcement_is_visible_to_user(uuid, uuid)
from anon;

revoke execute on function
  public.can_manage_publication_assets(uuid, uuid)
from anon;

revoke execute on function
  public.get_active_academic_period_id()
from anon;

revoke execute on function
  public.is_admin()
from anon;

revoke execute on function
  public.is_super_admin()
from anon;

revoke execute on function
  public.is_teacher()
from anon;

commit;
