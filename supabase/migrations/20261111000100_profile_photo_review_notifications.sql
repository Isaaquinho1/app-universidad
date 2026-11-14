-- Conecta ITT
-- Durable notifications for institutional photograph reviews.

begin;

create table public.profile_photo_review_notifications (
  id uuid primary key default gen_random_uuid(),

  submission_id uuid not null unique
    references public.student_profile_photo_submissions(id)
    on delete restrict,

  student_id uuid not null
    references public.profiles(id)
    on delete restrict,

  decision text not null
    check (decision in ('approved', 'rejected')),

  status text not null default 'pending'
    check (
      status in (
        'pending',
        'processing',
        'sent',
        'failed'
      )
    ),

  attempt_count integer not null default 0
    check (attempt_count >= 0),

  claim_token uuid,
  claimed_at timestamptz,
  next_attempt_at timestamptz not null default now(),

  sent_at timestamptz,
  last_error text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index profile_photo_review_notifications_work_idx
on public.profile_photo_review_notifications (
  status,
  next_attempt_at
)
where status in ('pending', 'processing', 'failed');

create index profile_photo_review_notifications_student_idx
on public.profile_photo_review_notifications (
  student_id,
  created_at desc
);

alter table public.profile_photo_review_notifications
enable row level security;

revoke all on public.profile_photo_review_notifications
from public, anon, authenticated;

grant select, insert, update
on public.profile_photo_review_notifications
to service_role;

-- Register a notification in the same transaction as the
-- approved/rejected submission. Never send FCM from a trigger.

create or replace function
public.enqueue_profile_photo_review_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.status = 'pending'
     and new.status in ('approved', 'rejected')
     and old.status is distinct from new.status then

    insert into public.profile_photo_review_notifications (
      submission_id,
      student_id,
      decision
    )
    values (
      new.id,
      new.student_id,
      new.status
    )
    on conflict (submission_id) do nothing;

  end if;

  return new;
end;
$$;

revoke all
on function public.enqueue_profile_photo_review_notification()
from public, anon, authenticated;

create trigger enqueue_profile_photo_review_notification
after update of status
on public.student_profile_photo_submissions
for each row
when (
  old.status = 'pending'
  and new.status in ('approved', 'rejected')
)
execute function
public.enqueue_profile_photo_review_notification();

comment on table public.profile_photo_review_notifications is
  'Private durable notification queue for approved or rejected '
  'student photograph submissions. One event per submission.';

commit;
