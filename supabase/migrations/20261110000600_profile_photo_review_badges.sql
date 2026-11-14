-- Conecta ITT
-- Individual administrative notification counters
-- for pending student photograph reviews.

begin;

create table public.profile_photo_review_views (
  admin_id uuid primary key
    references public.profiles(id)
    on delete cascade,

  last_seen_at timestamptz not null
    default now()
);

create index profile_photo_review_pending_badge_idx
on public.profiles(photo_updated_at)
where photo_status = 'pending'
  and photo_path is not null;

alter table public.profile_photo_review_views
enable row level security;

revoke all
on public.profile_photo_review_views
from public, anon, authenticated;

-- Number of new pending photographs for this administrator.

create or replace function
public.get_unseen_profile_photo_review_count()
returns integer
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  caller_id uuid;
  last_visit timestamptz;
  unseen_count integer;
begin
  caller_id := (select auth.uid());

  if caller_id is null or not public.is_admin() then
    raise exception 'Administrator permissions required'
      using errcode = 'insufficient_privilege';
  end if;

  select last_seen_at
  into last_visit
  from public.profile_photo_review_views
  where admin_id = caller_id;

  select count(*)::integer
  into unseen_count
  from public.profiles
  where photo_status = 'pending'
    and photo_path is not null
    and length(trim(photo_path)) > 0
    and photo_updated_at is not null
    and (
      last_visit is null
      or photo_updated_at > last_visit
    );

  return unseen_count;
end;
$$;

-- Mark the review section as viewed for this administrator.

create or replace function
public.mark_profile_photo_reviews_seen()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid;
begin
  caller_id := (select auth.uid());

  if caller_id is null or not public.is_admin() then
    raise exception 'Administrator permissions required'
      using errcode = 'insufficient_privilege';
  end if;

  insert into public.profile_photo_review_views (
    admin_id,
    last_seen_at
  )
  values (
    caller_id,
    statement_timestamp()
  )
  on conflict (admin_id)
  do update set
    last_seen_at = greatest(
      public.profile_photo_review_views.last_seen_at,
      excluded.last_seen_at
    );
end;
$$;

revoke all
on function public.get_unseen_profile_photo_review_count()
from public;

revoke all
on function public.mark_profile_photo_reviews_seen()
from public;

grant execute
on function public.get_unseen_profile_photo_review_count()
to authenticated;

grant execute
on function public.mark_profile_photo_reviews_seen()
to authenticated;

commit;
