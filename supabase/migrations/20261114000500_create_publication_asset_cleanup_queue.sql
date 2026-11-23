-- Conecta ITT | Recoverable cleanup for individual publication assets.
-- Separate from deletion of complete unpublished drafts.
BEGIN;

CREATE TABLE public.publication_asset_storage_cleanup (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  publication_id uuid NOT NULL,
  asset_id uuid,
  operation text NOT NULL,
  storage_bucket text NOT NULL,
  storage_path text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  attempts integer NOT NULL DEFAULT 0,
  claim_token uuid,
  claimed_at timestamptz,
  last_error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,

  CONSTRAINT asset_cleanup_operation_check
    CHECK (operation IN ('delete_asset', 'replace_cover')),

  CONSTRAINT asset_cleanup_status_check
    CHECK (
      status IN ('pending', 'processing', 'failed', 'completed')
    ),

  CONSTRAINT asset_cleanup_attempts_check
    CHECK (attempts >= 0),

  CONSTRAINT asset_cleanup_bucket_check
    CHECK (storage_bucket = 'institutional-publications'),

  CONSTRAINT asset_cleanup_path_check
    CHECK (
      (public.publication_id_from_storage_path(storage_path)
      = publication_id) IS TRUE
    ),

  CONSTRAINT asset_cleanup_object_unique
    UNIQUE (storage_bucket, storage_path)
);

CREATE INDEX publication_asset_cleanup_pending_idx
ON public.publication_asset_storage_cleanup (
  status, created_at
)
WHERE status <> 'completed';

ALTER TABLE public.publication_asset_storage_cleanup
ENABLE ROW LEVEL SECURITY;

-- Internal work queue: no direct access from mobile clients.
REVOKE ALL
ON TABLE public.publication_asset_storage_cleanup
FROM PUBLIC, anon, authenticated;

COMMENT ON TABLE public.publication_asset_storage_cleanup IS
  'Internal recovery queue for detached publication assets; '
  'not for deleting complete publications.';

COMMIT;
