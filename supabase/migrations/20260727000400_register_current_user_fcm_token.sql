-- Conecta ITT
-- Safely assigns one FCM installation token to the currently authenticated user.
--
-- A token belongs to the app installation/device, not permanently to a user.
-- When another account signs in on the same device, the token is transferred
-- to the active account while preserving global token uniqueness.

begin;

create or replace function public.register_current_user_fcm_token(
  p_device_id text,
  p_token text,
  p_platform text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid;
  normalized_device_id text;
  normalized_token text;
  normalized_platform text;
begin
  current_user_id := auth.uid();

  if current_user_id is null then
    raise exception 'Authentication is required'
      using errcode = 'insufficient_privilege';
  end if;

  normalized_device_id := nullif(trim(p_device_id), '');
  normalized_token := nullif(trim(p_token), '');
  normalized_platform := lower(trim(coalesce(p_platform, '')));

  if normalized_device_id is null then
    raise exception 'Device ID cannot be empty'
      using errcode = 'check_violation';
  end if;

  if normalized_token is null then
    raise exception 'FCM token cannot be empty'
      using errcode = 'check_violation';
  end if;

  if normalized_platform not in ('android', 'ios') then
    raise exception 'Unsupported notification platform'
      using errcode = 'check_violation';
  end if;

  if not exists (
    select 1
    from public.profiles
    where id = current_user_id
      and active = true
  ) then
    raise exception 'An active institutional profile is required'
      using errcode = 'foreign_key_violation';
  end if;

  -- Remove an obsolete token previously associated with this same
  -- user/device pair. This prevents the user_device unique constraint
  -- from conflicting when Firebase rotates the installation token.
  delete from public.user_fcm_tokens
  where user_id = current_user_id
    and device_id = normalized_device_id
    and token <> normalized_token;

  -- Insert the installation token or transfer it from the former account
  -- to the user who currently owns the authenticated session.
  insert into public.user_fcm_tokens (
    user_id,
    device_id,
    token,
    platform,
    active,
    last_seen_at
  )
  values (
    current_user_id,
    normalized_device_id,
    normalized_token,
    normalized_platform,
    true,
    timezone('utc', now())
  )
  on conflict (token) do update
  set
    user_id = excluded.user_id,
    device_id = excluded.device_id,
    platform = excluded.platform,
    active = true,
    last_seen_at = timezone('utc', now()),
    updated_at = timezone('utc', now());
end;
$$;

comment on function public.register_current_user_fcm_token(
  text,
  text,
  text
) is
  'Registers or transfers an Android/iOS FCM installation token to the '
  'currently authenticated user.';

revoke all on function public.register_current_user_fcm_token(
  text,
  text,
  text
) from public;

grant execute on function public.register_current_user_fcm_token(
  text,
  text,
  text
) to authenticated;

commit;
