begin;

create table if not exists public.announcement_notification_dispatches (
  id uuid primary key default gen_random_uuid(),

  announcement_id uuid not null
    references public.announcements(id)
    on update cascade
    on delete cascade,

  content_version integer not null,

  requested_by uuid not null
    references public.profiles(id)
    on update cascade
    on delete restrict,

  status text not null default 'processing',

  audience_count integer not null default 0,
  token_count integer not null default 0,
  sent_count integer not null default 0,
  failed_count integer not null default 0,
  no_token_count integer not null default 0,
  invalid_token_count integer not null default 0,

  error_message text,

  started_at timestamptz not null default timezone('utc', now()),
  completed_at timestamptz,

  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint announcement_notification_dispatches_version_positive
    check (content_version >= 1),

  constraint announcement_notification_dispatches_status_valid
    check (
      status in (
        'processing',
        'completed',
        'failed'
      )
    ),

  constraint announcement_notification_dispatches_counts_nonnegative
    check (
      audience_count >= 0
      and token_count >= 0
      and sent_count >= 0
      and failed_count >= 0
      and no_token_count >= 0
      and invalid_token_count >= 0
    ),

  constraint announcement_notification_dispatches_unique_version
    unique (announcement_id, content_version)
);

comment on table public.announcement_notification_dispatches is
  'Server-side execution log for FCM notifications sent for each announcement version.';

comment on column
  public.announcement_notification_dispatches.content_version is
  'Announcement content version associated with this notification dispatch.';

comment on column
  public.announcement_notification_dispatches.status is
  'Processing state of the server-side FCM dispatch.';

create index if not exists
  announcement_notification_dispatches_announcement_idx
on public.announcement_notification_dispatches(
  announcement_id,
  content_version desc
);

create index if not exists
  announcement_notification_dispatches_status_idx
on public.announcement_notification_dispatches(status);

drop trigger if exists
  announcement_notification_dispatches_set_updated_at
on public.announcement_notification_dispatches;

create trigger announcement_notification_dispatches_set_updated_at
before update on public.announcement_notification_dispatches
for each row
execute function public.set_updated_at();

alter table
  public.announcement_notification_dispatches
enable row level security;

revoke all
on table public.announcement_notification_dispatches
from anon;

revoke all
on table public.announcement_notification_dispatches
from authenticated;

commit;
