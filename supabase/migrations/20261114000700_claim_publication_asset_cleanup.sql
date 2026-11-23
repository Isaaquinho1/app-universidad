-- Conecta ITT | Claim and finish individual asset cleanup.
-- Requires migration 20261114000500.
-- Only service_role may invoke these RPCs.

BEGIN;

CREATE OR REPLACE FUNCTION public.claim_publication_asset_cleanup(
  p_limit integer DEFAULT 20
)
RETURNS TABLE (
  id uuid,
  publication_id uuid,
  storage_bucket text,
  storage_path text,
  attempts integer,
  claim_token uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF p_limit IS NULL OR p_limit < 1 OR p_limit > 20 THEN
    RAISE EXCEPTION 'INVALID_CLEANUP_LIMIT'
      USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  WITH candidates AS (
    SELECT queue.id
    FROM public.publication_asset_storage_cleanup AS queue
    WHERE (
      queue.status IN ('pending', 'failed')
      OR (
        queue.status = 'processing'
        AND queue.claimed_at < now() - interval '15 minutes'
      )
    )
    AND queue.storage_bucket = 'institutional-publications'
    AND public.publication_id_from_storage_path(
      queue.storage_path
    ) = queue.publication_id

    -- Never delete a currently registered object.
    AND NOT EXISTS (
      SELECT 1
      FROM public.publication_assets AS asset
      WHERE asset.storage_bucket = queue.storage_bucket
        AND asset.storage_path = queue.storage_path
    )

    -- Never overlap with draft deletion cleanup.
    AND NOT EXISTS (
      SELECT 1
      FROM public.draft_publication_storage_cleanup AS draft_queue
      WHERE draft_queue.storage_bucket = queue.storage_bucket
        AND draft_queue.storage_path = queue.storage_path
    )

    -- Fail closed if a legacy announcement references the object.
    AND NOT EXISTS (
      SELECT 1
      FROM public.announcements AS announcement
      CROSS JOIN LATERAL unnest(
        announcement.attachment_urls
      ) AS legacy(url)
      WHERE split_part(legacy.url, '?', 1) IN (
        queue.storage_path,
        queue.storage_bucket || '/' || queue.storage_path
      )
      OR right(
        split_part(legacy.url, '?', 1),
        length(
          '/storage/v1/object/public/' ||
          queue.storage_bucket || '/' || queue.storage_path
        )
      ) = '/storage/v1/object/public/' ||
          queue.storage_bucket || '/' || queue.storage_path
      OR right(
        split_part(legacy.url, '?', 1),
        length(
          '/storage/v1/object/sign/' ||
          queue.storage_bucket || '/' || queue.storage_path
        )
      ) = '/storage/v1/object/sign/' ||
          queue.storage_bucket || '/' || queue.storage_path
      OR right(
        split_part(legacy.url, '?', 1),
        length(
          '/storage/v1/object/authenticated/' ||
          queue.storage_bucket || '/' || queue.storage_path
        )
      ) = '/storage/v1/object/authenticated/' ||
          queue.storage_bucket || '/' || queue.storage_path
    )
    ORDER BY queue.created_at, queue.id
    FOR UPDATE OF queue SKIP LOCKED
    LIMIT p_limit
  )
  UPDATE public.publication_asset_storage_cleanup AS queue
  SET
    status = 'processing',
    attempts = queue.attempts + 1,
    claim_token = gen_random_uuid(),
    claimed_at = now(),
    last_error = NULL
  FROM candidates
  WHERE queue.id = candidates.id
  RETURNING
    queue.id,
    queue.publication_id,
    queue.storage_bucket,
    queue.storage_path,
    queue.attempts,
    queue.claim_token;
END;
$function$;

REVOKE ALL ON FUNCTION
  public.claim_publication_asset_cleanup(integer)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION
  public.claim_publication_asset_cleanup(integer)
TO service_role;

CREATE OR REPLACE FUNCTION public.finish_publication_asset_cleanup(
  p_id uuid,
  p_claim_token uuid,
  p_success boolean,
  p_error text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_affected integer;
BEGIN
  IF p_id IS NULL
     OR p_claim_token IS NULL
     OR p_success IS NULL THEN
    RAISE EXCEPTION 'INVALID_CLEANUP_COMPLETION'
      USING ERRCODE = '22023';
  END IF;

  UPDATE public.publication_asset_storage_cleanup AS queue
  SET
    status = CASE
      WHEN p_success THEN 'completed'
      ELSE 'failed'
    END,
    last_error = CASE
      WHEN p_success THEN NULL
      ELSE left(coalesce(p_error, 'Storage cleanup failed'), 1000)
    END,
    completed_at = CASE
      WHEN p_success THEN now()
      ELSE NULL
    END,
    claim_token = NULL,
    claimed_at = NULL
  WHERE queue.id = p_id
    AND queue.claim_token = p_claim_token
    AND queue.status = 'processing';

  GET DIAGNOSTICS v_affected = ROW_COUNT;

  RETURN v_affected = 1;
END;
$function$;

REVOKE ALL ON FUNCTION
  public.finish_publication_asset_cleanup(
    uuid, uuid, boolean, text
  )
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION
  public.finish_publication_asset_cleanup(
    uuid, uuid, boolean, text
  )
TO service_role;

COMMIT;
