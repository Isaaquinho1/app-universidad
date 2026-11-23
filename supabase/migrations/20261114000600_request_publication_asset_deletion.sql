-- Conecta ITT | Atomic individual asset deletion request.
-- Requires migration 20261114000500.
-- Physical Storage deletion is NOT performed here.

BEGIN;

CREATE OR REPLACE FUNCTION public.request_publication_asset_deletion(
  p_asset_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_publication_id uuid;
  v_asset public.publication_assets%ROWTYPE;
  v_queue_id uuid;
  v_deleted integer;
BEGIN
  IF p_asset_id IS NULL THEN
    RAISE EXCEPTION 'INVALID_ASSET_ID'
      USING ERRCODE = '22023';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.profiles AS profile
    WHERE profile.id = (SELECT auth.uid())
      AND profile.active IS TRUE
      AND profile.role IN ('admin', 'superAdmin')
      AND profile.staff_approval_pending IS FALSE
  ) THEN
    RAISE EXCEPTION 'ASSET_MANAGEMENT_NOT_AUTHORIZED'
      USING ERRCODE = '42501';
  END IF;

  SELECT asset.publication_id
  INTO v_publication_id
  FROM public.publication_assets AS asset
  WHERE asset.id = p_asset_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PUBLICATION_ASSET_NOT_FOUND'
      USING ERRCODE = 'P0002';
  END IF;

  -- Lock parent before asset metadata.
  PERFORM 1
  FROM public.announcements AS publication
  WHERE publication.id = v_publication_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PUBLICATION_NOT_FOUND'
      USING ERRCODE = 'P0002';
  END IF;

  SELECT *
  INTO v_asset
  FROM public.publication_assets AS asset
  WHERE asset.id = p_asset_id
  FOR UPDATE;

  IF NOT FOUND OR
     v_asset.publication_id IS DISTINCT FROM v_publication_id
  THEN
    RAISE EXCEPTION 'PUBLICATION_ASSET_CHANGED_RETRY'
      USING ERRCODE = '40001';
  END IF;

  IF v_asset.storage_bucket <> 'institutional-publications'
     OR public.publication_id_from_storage_path(
       v_asset.storage_path
     ) IS DISTINCT FROM v_publication_id
  THEN
    RAISE EXCEPTION 'PUBLICATION_ASSET_INVALID_OWNER'
      USING ERRCODE = '23514';
  END IF;

  -- Protect legacy attachment references.
  IF EXISTS (
    SELECT 1
    FROM public.announcements AS announcement
    CROSS JOIN LATERAL unnest(
      announcement.attachment_urls
    ) AS legacy(url)
    WHERE split_part(legacy.url, '?', 1)
       IN (
         v_asset.storage_path,
         v_asset.storage_bucket || '/' || v_asset.storage_path
       )
       OR right(
         split_part(legacy.url, '?', 1),
         length(
           '/storage/v1/object/public/' ||
           v_asset.storage_bucket || '/' || v_asset.storage_path
         )
       ) = '/storage/v1/object/public/' ||
           v_asset.storage_bucket || '/' || v_asset.storage_path
       OR right(
         split_part(legacy.url, '?', 1),
         length(
           '/storage/v1/object/sign/' ||
           v_asset.storage_bucket || '/' || v_asset.storage_path
         )
       ) = '/storage/v1/object/sign/' ||
           v_asset.storage_bucket || '/' || v_asset.storage_path
       OR right(
         split_part(legacy.url, '?', 1),
         length(
           '/storage/v1/object/authenticated/' ||
           v_asset.storage_bucket || '/' || v_asset.storage_path
         )
       ) = '/storage/v1/object/authenticated/' ||
           v_asset.storage_bucket || '/' || v_asset.storage_path
  ) THEN
    RAISE EXCEPTION 'ASSET_STILL_REFERENCED_BY_LEGACY_URL'
      USING ERRCODE = '23514';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.draft_publication_storage_cleanup AS queue
    WHERE queue.storage_bucket = v_asset.storage_bucket
      AND queue.storage_path = v_asset.storage_path
  ) THEN
    RAISE EXCEPTION 'ASSET_ALREADY_QUEUED_FOR_DRAFT_CLEANUP'
      USING ERRCODE = '23514';
  END IF;

  INSERT INTO public.publication_asset_storage_cleanup (
    publication_id,
    asset_id,
    operation,
    storage_bucket,
    storage_path
  )
  VALUES (
    v_asset.publication_id,
    v_asset.id,
    'delete_asset',
    v_asset.storage_bucket,
    v_asset.storage_path
  )
  RETURNING id INTO v_queue_id;

  DELETE FROM public.publication_assets
  WHERE id = p_asset_id
    AND publication_id = v_publication_id;

  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  IF v_deleted <> 1 THEN
    RAISE EXCEPTION 'ASSET_DELETION_NOT_CONFIRMED'
      USING ERRCODE = 'P0001';
  END IF;

  RETURN jsonb_build_object(
    'detached', true,
    'asset_id', p_asset_id,
    'publication_id', v_publication_id,
    'cleanup_id', v_queue_id,
    'storage_cleanup_complete', false
  );
END;
$function$;

REVOKE ALL ON FUNCTION
  public.request_publication_asset_deletion(uuid)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
  public.request_publication_asset_deletion(uuid)
TO authenticated;

COMMIT;
