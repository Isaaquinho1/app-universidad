-- Conecta ITT | Protect assets referenced by either cleanup queue.
-- Requires migrations 00300 and 00500 from 20261114.
BEGIN;

CREATE OR REPLACE FUNCTION
  public.guard_publication_asset_storage_reference()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  -- Serialize asset writes with deletion of their parent publication.
  -- The deletion RPC locks announcements using FOR UPDATE.
  PERFORM 1
  FROM public.announcements
  WHERE id = NEW.publication_id
  FOR KEY SHARE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PUBLICATION_ASSET_OWNER_NOT_FOUND'
      USING ERRCODE = '23503';
  END IF;

  -- Every managed asset belongs to its publication UUID.
  IF NEW.storage_bucket <> 'institutional-publications'
     OR public.publication_id_from_storage_path(
       NEW.storage_path
     ) IS DISTINCT FROM NEW.publication_id
  THEN
    RAISE EXCEPTION 'PUBLICATION_ASSET_INVALID_OWNER'
      USING ERRCODE = '23514';
  END IF;

  -- Never reuse an object already scheduled for deletion.
  IF EXISTS (
    SELECT 1
    FROM public.draft_publication_storage_cleanup AS queue
    WHERE queue.storage_bucket = NEW.storage_bucket
      AND queue.storage_path = NEW.storage_path
  ) THEN
    RAISE EXCEPTION 'PUBLICATION_ASSET_QUEUED_FOR_DELETION'
      USING ERRCODE = '23514';
  END IF;

  -- Prevent re-registering assets detached for individual cleanup.
  IF EXISTS (
    SELECT 1
    FROM public.publication_asset_storage_cleanup AS queue
    WHERE queue.storage_bucket = NEW.storage_bucket
      AND queue.storage_path = NEW.storage_path
  ) THEN
    RAISE EXCEPTION
      'PUBLICATION_ASSET_QUEUED_FOR_INDIVIDUAL_CLEANUP'
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$function$;

COMMIT;
