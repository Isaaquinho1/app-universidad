-- Conecta ITT: concurrency-safe draft Storage cleanup.
begin;

alter table public.draft_publication_storage_cleanup
  add column claim_token uuid,
  add column claimed_at timestamptz;

alter table public.draft_publication_storage_cleanup
  drop constraint draft_cleanup_status_check;

alter table public.draft_publication_storage_cleanup
  add constraint draft_cleanup_status_check
  check (status in ('pending', 'processing', 'completed', 'failed'));

create or replace function public.claim_draft_storage_cleanup(
  p_publication_id uuid,
  p_limit integer default 20
)
returns table (
  id uuid,
  storage_bucket text,
  storage_path text,
  attempts integer,
  claim_token uuid
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_publication_id is null
     or p_limit is null
     or p_limit < 1
     or p_limit > 20 then
    raise exception 'Invalid cleanup request'
      using errcode = '22023';
  end if;

  -- No deletion request may claim files of an existing publication.
  if exists (
    select 1
    from public.announcements
    where announcements.id = p_publication_id
  ) then
    raise exception 'Publication still exists'
      using errcode = 'P0001';
  end if;

  return query
  with candidates as (
    select queue.id
    from public.draft_publication_storage_cleanup as queue
    where queue.publication_id = p_publication_id
      and (
        queue.status in ('pending', 'failed')
        or (
          queue.status = 'processing'
          and queue.claimed_at < now() - interval '15 minutes'
        )
      )
    order by queue.created_at, queue.id
    for update skip locked
    limit p_limit
  )
  update public.draft_publication_storage_cleanup as queue
  set
    status = 'processing',
    claim_token = gen_random_uuid(),
    claimed_at = now(),
    attempts = queue.attempts + 1,
    last_error = null
  from candidates
  where queue.id = candidates.id
  returning
    queue.id,
    queue.storage_bucket,
    queue.storage_path,
    queue.attempts,
    queue.claim_token;
end;
$$;

revoke all on function public.claim_draft_storage_cleanup(uuid, integer)
  from public, anon, authenticated;

grant execute on function public.claim_draft_storage_cleanup(uuid, integer)
  to service_role;

create or replace function public.finish_draft_storage_cleanup(
  p_id uuid,
  p_claim_token uuid,
  p_success boolean,
  p_error text default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  affected integer;
begin
  if p_id is null
     or p_claim_token is null
     or p_success is null then
    raise exception 'Invalid cleanup completion'
      using errcode = '22023';
  end if;

  update public.draft_publication_storage_cleanup as queue
  set
    status = case
      when p_success then 'completed'
      else 'failed'
    end,
    last_error = case
      when p_success then null
      else left(coalesce(p_error, 'Storage cleanup failed'), 1000)
    end,
    completed_at = case when p_success then now() else null end,
    claim_token = null,
    claimed_at = null
  where queue.id = p_id
    and queue.claim_token = p_claim_token
    and queue.status = 'processing';

  get diagnostics affected = row_count;

  return affected = 1;
end;
$$;

revoke all on function public.finish_draft_storage_cleanup(
  uuid, uuid, boolean, text
) from public, anon, authenticated;

grant execute on function public.finish_draft_storage_cleanup(
  uuid, uuid, boolean, text
) to service_role;

commit;
