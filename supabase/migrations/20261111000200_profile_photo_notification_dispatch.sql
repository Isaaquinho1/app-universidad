-- Conecta ITT
-- Internal worker operations for photograph review notifications.
-- Only the service_role may invoke these RPCs.

begin;

create function public.claim_profile_photo_review_notifications(
  p_limit integer default 10
)
returns setof public.profile_photo_review_notifications
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_limit is null or p_limit < 1 or p_limit > 50 then
    raise exception 'The claim limit must be between 1 and 50'
      using errcode = 'invalid_parameter_value';
  end if;

  return query
    with candidates as (
      select notification.id
      from public.profile_photo_review_notifications as notification
      where notification.attempt_count < 5
        and (
          (
            notification.status in ('pending', 'failed')
            and notification.next_attempt_at <= now()
          )
          or (
            notification.status = 'processing'
            and notification.claimed_at <= now() - interval '5 minutes'
          )
        )
      order by notification.created_at, notification.id
      limit p_limit
      for update of notification skip locked
    )
    update public.profile_photo_review_notifications as notification
    set
      status = 'processing',
      attempt_count = notification.attempt_count + 1,
      claim_token = gen_random_uuid(),
      claimed_at = now(),
      updated_at = now(),
      last_error = null
    from candidates
    where notification.id = candidates.id
    returning notification.*;
end;
$$;

create function public.complete_profile_photo_review_notification(
  p_id uuid,
  p_claim_token uuid,
  p_success boolean,
  p_error text default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  completed_id uuid;
begin
  if p_id is null
     or p_claim_token is null
     or p_success is null then
    raise exception 'Notification id, claim token and result are required'
      using errcode = 'not_null_violation';
  end if;

  update public.profile_photo_review_notifications as notification
  set
    status = case
      when p_success then 'sent'
      else 'failed'
    end,
    sent_at = case
      when p_success then now()
      else notification.sent_at
    end,
    last_error = case
      when p_success then null
      else coalesce(
        left(nullif(trim(p_error), ''), 500),
        'Notification delivery failed'
      )
    end,
    next_attempt_at = case
      when p_success then notification.next_attempt_at
      else now() + (
        least(
          3600,
          30 * (1 << least(notification.attempt_count, 7))
        ) * interval '1 second'
      )
    end,
    claim_token = null,
    claimed_at = null,
    updated_at = now()
  where notification.id = p_id
    and notification.status = 'processing'
    and notification.claim_token = p_claim_token
  returning notification.id
  into completed_id;

  return completed_id is not null;
end;
$$;

revoke all
on function public.claim_profile_photo_review_notifications(integer)
from public, anon, authenticated;

revoke all
on function public.complete_profile_photo_review_notification(
  uuid, uuid, boolean, text
)
from public, anon, authenticated;

grant execute
on function public.claim_profile_photo_review_notifications(integer)
to service_role;

grant execute
on function public.complete_profile_photo_review_notification(
  uuid, uuid, boolean, text
)
to service_role;

comment on function
public.claim_profile_photo_review_notifications(integer)
is 'Atomically leases due photo review notification tasks to an internal worker.';

comment on function
public.complete_profile_photo_review_notification(
  uuid, uuid, boolean, text
)
is 'Completes a claimed notification task using its current claim token.';

commit;
