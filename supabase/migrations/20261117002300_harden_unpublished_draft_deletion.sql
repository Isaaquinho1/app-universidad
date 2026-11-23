-- Conecta ITT
-- Harden deletion of unpublished drafts.
-- Forward-only correction for the original historical migration.
-- Preserve the historical migration unchanged in Git.

begin;

create or replace function public.delete_unpublished_draft(
  p_publication_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_publication public.announcements;
  asset_count integer;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  if not public.is_admin() then
    raise exception 'Only administrators can delete drafts'
      using errcode = '42501';
  end if;

  -- Administrators awaiting institutional approval
  -- cannot perform destructive operations.
  if exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and staff_approval_pending = true
  ) then
    raise exception 'STAFF_APPROVAL_REQUIRED'
      using errcode = '42501';
  end if;

  if p_publication_id is null then
    raise exception 'Publication identifier is required'
      using errcode = '22023';
  end if;

  select *
    into current_publication
  from public.announcements
  where id = p_publication_id
  for update;

  if not found then
    raise exception 'Publication not found'
      using errcode = 'P0002';
  end if;

  if current_publication.status <> 'draft'
     or current_publication.published_at is not null then
    raise exception 'DRAFT_DELETION_NOT_ALLOWED'
      using errcode = 'P0001';
  end if;

  -- Protect institutional history, including prior publication.
  if exists (
    select 1 from public.announcement_receipts
    where announcement_id = p_publication_id
  ) or exists (
    select 1 from public.announcement_notification_dispatches
    where announcement_id = p_publication_id
  ) or exists (
    select 1 from public.announcement_reminder_dispatches
    where announcement_id = p_publication_id
  ) then
    raise exception 'DRAFT_HAS_INSTITUTIONAL_HISTORY'
      using errcode = 'P0001';
  end if;

  -- Never queue deletion of objects outside the managed bucket.
  if exists (
    select 1
    from public.publication_assets
    where publication_id = p_publication_id
      and storage_bucket <> 'institutional-publications'
  ) then
    raise exception 'DRAFT_HAS_UNSUPPORTED_STORAGE_ASSETS'
      using errcode = 'P0001';
  end if;

  -- Legacy attachments are not represented in publication_assets.
  -- Reject deletion until their storage references are migrated.
  if coalesce(
    array_length(current_publication.attachment_urls, 1),
    0
  ) > 0 then
    raise exception 'DRAFT_HAS_LEGACY_ATTACHMENTS'
      using errcode = 'P0001';
  end if;

  -- Refuse assets whose path belongs to another publication.
  if exists (
    select 1
    from public.publication_assets as asset
    where asset.publication_id = p_publication_id
      and public.publication_id_from_storage_path(
        asset.storage_path
      ) is distinct from p_publication_id
  ) then
    raise exception 'DRAFT_ASSET_PATH_OWNERSHIP_MISMATCH'
      using errcode = 'P0001';
  end if;

  -- Refuse known legacy references to the same Storage object
  -- from another announcement.
  if exists (
    select 1
    from public.publication_assets as asset
    join public.announcements as other_announcement
      on other_announcement.id <> p_publication_id
    cross join lateral unnest(
      other_announcement.attachment_urls
    ) as legacy(url)
    where asset.publication_id = p_publication_id
      and (
        split_part(legacy.url, '?', 1) = asset.storage_path
        or split_part(legacy.url, '?', 1) =
          asset.storage_bucket || '/' || asset.storage_path
        or split_part(legacy.url, '?', 1) =
          '/storage/v1/object/public/' ||
          asset.storage_bucket || '/' || asset.storage_path
        or split_part(legacy.url, '?', 1) =
          '/storage/v1/object/sign/' ||
          asset.storage_bucket || '/' || asset.storage_path
        or split_part(legacy.url, '?', 1) =
          '/storage/v1/object/authenticated/' ||
          asset.storage_bucket || '/' || asset.storage_path
        or right(
          split_part(legacy.url, '?', 1),
          length(
            '/storage/v1/object/public/' ||
            asset.storage_bucket || '/' || asset.storage_path
          )
        ) =
          '/storage/v1/object/public/' ||
          asset.storage_bucket || '/' || asset.storage_path
        or right(
          split_part(legacy.url, '?', 1),
          length(
            '/storage/v1/object/sign/' ||
            asset.storage_bucket || '/' || asset.storage_path
          )
        ) =
          '/storage/v1/object/sign/' ||
          asset.storage_bucket || '/' || asset.storage_path
        or right(
          split_part(legacy.url, '?', 1),
          length(
            '/storage/v1/object/authenticated/' ||
            asset.storage_bucket || '/' || asset.storage_path
          )
        ) =
          '/storage/v1/object/authenticated/' ||
          asset.storage_bucket || '/' || asset.storage_path
      )
  ) then
    raise exception 'DRAFT_ASSET_REFERENCED_BY_OTHER_PUBLICATION'
      using errcode = 'P0001';
  end if;

  select count(*)
    into asset_count
  from public.publication_assets
  where publication_id = p_publication_id;

  -- Preserve Storage paths before cascading metadata deletion.
  insert into public.draft_publication_storage_cleanup (
    publication_id,
    storage_bucket,
    storage_path
  )
  select
    publication_id,
    storage_bucket,
    storage_path
  from public.publication_assets
  where publication_id = p_publication_id;

  delete from public.announcements
  where id = p_publication_id
    and status = 'draft'
    and published_at is null;

  if not found then
    raise exception 'DRAFT_DELETION_NOT_CONFIRMED'
      using errcode = 'P0001';
  end if;

  return jsonb_build_object(
    'deleted', true,
    'publication_id', p_publication_id,
    'storage_cleanup_pending', asset_count
  );
end;
$$;

revoke all on function public.delete_unpublished_draft(uuid)
  from public, anon;

grant execute on function public.delete_unpublished_draft(uuid)
  to authenticated;

commit;
