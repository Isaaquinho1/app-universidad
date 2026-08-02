-- Conecta ITT
-- Fix PostgreSQL COALESCE usage in dynamic student ID QR validation.
-- COALESCE is SQL syntax and must not be schema-qualified.

-- Conecta ITT
-- Allow institutional profiles with administrative privileges to use
-- their student identification when their academic profile is complete.

begin;

create or replace function public.issue_student_id_qr_token()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid;
  current_profile public.profiles;

  v_now timestamptz;
  v_expires_at timestamptz;

  plain_token text;
  hashed_token bytea;
  inserted_token_id uuid;
begin
  current_user_id := (select auth.uid());

  if current_user_id is null then
    raise exception 'Authentication required'
      using errcode = 'insufficient_privilege';
  end if;

  select profile.*
  into current_profile
  from public.profiles as profile
  where profile.id = current_user_id
  for update;

  if current_profile.id is null then
    raise exception 'Institutional profile not found'
      using errcode = 'no_data_found';
  end if;

  if not current_profile.active then
    raise exception 'The institutional account is inactive'
      using errcode = 'insufficient_privilege';
  end if;

  if not current_profile.profile_completed then
    raise exception 'The institutional profile is incomplete'
      using errcode = 'check_violation';
  end if;

  if current_profile.control_number is null
     or pg_catalog.length(
       pg_catalog.btrim(current_profile.control_number)
     ) = 0 then
    raise exception 'A control number is required'
      using errcode = 'check_violation';
  end if;

  if current_profile.photo_status <> 'approved'
     or current_profile.photo_path is null
     or pg_catalog.length(
       pg_catalog.btrim(current_profile.photo_path)
     ) = 0 then
    raise exception 'An approved institutional photograph is required'
      using errcode = 'check_violation';
  end if;

  v_now := pg_catalog.timezone('utc', pg_catalog.now());
  v_expires_at := v_now + interval '60 seconds';

  update public.student_id_qr_tokens
  set
    revoked_at = v_now,
    revocation_reason = 'superseded'
  where student_id = current_user_id
    and revoked_at is null
    and expires_at > v_now;

  plain_token :=
    'itt1_' ||
    pg_catalog.encode(
      extensions.gen_random_bytes(32),
      'hex'
    );

  hashed_token :=
    extensions.digest(
      plain_token,
      'sha256'
    );

  insert into public.student_id_qr_tokens (
    student_id,
    token_hash,
    issued_at,
    expires_at
  )
  values (
    current_user_id,
    hashed_token,
    v_now,
    v_expires_at
  )
  returning id
  into inserted_token_id;

  return jsonb_build_object(
    'token_id', inserted_token_id,
    'token', plain_token,
    'issued_at', v_now,
    'expires_at', v_expires_at,
    'expires_in_seconds', 60
  );
end;
$$;

comment on function public.issue_student_id_qr_token() is
  'Issues a 60-second QR token for any eligible institutional profile, including profiles with administrative privileges.';

revoke all on function public.issue_student_id_qr_token()
from public;

grant execute on function public.issue_student_id_qr_token()
to authenticated;

-- Replace only the role-specific rejection in validation.
create or replace function public.validate_student_id_qr_token(
  p_token text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  validator_id uuid;
  v_now timestamptz;

  normalized_token text;
  requested_hash bytea;

  matched_token public.student_id_qr_tokens;
  matched_profile public.profiles;

  invalid_reason text;
begin
  validator_id := (select auth.uid());

  if validator_id is null then
    raise exception 'Authentication required'
      using errcode = 'insufficient_privilege';
  end if;

  if not public.is_admin() then
    raise exception 'Only administrators can validate student QR codes'
      using errcode = 'insufficient_privilege';
  end if;

  v_now := pg_catalog.timezone('utc', pg_catalog.now());

  normalized_token :=
    pg_catalog.lower(
      pg_catalog.btrim(
        coalesce(p_token, '')
      )
    );

  if normalized_token !~ '^itt1_[0-9a-f]{64}$' then
    insert into public.student_id_qr_validations (
      validated_by,
      validated_at,
      result,
      failure_reason
    )
    values (
      validator_id,
      v_now,
      'invalid',
      'invalid_format'
    );

    return jsonb_build_object(
      'valid', false,
      'reason', 'invalid_format',
      'validated_at', v_now
    );
  end if;

  requested_hash :=
    extensions.digest(
      normalized_token,
      'sha256'
    );

  select qr_token.*
  into matched_token
  from public.student_id_qr_tokens as qr_token
  where qr_token.token_hash = requested_hash
  limit 1;

  if matched_token.id is null then
    insert into public.student_id_qr_validations (
      validated_by,
      validated_at,
      result,
      failure_reason
    )
    values (
      validator_id,
      v_now,
      'invalid',
      'token_not_found'
    );

    return jsonb_build_object(
      'valid', false,
      'reason', 'token_not_found',
      'validated_at', v_now
    );
  end if;

  select profile.*
  into matched_profile
  from public.profiles as profile
  where profile.id = matched_token.student_id;

  if matched_token.revoked_at is not null then
    invalid_reason := 'token_revoked';
  elsif matched_token.expires_at <= v_now then
    invalid_reason := 'token_expired';
  elsif matched_profile.id is null then
    invalid_reason := 'profile_not_found';
  elsif not matched_profile.active then
    invalid_reason := 'inactive_profile';
  elsif not matched_profile.profile_completed then
    invalid_reason := 'incomplete_profile';
  elsif matched_profile.photo_status <> 'approved' then
    invalid_reason := 'photo_not_approved';
  elsif matched_profile.control_number is null
        or pg_catalog.length(
          pg_catalog.btrim(matched_profile.control_number)
        ) = 0 then
    invalid_reason := 'missing_control_number';
  else
    invalid_reason := null;
  end if;

  if invalid_reason is not null then
    insert into public.student_id_qr_validations (
      token_id,
      student_id,
      validated_by,
      validated_at,
      result,
      failure_reason
    )
    values (
      matched_token.id,
      matched_token.student_id,
      validator_id,
      v_now,
      'invalid',
      invalid_reason
    );

    return jsonb_build_object(
      'valid', false,
      'reason', invalid_reason,
      'student_id', matched_token.student_id,
      'issued_at', matched_token.issued_at,
      'expires_at', matched_token.expires_at,
      'validated_at', v_now
    );
  end if;

  insert into public.student_id_qr_validations (
    token_id,
    student_id,
    validated_by,
    validated_at,
    result
  )
  values (
    matched_token.id,
    matched_token.student_id,
    validator_id,
    v_now,
    'valid'
  );

  return jsonb_build_object(
    'valid', true,
    'reason', null,
    'student_id', matched_profile.id,
    'display_name', matched_profile.display_name,
    'control_number', matched_profile.control_number,
    'career_id', matched_profile.career_id,
    'semester', matched_profile.semester,
    'group_id', matched_profile.group_id,
    'photo_path', matched_profile.photo_path,
    'issued_at', matched_token.issued_at,
    'expires_at', matched_token.expires_at,
    'validated_at', v_now
  );
end;
$$;

comment on function public.validate_student_id_qr_token(text) is
  'Validates one institutional ID QR token and records the administrative attempt.';

revoke all on function public.validate_student_id_qr_token(text)
from public;

grant execute on function public.validate_student_id_qr_token(text)
to authenticated;

commit;
