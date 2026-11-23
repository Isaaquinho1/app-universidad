-- CONECTA ITT
-- Additional registration consent for the integral privacy notice.
-- The requirement activates only when an approved document is active.

begin;

create or replace function
  public.record_new_user_integral_notice_consent()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  active_document_id uuid;
  active_version text;
  accepted_version text;
  accepted boolean;
begin
  select document.id, document.version
    into active_document_id, active_version
  from public.legal_documents as document
  where document.document_type = 'integral_notice'
    and document.status = 'active';

  -- A draft does not activate the registration requirement.
  if active_document_id is null then
    return new;
  end if;

  accepted := coalesce(
    new.raw_user_meta_data ->> 'integralNoticeAccepted',
    'false'
  ) = 'true';

  accepted_version := nullif(
    trim(
      new.raw_user_meta_data ->> 'integralNoticeDocumentVersion'
    ),
    ''
  );

  if not accepted then
    raise exception 'Integral Privacy Notice must be accepted'
      using errcode = 'check_violation';
  end if;

  if accepted_version is distinct from active_version then
    raise exception 'Invalid Integral Privacy Notice version'
      using errcode = 'check_violation';
  end if;

  insert into public.user_legal_consents (
    user_id,
    document_id,
    accepted_at,
    source
  )
  values (
    new.id,
    active_document_id,
    timezone('utc', now()),
    'registration'
  )
  on conflict (user_id, document_id) do nothing;

  return new;
end;
$function$;

revoke all on function
  public.record_new_user_integral_notice_consent()
from public;

drop trigger if exists
  on_auth_user_created_integral_notice_consent
on auth.users;

create trigger on_auth_user_created_integral_notice_consent
after insert on auth.users
for each row
execute function
  public.record_new_user_integral_notice_consent();

commit;
