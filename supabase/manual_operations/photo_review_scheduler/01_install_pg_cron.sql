-- CORRECCIÓN 13.7L
-- EJECUCIÓN MANUAL EXCLUSIVAMENTE.
-- No incluir este archivo en supabase/migrations.

CREATE EXTENSION IF NOT EXISTS pg_cron
WITH SCHEMA pg_catalog;

SELECT extname, extversion
FROM pg_extension
WHERE extname = 'pg_cron';
