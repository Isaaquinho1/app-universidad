-- Conecta ITT
-- Private Supabase Storage bucket for institutional publication media.
--
-- Object path convention:
--   {publication_uuid}/{generated_file_name}
--
-- Database metadata remains in public.publication_assets.

begin;

-- ============================================================
-- Private bucket
-- ============================================================

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'institutional-publications',
  'institutional-publications',
  false,
  26214400,
  array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
    'image/heic',
    'image/heif',

    'application/pdf',

    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',

    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',

    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',

    'text/plain',
    'text/csv'
  ]::text[]
)
on conflict (id) do update
set
  name = excluded.name,
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- ============================================================
-- Safe publication UUID parser
-- ============================================================

create or replace function public.publication_id_from_storage_path(
  p_object_name text
)
returns uuid
language plpgsql
immutable
set search_path = ''
as $$
declare
  first_segment text;
begin
  first_segment := split_part(
    trim(coalesce(p_object_name, '')),
    '/',
    1
  );

  if first_segment = '' then
    return null;
  end if;

  begin
    return first_segment::uuid;
  exception
    when invalid_text_representation then
      return null;
  end;
end;
$$;

comment on function public.publication_id_from_storage_path(text) is
  'Returns the publication UUID stored in the first segment of a '
  'publication Storage object path, or null when invalid.';

revoke all on function public.publication_id_from_storage_path(text)
from public;

grant execute on function public.publication_id_from_storage_path(text)
to authenticated;

-- ============================================================
-- Storage object policies
-- ============================================================

drop policy if exists publication_storage_select_visible
on storage.objects;

create policy publication_storage_select_visible
on storage.objects
for select
to authenticated
using (
  bucket_id = 'institutional-publications'
  and (
    public.is_admin()
    or exists (
      select 1
      from public.publication_assets as asset
      where asset.storage_bucket = bucket_id
        and asset.storage_path = name
        and public.announcement_is_visible_to_user(
          asset.publication_id,
          auth.uid()
        )
    )
  )
);

drop policy if exists publication_storage_insert_managers
on storage.objects;

create policy publication_storage_insert_managers
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'institutional-publications'
  and public.can_manage_publication_assets(
    auth.uid(),
    public.publication_id_from_storage_path(name)
  )
);

drop policy if exists publication_storage_update_managers
on storage.objects;

create policy publication_storage_update_managers
on storage.objects
for update
to authenticated
using (
  bucket_id = 'institutional-publications'
  and public.can_manage_publication_assets(
    auth.uid(),
    public.publication_id_from_storage_path(name)
  )
)
with check (
  bucket_id = 'institutional-publications'
  and public.can_manage_publication_assets(
    auth.uid(),
    public.publication_id_from_storage_path(name)
  )
);

drop policy if exists publication_storage_delete_managers
on storage.objects;

create policy publication_storage_delete_managers
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'institutional-publications'
  and public.can_manage_publication_assets(
    auth.uid(),
    public.publication_id_from_storage_path(name)
  )
);

commit;
