-- Conecta ITT
-- Versioned legal documents and auditable user consent records.

begin;

-- ============================================================
-- Legal documents
-- ============================================================

create table if not exists public.legal_documents (
  id uuid primary key default gen_random_uuid(),

  document_type text not null,
  version text not null,
  title text not null,
  content text not null,

  status text not null default 'draft',

  published_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint legal_documents_type_valid
    check (
      document_type in (
        'terms',
        'privacy'
      )
    ),

  constraint legal_documents_status_valid
    check (
      status in (
        'draft',
        'development',
        'active',
        'retired'
      )
    ),

  constraint legal_documents_version_not_blank
    check (length(trim(version)) > 0),

  constraint legal_documents_title_not_blank
    check (length(trim(title)) > 0),

  constraint legal_documents_content_not_blank
    check (length(trim(content)) > 0),

  constraint legal_documents_type_version_unique
    unique (document_type, version)
);

comment on table public.legal_documents is
  'Versioned Terms of Service and Privacy Policy documents.';

comment on column public.legal_documents.status is
  'Development documents are provisional and must be replaced before launch.';

drop trigger if exists legal_documents_set_updated_at
  on public.legal_documents;

create trigger legal_documents_set_updated_at
before update on public.legal_documents
for each row
execute function public.set_updated_at();

create unique index if not exists
  legal_documents_one_active_type_idx
on public.legal_documents(document_type)
where status = 'active';

create unique index if not exists
  legal_documents_one_development_type_idx
on public.legal_documents(document_type)
where status = 'development';

-- ============================================================
-- User consent evidence
-- ============================================================

create table if not exists public.user_legal_consents (
  user_id uuid not null references auth.users(id)
    on update cascade
    on delete cascade,

  document_id uuid not null references public.legal_documents(id)
    on update cascade
    on delete restrict,

  accepted_at timestamptz not null,
  recorded_at timestamptz not null default timezone('utc', now()),

  source text not null default 'registration',

  primary key (user_id, document_id),

  constraint user_legal_consents_source_valid
    check (
      source in (
        'registration',
        'profile_update',
        'document_update'
      )
    )
);

comment on table public.user_legal_consents is
  'Immutable evidence of the exact legal document version accepted by a user.';

create index if not exists user_legal_consents_user_idx
  on public.user_legal_consents(user_id);

create index if not exists user_legal_consents_document_idx
  on public.user_legal_consents(document_id);

-- Direct table access is not required by the mobile client.
alter table public.legal_documents enable row level security;
alter table public.user_legal_consents enable row level security;

revoke all on table public.legal_documents from anon, authenticated;
revoke all on table public.user_legal_consents from anon, authenticated;

-- ============================================================
-- Development documents
-- ============================================================

insert into public.legal_documents (
  document_type,
  version,
  title,
  content,
  status,
  published_at
)
values
  (
    'terms',
    'dev-2026-07-27',
    'Términos de Servicio — versión de desarrollo',
    'Documento provisional para pruebas internas de Conecta ITT. '
      'No constituye la versión institucional definitiva. '
      'Debe ser sustituido y aprobado antes del lanzamiento público.',
    'development',
    timezone('utc', now())
  ),
  (
    'privacy',
    'dev-2026-07-27',
    'Política de Privacidad — versión de desarrollo',
    'Documento provisional para pruebas internas de Conecta ITT. '
      'No constituye la versión institucional definitiva. '
      'Debe ser sustituido y aprobado antes del lanzamiento público.',
    'development',
    timezone('utc', now())
  )
on conflict (document_type, version) do update
set
  title = excluded.title,
  content = excluded.content,
  status = excluded.status,
  published_at = excluded.published_at,
  updated_at = timezone('utc', now());

-- ============================================================
-- Registration document catalog
-- ============================================================

create or replace function public.get_registration_legal_documents()
returns table (
  document_id uuid,
  document_type text,
  version text,
  title text,
  content text,
  status text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    document.id,
    document.document_type,
    document.version,
    document.title,
    document.content,
    document.status
  from public.legal_documents as document
  where document.status = 'active'

  union all

  select
    document.id,
    document.document_type,
    document.version,
    document.title,
    document.content,
    document.status
  from public.legal_documents as document
  where document.status = 'development'
    and not exists (
      select 1
      from public.legal_documents as active_document
      where active_document.document_type = document.document_type
        and active_document.status = 'active'
    )

  order by document_type;
$$;

revoke all on function public.get_registration_legal_documents()
  from public;

grant execute on function public.get_registration_legal_documents()
  to anon;

grant execute on function public.get_registration_legal_documents()
  to authenticated;

-- ============================================================
-- Consent registration from auth metadata
-- ============================================================

create or replace function public.record_new_user_legal_consents()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  terms_accepted boolean;
  privacy_accepted boolean;

  terms_version text;
  privacy_version text;

  accepted_at timestamptz;

  terms_document_id uuid;
  privacy_document_id uuid;
begin
  terms_accepted := coalesce(
    (new.raw_user_meta_data ->> 'termsAccepted')::boolean,
    false
  );

  privacy_accepted := coalesce(
    (new.raw_user_meta_data ->> 'privacyAccepted')::boolean,
    false
  );

  terms_version := nullif(
    trim(new.raw_user_meta_data ->> 'termsDocumentVersion'),
    ''
  );

  privacy_version := nullif(
    trim(new.raw_user_meta_data ->> 'privacyDocumentVersion'),
    ''
  );

  begin
    accepted_at := coalesce(
      nullif(
        trim(new.raw_user_meta_data ->> 'legalAcceptedAt'),
        ''
      )::timestamptz,
      timezone('utc', now())
    );
  exception
    when invalid_datetime_format then
      raise exception 'Invalid legal acceptance timestamp'
        using errcode = 'check_violation';
  end;

  if not terms_accepted or not privacy_accepted then
    raise exception 'Terms and Privacy Policy must be accepted'
      using errcode = 'check_violation';
  end if;

  if terms_version is null or privacy_version is null then
    raise exception 'Legal document versions are required'
      using errcode = 'check_violation';
  end if;

  select document.id
  into terms_document_id
  from public.legal_documents as document
  where document.document_type = 'terms'
    and document.version = terms_version
    and document.status in ('active', 'development');

  if terms_document_id is null then
    raise exception 'Invalid Terms of Service version'
      using errcode = 'foreign_key_violation';
  end if;

  select document.id
  into privacy_document_id
  from public.legal_documents as document
  where document.document_type = 'privacy'
    and document.version = privacy_version
    and document.status in ('active', 'development');

  if privacy_document_id is null then
    raise exception 'Invalid Privacy Policy version'
      using errcode = 'foreign_key_violation';
  end if;

  insert into public.user_legal_consents (
    user_id,
    document_id,
    accepted_at,
    source
  )
  values
    (
      new.id,
      terms_document_id,
      accepted_at,
      'registration'
    ),
    (
      new.id,
      privacy_document_id,
      accepted_at,
      'registration'
    )
  on conflict (user_id, document_id) do nothing;

  return new;
end;
$$;

comment on function public.record_new_user_legal_consents() is
  'Records immutable registration consent for the exact accepted legal versions.';

drop trigger if exists on_auth_user_created_legal_consents
  on auth.users;

create trigger on_auth_user_created_legal_consents
after insert on auth.users
for each row
execute function public.record_new_user_legal_consents();

commit;
