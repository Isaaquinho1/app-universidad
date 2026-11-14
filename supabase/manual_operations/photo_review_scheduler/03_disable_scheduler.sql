-- CORRECCIÓN 13.7L
-- Desactivación manual del programador.
-- No elimina secretos ni notificaciones pendientes.

SELECT cron.unschedule(jobid)
FROM cron.job
WHERE jobname = 'conecta-itt-photo-review-worker';
