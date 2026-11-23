-- Conecta ITT | Prevent direct deletion of tracked publication files.
-- Preserve compensating deletion of untracked uploads.
-- Requires 20261114000400 and 20261114000500.

BEGIN;

CREATE OR REPLACE FUNCTION
public.can_delete_untracked_publication_storage_object(
  p_user_id uuid,
  p_bucket text,
  p_path text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT
    p_bucket = 'institutional-publications'
    AND p_path IS NOT NULL
    AND public.can_manage_publication_assets(
      p_user_id,
      public.publication_id_from_storage_path(p_path)
    )
    AND NOT EXISTS (
      SELECT 1
      FROM public.publication_assets AS asset
      WHERE asset.storage_bucket = p_bucket
        AND asset.storage_path = p_path
    )
      -- Protect legacy references to untracked objects.
      AND NOT EXISTS (
        SELECT 1
        FROM public.announcements AS announcement
        CROSS JOIN LATERAL unnest(
          announcement.attachment_urls
        ) AS legacy(url)
        WHERE split_part(legacy.url, '?', 1) IN (
          p_path,
          p_bucket || '/' || p_path
        )
        OR right(
          split_part(legacy.url, '?', 1),
          length(
            '/storage/v1/object/public/' ||
            p_bucket || '/' || p_path
          )
        ) = '/storage/v1/object/public/' ||
            p_bucket || '/' || p_path
        OR right(
          split_part(legacy.url, '?', 1),
          length(
            '/storage/v1/object/sign/' ||
            p_bucket || '/' || p_path
          )
        ) = '/storage/v1/object/sign/' ||
            p_bucket || '/' || p_path
        OR right(
          split_part(legacy.url, '?', 1),
          length(
            '/storage/v1/object/authenticated/' ||
            p_bucket || '/' || p_path
          )
        ) = '/storage/v1/object/authenticated/' ||
            p_bucket || '/' || p_path
      )
    AND NOT EXISTS (
      SELECT 1
      FROM public.draft_publication_storage_cleanup AS queue
      WHERE queue.storage_bucket = p_bucket
        AND queue.storage_path = p_path
    )
    AND NOT EXISTS (
      SELECT 1
      FROM public.publication_asset_storage_cleanup AS queue
      WHERE queue.storage_bucket = p_bucket
        AND queue.storage_path = p_path
    );
$function$;

REVOKE ALL ON FUNCTION
public.can_delete_untracked_publication_storage_object(
  uuid, text, text
)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
public.can_delete_untracked_publication_storage_object(
  uuid, text, text
)
TO authenticated;

DROP POLICY IF EXISTS
publication_storage_delete_managers
ON storage.objects;

CREATE POLICY publication_storage_delete_managers
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'institutional-publications'
  AND public.can_delete_untracked_publication_storage_object(
    (SELECT auth.uid()),
    bucket_id,
    name
  )
);

COMMIT;
