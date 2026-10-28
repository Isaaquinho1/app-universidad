-- Conecta ITT
-- Bloque 15.4AF: restringir RPC auxiliares de perfil.
--
-- Revocar exclusivamente EXECUTE para anon.
-- Preservar permisos existentes de authenticated,
-- postgres y service_role.
-- No modificar implementaciones, datos ni politicas RLS.

begin;

revoke execute on function
  public.current_profile_role()
from anon;

revoke execute on function
  public.get_own_profile_photo_allowance()
from anon;

revoke execute on function
  public.update_own_profile(
    text,
    text,
    smallint,
    text,
    boolean
  )
from anon;

commit;
