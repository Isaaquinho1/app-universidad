begin;

-- ============================================================
-- Announcement and receipt versions
-- ============================================================

alter table public.announcements
add column if not exists content_version integer not null default 1;

alter table public.announcement_receipts
add column if not exists receipt_version integer not null default 1;

alter table public.announcements
drop constraint if exists announcements_content_version_positive;

alter table public.announcements
add constraint announcements_content_version_positive
check (content_version >= 1);

alter table public.announcement_receipts
drop constraint if exists announcement_receipts_version_positive;

alter table public.announcement_receipts
add constraint announcement_receipts_version_positive
check (receipt_version >= 1);

comment on column public.announcements.content_version is
  'Incremented whenever an administrator saves an edited announcement.';

comment on column public.announcement_receipts.receipt_version is
  'Announcement content version for which the receipt progress was recorded.';

-- Existing data belongs to the initial version.
update public.announcements
set content_version = 1
where content_version is null
   or content_version < 1;

update public.announcement_receipts
set receipt_version = 1
where receipt_version is null
   or receipt_version < 1;

-- ============================================================
-- Transactional update with version increment
-- ============================================================

create or replace function public.update_announcement_with_targets(
  p_announcement_id uuid,
  p_announcement jsonb,
  p_target jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid;
  existing_announcement public.announcements;
  requested_status text;
  requested_priority text;
  requested_all_users boolean;
  requested_published_at timestamptz;
  target_count integer;
begin
  current_user_id := (select auth.uid());

  if current_user_id is null then
    raise exception 'Authentication required'
      using errcode = 'insufficient_privilege';
  end if;

  if not public.is_admin() then
    raise exception 'Only administrators can update announcements'
      using errcode = 'insufficient_privilege';
  end if;

  if p_announcement_id is null then
    raise exception 'Announcement identifier is required'
      using errcode = 'invalid_parameter_value';
  end if;

  select *
  into existing_announcement
  from public.announcements
  where id = p_announcement_id
  for update;

  if not found then
    raise exception 'Announcement not found'
      using errcode = 'no_data_found';
  end if;

  if nullif(trim(p_announcement ->> 'author_id'), '') is not null
     and (p_announcement ->> 'author_id')::uuid
         <> existing_announcement.author_id then
    raise exception 'The announcement author cannot be changed'
      using errcode = 'insufficient_privilege';
  end if;

  requested_status := coalesce(
    nullif(trim(p_announcement ->> 'status'), ''),
    existing_announcement.status
  );

  requested_priority := coalesce(
    nullif(trim(p_announcement ->> 'priority'), ''),
    existing_announcement.priority
  );

  requested_all_users := coalesce(
    (p_announcement ->> 'all_users')::boolean,
    existing_announcement.all_users
  );

  if requested_status = 'published' then
    requested_published_at := coalesce(
      nullif(
        trim(p_announcement ->> 'published_at'),
        ''
      )::timestamptz,
      existing_announcement.published_at,
      timezone('utc', now())
    );
  else
    requested_published_at := nullif(
      trim(p_announcement ->> 'published_at'),
      ''
    )::timestamptz;
  end if;

  target_count :=
      jsonb_array_length(
        coalesce(p_target -> 'roles', '[]'::jsonb)
      )
    + jsonb_array_length(
        coalesce(p_target -> 'career_ids', '[]'::jsonb)
      )
    + jsonb_array_length(
        coalesce(p_target -> 'semesters', '[]'::jsonb)
      )
    + jsonb_array_length(
        coalesce(p_target -> 'group_ids', '[]'::jsonb)
      )
    + jsonb_array_length(
        coalesce(p_target -> 'user_ids', '[]'::jsonb)
      );

  if requested_all_users and target_count > 0 then
    raise exception
      'An all-users announcement cannot contain audience targets'
      using errcode = 'check_violation';
  end if;

  if not requested_all_users and target_count = 0 then
    raise exception
      'A segmented announcement requires at least one audience target'
      using errcode = 'check_violation';
  end if;

  update public.announcements
  set
    title = trim(p_announcement ->> 'title'),
    summary = nullif(trim(p_announcement ->> 'summary'), ''),
    body = trim(p_announcement ->> 'body'),
    author_name = nullif(trim(p_announcement ->> 'author_name'), ''),
    status = requested_status,
    priority = requested_priority,
    all_users = requested_all_users,
    attachment_urls = array(
      select jsonb_array_elements_text(
        coalesce(
          p_announcement -> 'attachment_urls',
          '[]'::jsonb
        )
      )
    ),
    published_at = requested_published_at,
    expires_at = nullif(
      trim(p_announcement ->> 'expires_at'),
      ''
    )::timestamptz,
    content_version = existing_announcement.content_version + 1,
    updated_at = timezone('utc', now())
  where id = p_announcement_id;

  delete from public.announcement_targets
  where announcement_id = p_announcement_id;

  if requested_all_users then
    return p_announcement_id;
  end if;

  insert into public.announcement_targets (
    announcement_id,
    role
  )
  select p_announcement_id, value
  from jsonb_array_elements_text(
    coalesce(p_target -> 'roles', '[]'::jsonb)
  );

  insert into public.announcement_targets (
    announcement_id,
    career_id
  )
  select p_announcement_id, value
  from jsonb_array_elements_text(
    coalesce(p_target -> 'career_ids', '[]'::jsonb)
  );

  insert into public.announcement_targets (
    announcement_id,
    semester
  )
  select p_announcement_id, value::smallint
  from jsonb_array_elements_text(
    coalesce(p_target -> 'semesters', '[]'::jsonb)
  );

  insert into public.announcement_targets (
    announcement_id,
    group_id
  )
  select p_announcement_id, value
  from jsonb_array_elements_text(
    coalesce(p_target -> 'group_ids', '[]'::jsonb)
  );

  insert into public.announcement_targets (
    announcement_id,
    user_id
  )
  select p_announcement_id, value::uuid
  from jsonb_array_elements_text(
    coalesce(p_target -> 'user_ids', '[]'::jsonb)
  );

  return p_announcement_id;
end;
$$;

revoke all on function public.update_announcement_with_targets(
  uuid,
  jsonb,
  jsonb
) from public;

grant execute on function public.update_announcement_with_targets(
  uuid,
  jsonb,
  jsonb
) to authenticated;

-- ============================================================
-- Receipt progression by announcement version
-- ============================================================

create or replace function public.advance_announcement_receipt(
  p_announcement_id uuid,
  p_status text
)
returns public.announcement_receipts
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid;
  current_content_version integer;
  stored_receipt_version integer;
  current_level integer;
  requested_level integer;
  receipt public.announcement_receipts;
begin
  current_user_id := (select auth.uid());

  if current_user_id is null then
    raise exception 'Authentication required'
      using errcode = 'insufficient_privilege';
  end if;

  if not public.announcement_is_visible_to_user(
    p_announcement_id,
    current_user_id
  ) then
    raise exception 'Announcement is not visible to this user'
      using errcode = 'insufficient_privilege';
  end if;

  select announcement.content_version
  into current_content_version
  from public.announcements announcement
  where announcement.id = p_announcement_id;

  if current_content_version is null then
    raise exception 'Announcement not found'
      using errcode = 'no_data_found';
  end if;

  requested_level := case p_status
    when 'delivered' then 0
    when 'seen' then 1
    when 'read' then 2
    when 'confirmed' then 3
    else null
  end;

  if requested_level is null then
    raise exception 'Invalid receipt status: %', p_status
      using errcode = 'check_violation';
  end if;

  select
    case status
      when 'delivered' then 0
      when 'seen' then 1
      when 'read' then 2
      when 'confirmed' then 3
    end,
    receipt_version
  into
    current_level,
    stored_receipt_version
  from public.announcement_receipts
  where announcement_id = p_announcement_id
    and user_id = current_user_id
  for update;

  if stored_receipt_version = current_content_version
     and current_level is not null
     and current_level >= requested_level then
    select *
    into receipt
    from public.announcement_receipts
    where announcement_id = p_announcement_id
      and user_id = current_user_id;

    return receipt;
  end if;

  insert into public.announcement_receipts (
    announcement_id,
    user_id,
    status,
    receipt_version,
    delivered_at,
    seen_at,
    read_at,
    confirmed_at
  )
  values (
    p_announcement_id,
    current_user_id,
    p_status,
    current_content_version,
    case
      when requested_level >= 0
      then timezone('utc', now())
    end,
    case
      when requested_level >= 1
      then timezone('utc', now())
    end,
    case
      when requested_level >= 2
      then timezone('utc', now())
    end,
    case
      when requested_level >= 3
      then timezone('utc', now())
    end
  )
  on conflict (announcement_id, user_id)
  do update
  set
    status = excluded.status,
    receipt_version = excluded.receipt_version,

    delivered_at = case
      when public.announcement_receipts.receipt_version
           <> excluded.receipt_version
      then excluded.delivered_at
      else coalesce(
        public.announcement_receipts.delivered_at,
        excluded.delivered_at
      )
    end,

    seen_at = case
      when public.announcement_receipts.receipt_version
           <> excluded.receipt_version
      then excluded.seen_at
      else coalesce(
        public.announcement_receipts.seen_at,
        excluded.seen_at
      )
    end,

    read_at = case
      when public.announcement_receipts.receipt_version
           <> excluded.receipt_version
      then excluded.read_at
      else coalesce(
        public.announcement_receipts.read_at,
        excluded.read_at
      )
    end,

    confirmed_at = case
      when public.announcement_receipts.receipt_version
           <> excluded.receipt_version
      then excluded.confirmed_at
      else coalesce(
        public.announcement_receipts.confirmed_at,
        excluded.confirmed_at
      )
    end,

    updated_at = timezone('utc', now())
  returning *
  into receipt;

  return receipt;
end;
$$;

revoke all on function public.advance_announcement_receipt(
  uuid,
  text
) from public;

grant execute on function public.advance_announcement_receipt(
  uuid,
  text
) to authenticated;

-- ============================================================
-- Visible announcements including content version
-- ============================================================

create or replace function public.get_visible_announcements(
  p_limit integer default 100
)
returns setof jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', announcement.id,
    'title', announcement.title,
    'summary', announcement.summary,
    'body', announcement.body,
    'author_id', announcement.author_id,
    'author_name', announcement.author_name,
    'status', announcement.status,
    'priority', announcement.priority,
    'all_users', announcement.all_users,
    'content_version', announcement.content_version,
    'attachment_urls', announcement.attachment_urls,
    'published_at', announcement.published_at,
    'expires_at', announcement.expires_at,
    'created_at', announcement.created_at,
    'updated_at', announcement.updated_at,
    'target', jsonb_build_object(
      'all_users', announcement.all_users,
      'roles', coalesce(
        (
          select jsonb_agg(target.role order by target.role)
          from public.announcement_targets target
          where target.announcement_id = announcement.id
            and target.role is not null
        ),
        '[]'::jsonb
      ),
      'career_ids', coalesce(
        (
          select jsonb_agg(target.career_id order by target.career_id)
          from public.announcement_targets target
          where target.announcement_id = announcement.id
            and target.career_id is not null
        ),
        '[]'::jsonb
      ),
      'semesters', coalesce(
        (
          select jsonb_agg(target.semester order by target.semester)
          from public.announcement_targets target
          where target.announcement_id = announcement.id
            and target.semester is not null
        ),
        '[]'::jsonb
      ),
      'group_ids', coalesce(
        (
          select jsonb_agg(target.group_id order by target.group_id)
          from public.announcement_targets target
          where target.announcement_id = announcement.id
            and target.group_id is not null
        ),
        '[]'::jsonb
      ),
      'user_ids', coalesce(
        (
          select jsonb_agg(target.user_id order by target.user_id)
          from public.announcement_targets target
          where target.announcement_id = announcement.id
            and target.user_id is not null
        ),
        '[]'::jsonb
      )
    )
  )
  from public.announcements announcement
  where public.announcement_is_visible_to_user(
    announcement.id,
    (select auth.uid())
  )
  order by announcement.published_at desc
  limit greatest(1, least(coalesce(p_limit, 100), 500));
