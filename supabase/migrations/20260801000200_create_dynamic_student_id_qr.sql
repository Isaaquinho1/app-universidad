-- Conecta ITT
-- Dynamic, short-lived and server-validated student identification QR codes.
--
-- Security principles:
--   * The QR contains only an opaque random token.
--   * The database stores only SHA-256 hashes.
--   * Tokens expire after 60 seconds.
--   * Issuing a token revokes previous active tokens for the student.
--   * Validation is restricted to authenticated admin and superAdmin users.
--   * Validation attempts are audited without storing the scanned token.

begin;

-- ============================================================
-- Short-lived QR tokens
-- ============================================================

create table if not exists public.student_id_qr_tokens (
  id uuid primary key default extensions.gen_random_uuid(),

  student_id uuid not null
    references public.profiles(id)
    on update cascade
    on delete cascade,

  token_hash bytea not null,

  issued_at timestamptz not null,
  expires_at timestamptz not null,

  revoked_at timestamptz,
  revocation_reason text,

  created_at timestamptz not null
    default pg_catalog.timezone('utc', pg_catalog.now()),

  constraint student_id_qr_tokens_hash_unique
    unique (token_hash),

  constraint student_id_qr_tokens_expiration_valid
    check (expires_at > issued_at),

  constraint student_id_qr_tokens_revocation_consistent
    check (
      (
        revoked_at is null
        and revocation_reason is null
      )
      or (
        revoked_at is not null
        and revocation_reason is not null
        and pg_catalog.length(
          pg_catalog.btrim(revocation_reason)
        ) > 0
      )
    )
);

comment on table public.student_id_qr_tokens is
  'Hashed, short-lived tokens used by dynamic institutional student ID QR codes.';

comment on column public.student_id_qr_tokens.token_hash is
  'SHA-256 hash of the opaque token. The original token is never persisted.';

comment on column public.student_id_qr_tokens.expires_at is
  'UTC expiration timestamp. Dynamic QR tokens currently last 60 seconds.';

create index if not exists student_id_qr_tokens_student_idx
  on public.student_id_qr_tokens(student_id);

create index if not exists student_id_qr_tokens_active_idx
  on public.student_id_qr_tokens(student_id, expires_at)
  where revoked_at is null;

create index if not exists student_id_qr_tokens_expiration_idx
  on public.student_id_qr_tokens(expires_at);

-- ============================================================
-- Validation audit log
-- ============================================================

create table if not exists public.student_id_qr_validations (
  id uuid primary key default extensions.gen_random_uuid(),

  token_id uuid
    references public.student_id_qr_tokens(id)
    on update cascade
    on delete set null,

  student_id uuid
    references public.profiles(id)
    on update cascade
    on delete set null,

  validated_by uuid not null
    references public.profiles(id)
    on update cascade
    on delete restrict,

  validated_at timestamptz not null
    default pg_catalog.timezone('utc', pg_catalog.now()),

  result text not null,
  failure_reason text,

  constraint student_id_qr_validations_result_valid
    check (result in ('valid', 'invalid')),

  constraint student_id_qr_validations_failure_consistent
    check (
      (
        result = 'valid'
        and failure_reason is null
      )
      or (
        result = 'invalid'
        and failure_reason is not null
        and pg_catalog.length(
          pg_catalog.btrim(failure_reason)
        ) > 0
      )
    )
);

comment on table public.student_id_qr_validations is
  'Administrative audit trail for institutional student QR validation attempts.';

comment on column public.student_id_qr_validations.failure_reason is
  'Machine-readable reason for an invalid QR validation attempt.';

create index if not exists student_id_qr_validations_student_idx
  on public.student_id_qr_validations(student_id, validated_at desc);

create index if not exists student_id_qr_validations_validator_idx
  on public.student_id_qr_validations(validated_by, validated_at desc);

-- ============================================================
-- Issue a new dynamic token for the authenticated student
-- ============================================================

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

  if current_profile.role <> 'student' then
    raise exception 'Only student accounts can issue identification QR codes'
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

  v_now :=
    pg_catalog.timezone('utc', pg_catalog.now());

  v_expires_at :=
    v_now + interval '60 seconds';

  -- Only the latest issued token remains active.
  update public.student_id_qr_tokens
  set
    revoked_at = v_now,
    revocation_reason = 'superseded'
  where student_id = current_user_id
    and revoked_at is null
    and expires_at > v_now;

  -- 256 bits of cryptographic randomness.
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
  'Issues a 60-second opaque dynamic QR token for the authenticated eligible student.';

revoke all on function public.issue_student_id_qr_token()
from public;

grant execute on function public.issue_student_id_qr_token()
to authenticated;

-- ============================================================
-- Validate a dynamic QR token
-- ============================================================

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

  v_now :=
    pg_catalog.timezone('utc', pg_catalog.now());

  normalized_token :=
    pg_catalog.lower(
      pg_catalog.btrim(
        pg_catalog.coalesce(p_token, '')
      )
    );

  -- Expected format: itt1_ plus 64 lowercase hexadecimal characters.
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
  elsif matched_profile.role <> 'student' then
    invalid_reason := 'invalid_account_type';
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
  'Validates one opaque student ID QR token and records the administrative attempt.';

revoke all on function public.validate_student_id_qr_token(text)
from public;

grant execute on function public.validate_student_id_qr_token(text)
to authenticated;

-- ============================================================
-- Row Level Security and direct API privileges
-- ============================================================

alter table public.student_id_qr_tokens
  enable row level security;

alter table public.student_id_qr_validations
  enable row level security;

-- No direct table policies are intentionally created.
-- Access is available only through the protected RPC functions.

revoke all on table public.student_id_qr_tokens
from anon, authenticated;

revoke all on table public.student_id_qr_validations
from anon, authenticated;

commit;
