-- Conecta ITT | Protect institutional announcement history.
-- Direct client-side DELETE is forbidden.
-- Safe deletion remains available through the authorized RPC.

REVOKE DELETE
ON TABLE public.announcements
FROM authenticated;

DROP POLICY IF EXISTS announcements_admin_delete
ON public.announcements;
