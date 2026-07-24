-- Conecta ITT targets Android and iOS mobile devices only.
--
-- Preserve legacy token rows from unsupported platforms for audit purposes,
-- but deactivate them and clear their obsolete platform classification.

update public.user_fcm_tokens
set
  active = false,
  platform = null,
  updated_at = timezone('utc', now())
where platform is not null
  and platform not in ('android', 'ios');

alter table public.user_fcm_tokens
  drop constraint if exists user_fcm_tokens_platform_valid;

alter table public.user_fcm_tokens
  add constraint user_fcm_tokens_platform_valid
  check (
    platform is null
    or platform in ('android', 'ios')
  );

comment on column public.user_fcm_tokens.platform is
  'Mobile notification platform. Supported values: android and ios.';
