-- Conecta ITT
-- Private institutional photographs for digital student identification.
--
-- Storage path convention:
--   {authenticated_user_uuid}/{generated_file_name}
--
-- Photographs are never public. Access is granted through signed URLs.

begin;

-- ============================================================
-- Profile photograph metadata
-- ============================================================

alter table public.profiles
  add column if not exists photo_path text,
  add column if not exists photo_status text not null default 'missing',
  add column if not exists photo_updated_at timestamptz,
  add column if not exists photo_reviewed_at timestamptz,
  add column if not exists photo_reviewed_by uuid
    references public.profiles(id)
    on update cascade
    on delete set null,
  add column if not exists photo_rejection_reason text;

alter table public.profiles
  drop constraint if exists profiles_photo_status_valid;

alter table public.profiles
  add constraint profiles_photo_status_valid
  check (
    photo_status in (
      'missing',
      'pending',
      'approved',
      'rejected'
    )
  );

alter table public.profiles
  drop constraint if exists profiles_photo_path_consistent;

alter table public.profiles
  add constraint profiles_photo_path_consistent
  check (
    (
      photo_status = 'missing'
      and photo_path is null
    )
    or (
      photo_status in ('pending', 'approved', 'rejected')
      and photo_path is not null
      and length(trim(photo_path)) > 0
    )
  );

comment on column public.profiles.photo_path is
  'Private Storage path of the current institutional profile photograph.';

comment on column public.profiles.photo_status is
  'Review state of the profile photograph: missing, pending, approved or rejected.';

comment on column public.profiles.photo_updated_at is
  'UTC timestamp of the latest student photograph submission.';

comment on column public.profiles.photo_reviewed_at is
  'UTC timestamp of the latest administrative photograph review.';

comment on column public.profiles.photo_reviewed_by is
  'Administrator or super administrator who reviewed the photograph.';

comment on column public.profiles.photo_rejection_reason is
  'Reason shown to the student when a photograph is rejected.';

create index if not exists profiles_photo_status_idx
  on public.profiles(photo_status);

-- ============================================================
-- Private Storage bucket
-- ============================================================

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'student-profile-photos',
  'student-profile-photos',
  false,
  5242880,
  array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/heic',
    'image/heif'
  ]::text[]
)
on conflict (id) do update
set
  name = excluded.name,
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- ============================================================
-- Safe owner UUID parser
-- ============================================================

create or replace function public.profile_photo_owner_from_storage_path(
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

comment on function public.profile_photo_owner_from_storage_path(text) is
  'Returns the user UUID stored in the first segment of a profile-photo path.';

revoke all on function public.profile_photo_owner_from_storage_path(text)
from public;

grant execute on function public.profile_photo_owner_from_storage_path(text)
to authenticated;

-- ============================================================
-- Storage policies
-- ============================================================

drop policy if exists profile_photos_select_own
on storage.objects;

create policy profile_photos_select_own
on storage.objects
for select
to authenticated
using (
  bucket_id = 'student-profile-photos'
  and (
    public.profile_photo_owner_from_storage_path(name) =
      (select auth.uid())
    or (select public.is_admin())
  )
);

drop policy if exists profile_photos_insert_own
on storage.objects;

create policy profile_photos_insert_own
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'student-profile-photos'
  and public.profile_photo_owner_from_storage_path(name) =
    (select auth.uid())
);

drop policy if exists profile_photos_update_own
on storage.objects;

create policy profile_photos_update_own
on storage.objects
for update
to authenticated
using (
  bucket_id = 'student-profile-photos'
  and public.profile_photo_owner_from_storage_path(name) =
    (select auth.uid())
)
with check (
  bucket_id = 'student-profile-photos'
  and public.profile_photo_owner_from_storage_path(name) =
    (select auth.uid())
);

drop policy if exists profile_photos_delete_own
on storage.objects;

create policy profile_photos_delete_own
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'student-profile-photos'
  and public.profile_photo_owner_from_storage_path(name) =
    (select auth.uid())
);

-- ============================================================
-- Submit current user's photograph
-- ============================================================

create or replace function public.submit_own_profile_photo(
  p_photo_path text
)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_path text;
  updated_profile public.profiles;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required'
      using errcode = 'insufficient_privilege';
  end if;

  normalized_path := trim(coalesce(p_photo_path, ''));

  if normalized_path = '' then
    raise exception 'A profile photo path is required'
      using errcode = 'not_null_violation';
  end if;

  if public.profile_photo_owner_from_storage_path(normalized_path)
       <> (select auth.uid()) then
    raise exception 'The photograph path does not belong to the current user'
      using errcode = 'insufficient_privilege';
  end if;

  if not exists (
    select 1
    from storage.objects
    where bucket_id = 'student-profile-photos'
      and name = normalized_path
      and owner_id = (select auth.uid()::text)
  ) then
    raise exception 'The uploaded profile photograph was not found'
      using errcode = 'no_data_found';
  end if;

  update public.profiles
  set
    photo_path = normalized_path,
    photo_status = 'pending',
    photo_updated_at = timezone('utc', now()),
    photo_reviewed_at = null,
    photo_reviewed_by = null,
    photo_rejection_reason = null,
    updated_at = timezone('utc', now())
  where id = (select auth.uid())
    and active = true
  returning *
  into updated_profile;

  if updated_profile.id is null then
    raise exception 'Active profile not found'
      using errcode = 'no_data_found';
  end if;

  return updated_profile;
end;
$$;

revoke all on function public.submit_own_profile_photo(text)
from public;

grant execute on function public.submit_own_profile_photo(text)
to authenticated;

-- ============================================================
-- Remove current user's photograph
-- ============================================================

create or replace function public.remove_own_profile_photo()
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  updated_profile public.profiles;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required'
      using errcode = 'insufficient_privilege';
  end if;

  update public.profiles
  set
    photo_path = null,
    photo_status = 'missing',
    photo_updated_at = timezone('utc', now()),
    photo_reviewed_at = null,
    photo_reviewed_by = null,
    photo_rejection_reason = null,
    updated_at = timezone('utc', now())
  where id = (select auth.uid())
    and active = true
  returning *
  into updated_profile;

  if updated_profile.id is null then
    raise exception 'Active profile not found'
      using errcode = 'no_data_found';
  end if;

  return updated_profile;
end;
$$;

revoke all on function public.remove_own_profile_photo()
from public;

grant execute on function public.remove_own_profile_photo()
to authenticated;

commit;
