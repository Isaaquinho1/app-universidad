begin;

create or replace function public.get_announcement_notification_metrics(
  p_announcement_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  announcement_record public.announcements;
  dispatch_record public.announcement_notification_dispatches;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required'
      using errcode = 'insufficient_privilege';
  end if;

  if not public.is_admin() then
    raise exception 'Only administrators can view notification metrics'
      using errcode = 'insufficient_privilege';
  end if;

  if p_announcement_id is null then
    raise exception 'Announcement identifier is required'
      using errcode = 'invalid_parameter_value';
  end if;

  select *
  into announcement_record
  from public.announcements
  where id = p_announcement_id;

  if not found then
    raise exception 'Announcement not found'
      using errcode = 'no_data_found';
  end if;

  select *
  into dispatch_record
  from public.announcement_notification_dispatches
  where announcement_id = p_announcement_id
    and content_version = announcement_record.content_version
  limit 1;

  if not found then
    return jsonb_build_object(
      'announcement_id', announcement_record.id,
      'content_version', announcement_record.content_version,
      'requested', false,
      'status', 'not_requested',
      'audience_count', 0,
      'token_count', 0,
      'sent_count', 0,
      'failed_count', 0,
      'no_token_count', 0,
      'invalid_token_count', 0,
      'error_message', null,
      'started_at', null,
      'completed_at', null,
      'created_at', null,
      'updated_at', null
    );
  end if;

  return jsonb_build_object(
    'dispatch_id', dispatch_record.id,
    'announcement_id', dispatch_record.announcement_id,
    'content_version', dispatch_record.content_version,
    'requested', true,
    'status', dispatch_record.status,
    'audience_count', dispatch_record.audience_count,
    'token_count', dispatch_record.token_count,
    'sent_count', dispatch_record.sent_count,
    'failed_count', dispatch_record.failed_count,
    'no_token_count', dispatch_record.no_token_count,
    'invalid_token_count', dispatch_record.invalid_token_count,
    'error_message', dispatch_record.error_message,
    'started_at', dispatch_record.started_at,
    'completed_at', dispatch_record.completed_at,
    'created_at', dispatch_record.created_at,
    'updated_at', dispatch_record.updated_at
  );
end;
$$;

revoke all
on function public.get_announcement_notification_metrics(uuid)
from public;

grant execute
on function public.get_announcement_notification_metrics(uuid)
to authenticated;

comment on function
  public.get_announcement_notification_metrics(uuid)
is
  'Returns server-side FCM dispatch metrics for the current content version of an announcement.';

commit;
