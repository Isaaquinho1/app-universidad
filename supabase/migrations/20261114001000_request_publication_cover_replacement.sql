-- Conecta ITT | Atomic publication cover replacement.
-- The new object must already have been uploaded to Storage.
-- The old object is only queued; physical deletion is separate.

BEGIN;

CREATE OR REPLACE FUNCTION public.request_publication_cover_replacement(
  p_cover_id uuid,
  p_expected_old_path text,
  p_new_path text,
  p_original_name text,
  p_mime_type text,
  p_size_bytes bigint
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_publication_id uuid;
  v_cover public.publication_assets%ROWTYPE;
  v_cleanup_id uuid;
BEGIN
  IF p_cover_id IS NULL
     OR nullif(trim(p_expected_old_path), '') IS NULL
     OR nullif(trim(p_new_path), '') IS NULL
     OR nullif(trim(p_original_name), '') IS NULL
     OR p_mime_type NOT IN (
       'image/jpeg', 'image/png', 'image/webp',
       'image/gif', 'image/heic', 'image/heif'
     )
     OR p_size_bytes IS NULL
     OR p_size_bytes < 1
     OR p_size_bytes > 26214400
  THEN
    RAISE EXCEPTION 'INVALID_COVER_REPLACEMENT'
      USING ERRCODE = '22023';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.profiles AS p
    WHERE p.id = (SELECT auth.uid())
      AND p.active IS TRUE
      AND p.staff_approval_pending IS FALSE
      AND p.role IN ('admin', 'superAdmin')
  ) THEN
    RAISE EXCEPTION 'ASSET_MANAGEMENT_NOT_AUTHORIZED'
      USING ERRCODE = '42501';
  END IF;

  SELECT a.publication_id
  INTO v_publication_id
  FROM public.publication_assets AS a
  WHERE a.id = p_cover_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'COVER_NOT_FOUND'
      USING ERRCODE = 'P0002';
  END IF;

  PERFORM 1
  FROM public.announcements AS p
  WHERE p.id = v_publication_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PUBLICATION_NOT_FOUND'
      USING ERRCODE = 'P0002';
  END IF;

  SELECT *
  INTO v_cover
  FROM public.publication_assets AS a
  WHERE a.id = p_cover_id
  FOR UPDATE;

  IF NOT FOUND
     OR v_cover.publication_id IS DISTINCT FROM v_publication_id
     OR v_cover.asset_type <> 'cover'
     OR v_cover.storage_path IS DISTINCT FROM p_expected_old_path
  THEN
    RAISE EXCEPTION 'COVER_CHANGED_RETRY'
      USING ERRCODE = '40001';
  END IF;

  IF v_cover.storage_bucket <> 'institutional-publications'
     OR public.publication_id_from_storage_path(
       v_cover.storage_path
     ) IS DISTINCT FROM v_publication_id
     OR public.publication_id_from_storage_path(
       p_new_path
     ) IS DISTINCT FROM v_publication_id
     OR p_new_path NOT LIKE v_publication_id::text || '/cover/%'
     OR p_new_path = v_cover.storage_path
  THEN
    RAISE EXCEPTION 'INVALID_COVER_STORAGE_PATH'
      USING ERRCODE = '23514';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.publication_assets AS a
    WHERE a.storage_bucket = v_cover.storage_bucket
      AND a.storage_path = p_new_path
  ) OR EXISTS (
    SELECT 1
    FROM public.publication_asset_storage_cleanup AS q
    WHERE q.storage_bucket = v_cover.storage_bucket
      AND q.storage_path = p_new_path
  ) OR EXISTS (
    SELECT 1
    FROM public.draft_publication_storage_cleanup AS q
    WHERE q.storage_bucket = v_cover.storage_bucket
      AND q.storage_path = p_new_path
  ) THEN
    RAISE EXCEPTION 'NEW_COVER_PATH_ALREADY_RESERVED'
      USING ERRCODE = '23514';
  END IF;

    -- Verify that the new cover exists in Storage.
    -- Reject missing, archived or deleted objects.
    IF NOT EXISTS (
      SELECT 1
      FROM storage.objects AS object
      WHERE object.bucket_id = 'institutional-publications'
        AND object.name = p_new_path
        AND object.is_delete_marker IS FALSE
        AND object.archived_at IS NULL
        AND object.metadata ->> 'mimetype' = p_mime_type
        AND object.metadata ->> 'size' = p_size_bytes::text
    ) THEN
      RAISE EXCEPTION 'NEW_COVER_STORAGE_OBJECT_NOT_VALID'
        USING ERRCODE = '23514';
    END IF;

  -- Do not queue the old cover if another active metadata
  -- reference exists or a legacy announcement still uses it.
  IF EXISTS (
    SELECT 1
    FROM public.announcements AS a
    CROSS JOIN LATERAL unnest(a.attachment_urls) AS legacy(url)
    WHERE split_part(legacy.url, '?', 1) IN (
      v_cover.storage_path,
      v_cover.storage_bucket || '/' || v_cover.storage_path
    )
    OR right(
      split_part(legacy.url, '?', 1),
      length('/' || v_cover.storage_bucket || '/' || v_cover.storage_path)
    ) = '/' || v_cover.storage_bucket || '/' || v_cover.storage_path
  ) THEN
    RAISE EXCEPTION 'OLD_COVER_HAS_LEGACY_REFERENCE'
      USING ERRCODE = '23514';
  END IF;

  INSERT INTO public.publication_asset_storage_cleanup (
    publication_id,
    asset_id,
    operation,
    storage_bucket,
    storage_path
  ) VALUES (
    v_publication_id,
    v_cover.id,
    'replace_cover',
    v_cover.storage_bucket,
    v_cover.storage_path
  )
  RETURNING id INTO v_cleanup_id;

  UPDATE public.publication_assets
  SET
    storage_path = p_new_path,
    original_name = trim(p_original_name),
    mime_type = p_mime_type,
    size_bytes = p_size_bytes,
    display_order = 0,
    uploaded_by = (SELECT auth.uid())
  WHERE id = p_cover_id
    AND publication_id = v_publication_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'COVER_UPDATE_NOT_CONFIRMED'
      USING ERRCODE = 'P0001';
  END IF;

  RETURN jsonb_build_object(
    'replaced', true,
    'cover_id', p_cover_id,
    'publication_id', v_publication_id,
    'cleanup_id', v_cleanup_id,
    'storage_cleanup_complete', false
  );
END;
$function$;

REVOKE ALL ON FUNCTION
public.request_publication_cover_replacement(
  uuid, text, text, text, text, bigint
)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
public.request_publication_cover_replacement(
  uuid, text, text, text, text, bigint
)
TO authenticated;

COMMIT;
