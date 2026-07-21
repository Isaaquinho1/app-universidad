begin;

create or replace function public.get_announcement_reminder_recipients(
  p_announcement_id uuid,
  p_criterion text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  normalized_criterion text;
  announcement_results jsonb;
  result jsonb;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required'
      using errcode = 'insufficient_privilege';
  end if;

  if not public.is_admin() then
    raise exception
      'Only administrators can resolve reminder recipients'
      using errcode = 'insufficient_privilege';
  end if;

  if p_announcement_id is null then
    raise exception 'Announcement identifier is required'
      using errcode = 'invalid_parameter_value';
  end if;

  normalized_criterion := lower(trim(coalesce(p_criterion, '')));

  if normalized_criterion not in (
    'pending',
    'edited',
    'not_seen',
    'not_read',
    'not_confirmed'
  ) then
    raise exception
      'Invalid reminder criterion: %',
      coalesce(p_criterion, '')
      using errcode = 'invalid_parameter_value';
  end if;

  announcement_results :=
    public.get_announcement_results(p_announcement_id);

  if announcement_results ->> 'status' <> 'published' then
    raise exception
      'Only published announcements can send reminders'
      using errcode = 'object_not_in_prerequisite_state';
  end if;

  with recipients as (
    select recipient
    from jsonb_array_elements(
      coalesce(
        announcement_results -> 'recipients',
        '[]'::jsonb
      )
    ) as recipient
  ),
  eligible as (
    select recipient
    from recipients
    where
      case normalized_criterion
        when 'pending' then
          recipient ->> 'status' = 'pending'

        when 'edited' then
          recipient ->> 'status' = 'edited'

        when 'not_seen' then
          recipient ->> 'status' in (
            'pending',
            'edited',
            'delivered'
          )

        when 'not_read' then
          recipient ->> 'status' in (
            'pending',
            'edited',
            'delivered',
            'seen'
          )

        when 'not_confirmed' then
          recipient ->> 'status' <> 'confirmed'

        else false
      end
  )
  select jsonb_build_object(
    'announcement_id',
      announcement_results ->> 'announcement_id',

    'title',
      announcement_results ->> 'title',

    'content_version',
      coalesce(
        (announcement_results ->> 'content_version')::integer,
        1
      ),

    'criterion',
      normalized_criterion,

    'eligible_count',
      count(*)::integer,

    'recipients',
      coalesce(
        jsonb_agg(
          recipient
          order by
            recipient ->> 'control_number',
            recipient ->> 'display_name'
        ),
        '[]'::jsonb
      )
  )
  into result
  from eligible;

  return result;
end;
$$;

comment on function public.get_announcement_reminder_recipients(
  uuid,
  text
) is
  'Returns the current-version recipients eligible for an institutional announcement reminder.';

revoke all
on function public.get_announcement_reminder_recipients(uuid, text)
from public;

grant execute
on function public.get_announcement_reminder_recipients(uuid, text)
to authenticated;

commit;
