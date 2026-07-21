begin;

create table if not exists public.announcement_reminder_dispatches (
  id uuid primary key default gen_random_uuid(),

  announcement_id uuid not null
    references public.announcements(id)
    on update cascade
    on delete cascade,

  content_version integer not null,

  criterion text not null,

  request_key uuid not null,

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

  constraint announcement_reminder_dispatches_version_positive
    check (content_version >= 1),

  constraint announcement_reminder_dispatches_criterion_valid
    check (
      criterion in (
        'pending',
        'edited',
        'not_seen',
        'not_read',
        'not_confirmed'
      )
    ),

  constraint announcement_reminder_dispatches_status_valid
    check (
      status in (
        'processing',
        'completed',
        'failed'
      )
    ),

  constraint announcement_reminder_dispatches_counts_nonnegative
    check (
      audience_count >= 0
      and token_count >= 0
      and sent_count >= 0
      and failed_count >= 0
      and no_token_count >= 0
      and invalid_token_count >= 0
    ),

  constraint announcement_reminder_dispatches_request_key_unique
    unique (request_key)
);

comment on table public.announcement_reminder_dispatches is
  'Server-side audit log for segmented reminder notifications sent for institutional announcements.';

comment on column
  public.announcement_reminder_dispatches.criterion is
  'Recipient criterion used to resolve the reminder audience.';

comment on column
  public.announcement_reminder_dispatches.request_key is
  'Client-generated idempotency identifier preventing duplicate reminder submissions.';

create index if not exists
  announcement_reminder_dispatches_announcement_idx
on public.announcement_reminder_dispatches(
  announcement_id,
  content_version desc,
  started_at desc
);

create index if not exists
  announcement_reminder_dispatches_status_idx
on public.announcement_reminder_dispatches(status);

create index if not exists
  announcement_reminder_dispatches_requested_by_idx
on public.announcement_reminder_dispatches(requested_by);

drop trigger if exists
  announcement_reminder_dispatches_set_updated_at
on public.announcement_reminder_dispatches;

create trigger announcement_reminder_dispatches_set_updated_at
before update on public.announcement_reminder_dispatches
for each row
execute function public.set_updated_at();

alter table
  public.announcement_reminder_dispatches
enable row level security;

revoke all
on table public.announcement_reminder_dispatches
from anon;

revoke all
on table public.announcement_reminder_dispatches
from authenticated;

commit;
