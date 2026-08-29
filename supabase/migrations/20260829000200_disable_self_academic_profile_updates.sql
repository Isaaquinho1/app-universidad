-- ============================================================
-- Disable self-service academic profile changes
-- ============================================================
--
-- Academic identity is established during registration.
-- Subsequent career, semester and group changes require an
-- audited administrative flow.
-- ============================================================

revoke execute
on function public.update_own_profile(
  text,
  text,
  smallint,
  text,
  boolean
)
from authenticated;

comment on function public.update_own_profile(
  text,
  text,
  smallint,
  text,
  boolean
) is
  'Legacy self-profile update RPC. Execution is disabled. Academic identity changes require an audited administrative flow.';
