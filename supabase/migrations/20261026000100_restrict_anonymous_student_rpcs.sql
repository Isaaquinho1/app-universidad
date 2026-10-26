-- Conecta ITT
-- Bloque 15.4R: restringir ejecución anónima de RPC institucionales.
--
-- Conservar permisos de authenticated, postgres y service_role.
-- Mantener intactas las RPC públicas necesarias para el registro.
-- No modifica funciones, tablas, datos ni políticas RLS.

begin;

revoke execute on function
  public.advance_announcement_receipt(uuid, text)
from anon;

revoke execute on function
  public.get_my_teacher_assignments()
from anon;

revoke execute on function
  public.get_visible_announcements(integer)
from anon;

revoke execute on function
  public.issue_student_id_qr_token()
from anon;

revoke execute on function
  public.register_current_user_fcm_token(text, text, text)
from anon;

revoke execute on function
  public.remove_own_profile_photo()
from anon;

revoke execute on function
  public.submit_own_profile_photo(text)
from anon;

revoke execute on function
  public.validate_student_id_qr_token(text)
from anon;

commit;
