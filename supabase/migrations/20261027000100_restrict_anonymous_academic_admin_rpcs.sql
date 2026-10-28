-- Conecta ITT
-- Bloque 15.4W: restringir RPC administrativas academicas.
--
-- Revocar exclusivamente EXECUTE para anon.
-- Conservar los permisos de authenticated, postgres y service_role.
-- No modificar funciones, tablas, datos ni politicas RLS.
-- Preservar las RPC publicas del registro institucional.

begin;

revoke execute on function
  public.create_institutional_subject_as_admin(text, text)
from anon;

revoke execute on function
  public.create_teacher_assignment_session_as_admin(
    uuid,
    smallint,
    time without time zone,
    time without time zone,
    text,
    text
  )
from anon;

revoke execute on function
  public.delete_teacher_assignment_session_as_admin(uuid)
from anon;

revoke execute on function
  public.set_institutional_subject_active_as_admin(uuid, boolean)
from anon;

revoke execute on function
  public.set_teacher_assignment_active_as_admin(uuid, boolean)
from anon;

commit;