$$;

revoke all on function public.get_visible_announcements(integer)
from public;

grant execute on function public.get_visible_announcements(integer)
to authenticated;

-- ============================================================
-- Administrative announcements including content version
-- ============================================================

create or replace function public.get_admin_announcements(
  p_status text default null,
  p_limit integer default 200
)
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required'
      using errcode = 'insufficient_privilege';
  end if;

  if not public.is_admin() then
    raise exception 'Only administrators can list announcements'
      using errcode = 'insufficient_privilege';
  end if;

  if p_status is not null
     and p_status not in (
       'draft',
       'scheduled',
       'published',
       'archived'
     ) then
    raise exception 'Invalid announcement status: %', p_status
      using errcode = 'invalid_parameter_value';
  end if;

  return query
  select jsonb_build_object(
    'id', announcement.id,
    'title', announcement.title,
    'summary', announcement.summary,
    'body', announcement.body,
    'author_id', announcement.author_id,
    'author_name', announcement.author_name,
    'status', announcement.status,
    'priority', announcement.priority,
    'all_users', announcement.all_users,
    'content_version', announcement.content_version,
    'attachment_urls', announcement.attachment_urls,
    'published_at', announcement.published_at,
    'expires_at', announcement.expires_at,
    'created_at', announcement.created_at,
    'updated_at', announcement.updated_at,
    'target', jsonb_build_object(
      'all_users', announcement.all_users,
      'roles', coalesce(
        (
          select jsonb_agg(target.role order by target.role)
          from public.announcement_targets target
          where target.announcement_id = announcement.id
            and target.role is not null
        ),
        '[]'::jsonb
      ),
      'career_ids', coalesce(
        (
          select jsonb_agg(target.career_id order by target.career_id)
          from public.announcement_targets target
          where target.announcement_id = announcement.id
            and target.career_id is not null
        ),
        '[]'::jsonb
      ),
      'semesters', coalesce(
        (
          select jsonb_agg(target.semester order by target.semester)
          from public.announcement_targets target
          where target.announcement_id = announcement.id
            and target.semester is not null
        ),
        '[]'::jsonb
      ),
      'group_ids', coalesce(
        (
          select jsonb_agg(target.group_id order by target.group_id)
          from public.announcement_targets target
          where target.announcement_id = announcement.id
            and target.group_id is not null
        ),
        '[]'::jsonb
      ),
      'user_ids', coalesce(
        (
          select jsonb_agg(target.user_id order by target.user_id)
          from public.announcement_targets target
          where target.announcement_id = announcement.id
            and target.user_id is not null
        ),
        '[]'::jsonb
      )
    )
  )
  from public.announcements announcement
  where p_status is null
     or announcement.status = p_status
  order by
    case announcement.status
      when 'draft' then 0
      when 'scheduled' then 1
      when 'published' then 2
      when 'archived' then 3
      else 4
    end,
    announcement.updated_at desc
  limit greatest(1, least(coalesce(p_limit, 200), 500));
end;
$$;

revoke all on function public.get_admin_announcements(
  text,
  integer
) from public;

grant execute on function public.get_admin_announcements(
  text,
  integer
) to authenticated;

commit;
