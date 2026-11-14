-- CORRECCIÓN 13.7L
-- ACTIVACIÓN MANUAL EXCLUSIVAMENTE.
--
-- Requisitos:
-- 1. pg_cron y pg_net instalados.
-- 2. URL HTTPS almacenada en Supabase Vault.
-- 3. Secreto del trabajador almacenado en Supabase Vault.
-- 4. PHOTO_REVIEW_WORKER_SECRET configurado en la Edge Function.
-- 5. Edge Function desplegada y comprobada.
--
-- Este script NO debe ejecutarse hasta recibir autorización.
-- Los valores reales de los secretos NO se guardan en cron.job.

BEGIN;

DO $setup$
DECLARE
  v_url text;
  v_secret text;
  v_url_count integer;
  v_secret_count integer;
  v_job_command text;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
  ) THEN
    RAISE EXCEPTION 'pg_cron no está instalado';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_net'
  ) THEN
    RAISE EXCEPTION 'pg_net no está instalado';
  END IF;

  SELECT count(*), max(decrypted_secret)
  INTO v_url_count, v_url
  FROM vault.decrypted_secrets
  WHERE name = 'conecta_itt_photo_review_worker_url';

  SELECT count(*), max(decrypted_secret)
  INTO v_secret_count, v_secret
  FROM vault.decrypted_secrets
  WHERE name = 'conecta_itt_photo_review_worker_secret';

  IF v_url_count <> 1 OR v_secret_count <> 1 THEN
    RAISE EXCEPTION
      'Faltan secretos de Vault o existen duplicados';
  END IF;

  IF v_url IS NULL
     OR v_url !~ '^https://[^/]+/functions/v1/send-profile-photo-review-notifications$'
  THEN
    RAISE EXCEPTION 'URL HTTPS del trabajador no válida';
  END IF;

  IF v_secret IS NULL OR length(v_secret) < 32 THEN
    RAISE EXCEPTION 'Secreto del trabajador no válido';
  END IF;

  IF EXISTS (
    SELECT 1 FROM cron.job
    WHERE jobname = 'conecta-itt-photo-review-worker'
  ) THEN
    RAISE EXCEPTION 'La tarea ya está registrada';
  END IF;

  -- Esta consulta se almacena como comando de cron.
  -- Consulta Vault durante cada ejecución.
  -- No contiene el valor literal del secreto.
  v_job_command := $job$
    SELECT net.http_post(
      url := (
        SELECT decrypted_secret
        FROM vault.decrypted_secrets
        WHERE name = 'conecta_itt_photo_review_worker_url'
      ),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-photo-review-worker-secret', (
          SELECT decrypted_secret
          FROM vault.decrypted_secrets
          WHERE name = 'conecta_itt_photo_review_worker_secret'
        )
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 10000
    );
  $job$;

  PERFORM cron.schedule(
    'conecta-itt-photo-review-worker',
    '* * * * *',
    v_job_command
  );

  RAISE NOTICE 'Programador registrado correctamente';
END;
$setup$;

COMMIT;
