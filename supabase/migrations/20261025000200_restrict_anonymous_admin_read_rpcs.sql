-- Conecta ITT
-- Bloque 15.4O: restringir consultas administrativas anónimas.
-- Mantener los permisos de authenticated, postgres y service_role.
-- No afecta las RPC públicas del registro institucional.

begin;

revoke execute on function
  public.get_admin_announcements(text, integer)
from anon;

revoke execute on function
  public.get_announcement_notification_metrics(uuid)
from anon;

revoke execute on function
  public.get_announcement_reminder_recipients(uuid, text)
from anon;

revoke execute on function
  public.get_announcement_results(uuid)
from anon;

revoke execute on function
  public.get_profile_photo_review_queue(text)
from anon;

revoke execute on function
  public.review_profile_photo(uuid, text, text)
from anon;

revoke execute on function
  public.search_announcement_recipients(text, integer)
from anon;

revoke execute on function
  public.search_institutional_subjects_as_admin(text, boolean, integer)
from anon;

revoke execute on function
  public.search_role_management_profiles(text, integer)
from anon;

revoke execute on function
  public.search_student_academic_profiles_as_admin(text, integer)
from anon;

revoke execute on function
  public.search_teacher_assignments_as_admin(text, uuid, boolean, integer)
from anon;

revoke execute on function
  public.search_teachers_as_admin(text, integer)
from anon;

commit;
