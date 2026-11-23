-- Conecta ITT | Prevent unsafe publication Storage references.
-- This migration must be applied after migrations 003 and 004.
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

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION
  public.guard_publication_asset_storage_reference()
FROM PUBLIC;

DROP TRIGGER IF EXISTS
  publication_assets_guard_storage_reference
ON public.publication_assets;

CREATE TRIGGER publication_assets_guard_storage_reference
BEFORE INSERT OR UPDATE OF
  publication_id, storage_bucket, storage_path
ON public.publication_assets
FOR EACH ROW
EXECUTE FUNCTION
  public.guard_publication_asset_storage_reference();

-- The current app uses publication_assets, not legacy URLs.
-- Existing legacy values remain readable and unchanged.
CREATE OR REPLACE FUNCTION
  public.guard_new_legacy_publication_attachments()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF cardinality(NEW.attachment_urls) > 0 THEN
      RAISE EXCEPTION 'NEW_LEGACY_ATTACHMENTS_NOT_ALLOWED'
        USING ERRCODE = '23514';
    END IF;
  ELSIF NEW.attachment_urls
        IS DISTINCT FROM OLD.attachment_urls
        AND cardinality(NEW.attachment_urls) > 0
  THEN
    RAISE EXCEPTION 'NEW_LEGACY_ATTACHMENTS_NOT_ALLOWED'
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION
  public.guard_new_legacy_publication_attachments()
FROM PUBLIC;

DROP TRIGGER IF EXISTS
  announcements_guard_new_legacy_attachments
ON public.announcements;

CREATE TRIGGER announcements_guard_new_legacy_attachments
BEFORE INSERT OR UPDATE OF attachment_urls
ON public.announcements
FOR EACH ROW
EXECUTE FUNCTION
  public.guard_new_legacy_publication_attachments();

COMMIT;
