-- Conecta ITT
-- Block 15.4: Restrict anonymous execution of administrative RPCs.
--
-- These privileges were revoked manually in production on 2026-10-25.
-- This migration records the same change for reproducible deployments.
--
-- Keep authenticated and service_role permissions unchanged.
-- Do not revoke anonymous access to registration catalog RPCs.

begin;

revoke execute on function
  public.create_announcement_with_targets(jsonb, jsonb)
from anon;

revoke execute on function
  public.create_teacher_assignment_as_admin(uuid, uuid, text, uuid)
from anon;

revoke execute on function
  public.get_announcement_recipients_by_ids(jsonb)
from anon;

revoke execute on function
  public.update_announcement_with_targets(uuid, jsonb, jsonb)
from anon;

revoke execute on function
  public.update_profile_role_as_super_admin(uuid, text)
from anon;

revoke execute on function
  public.update_student_academic_profile_as_admin(uuid, text, smallint, text)
from anon;

commit;
