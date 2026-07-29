-- Conecta ITT
-- Enables institutional news as global publications.
--
-- Rules:
-- - Announcements may be global or segmented.
-- - News publications are always global and cannot contain audience targets.
-- - Editorial fields are persisted by transactional RPCs.
-- - Publication queries expose all editorial fields.

begin;

-- ============================================================
-- Create publication with audience targets
-- ============================================================

create or replace function public.create_announcement_with_targets(
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
  new_announcement_id uuid;
  requested_author_id uuid;
  requested_status text;
  requested_priority text;
  requested_content_type text;
  requested_news_category text;
  requested_featured boolean;
  requested_featured_until timestamptz;
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
    raise exception 'Only administrators can create publications'
      using errcode = 'insufficient_privilege';
  end if;

  requested_author_id :=
    nullif(trim(p_announcement ->> 'author_id'), '')::uuid;

  if requested_author_id is null
     or requested_author_id <> current_user_id then
    raise exception
      'The publication author must match the authenticated user'
      using errcode = 'insufficient_privilege';
  end if;

  requested_status := coalesce(
    nullif(trim(p_announcement ->> 'status'), ''),
    'draft'
  );

  requested_priority := coalesce(
    nullif(trim(p_announcement ->> 'priority'), ''),
    'normal'
  );

  requested_content_type := coalesce(
    nullif(trim(p_announcement ->> 'content_type'), ''),
    'announcement'
  );

  if requested_content_type not in ('announcement', 'news') then
    raise exception 'Invalid publication content type: %',
      requested_content_type
      using errcode = 'invalid_parameter_value';
  end if;

  requested_all_users := coalesce(
    (p_announcement ->> 'all_users')::boolean,
    false
  );

  requested_news_category :=
    nullif(trim(p_announcement ->> 'news_category'), '');

  requested_featured := coalesce(
    (p_announcement ->> 'featured')::boolean,
    false
  );

  requested_featured_until :=
    nullif(
      trim(p_announcement ->> 'featured_until'),
      ''
    )::timestamptz;

  if requested_content_type = 'announcement' then
    requested_news_category := null;
    requested_featured := false;
    requested_featured_until := null;
  elsif requested_featured is false then
    requested_featured_until := null;
  end if;

  if requested_status = 'published' then
    requested_published_at := coalesce(
      nullif(
        trim(p_announcement ->> 'published_at'),
        ''
      )::timestamptz,
      timezone('utc', now())
    );
  else
    requested_published_at :=
      nullif(
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

  if requested_content_type = 'news'
     and not requested_all_users then
    raise exception 'Institutional news must be global'
      using errcode = 'check_violation';
  end if;

  if requested_content_type = 'news'
     and target_count > 0 then
    raise exception 'Institutional news cannot contain audience targets'
      using errcode = 'check_violation';
  end if;

  if requested_all_users and target_count > 0 then
    raise exception
      'An all-users publication cannot contain audience targets'
      using errcode = 'check_violation';
  end if;

  if not requested_all_users and target_count = 0 then
    raise exception
      'A segmented announcement requires at least one audience target'
      using errcode = 'check_violation';
  end if;

  insert into public.announcements (
    id,
    title,
    summary,
    body,
    author_id,
    author_name,
    status,
    priority,
    content_type,
    news_category,
    featured,
    featured_until,
    all_users,
    attachment_urls,
    published_at,
    expires_at
  )
  values (
    coalesce(
      nullif(trim(p_announcement ->> 'id'), '')::uuid,
      gen_random_uuid()
    ),
    trim(p_announcement ->> 'title'),
    nullif(trim(p_announcement ->> 'summary'), ''),
    trim(p_announcement ->> 'body'),
    requested_author_id,
    nullif(trim(p_announcement ->> 'author_name'), ''),
    requested_status,
    requested_priority,
    requested_content_type,
    requested_news_category,
    requested_featured,
    requested_featured_until,
    requested_all_users,
    array(
      select jsonb_array_elements_text(
        coalesce(
          p_announcement -> 'attachment_urls',
          '[]'::jsonb
        )
      )
    ),
    requested_published_at,
    nullif(
      trim(p_announcement ->> 'expires_at'),
      ''
    )::timestamptz
  )
  returning id into new_announcement_id;

  if requested_all_users then
    return new_announcement_id;
  end if;

  insert into public.announcement_targets (
    announcement_id,
    role
  )
  select new_announcement_id, value
  from jsonb_array_elements_text(
    coalesce(p_target -> 'roles', '[]'::jsonb)
  );

  insert into public.announcement_targets (
    announcement_id,
    career_id
  )
  select new_announcement_id, value
  from jsonb_array_elements_text(
    coalesce(p_target -> 'career_ids', '[]'::jsonb)
  );

  insert into public.announcement_targets (
    announcement_id,
    semester
  )
  select new_announcement_id, value::smallint
  from jsonb_array_elements_text(
    coalesce(p_target -> 'semesters', '[]'::jsonb)
  );

  insert into public.announcement_targets (
    announcement_id,
    group_id
  )
  select new_announcement_id, value
  from jsonb_array_elements_text(
    coalesce(p_target -> 'group_ids', '[]'::jsonb)
  );

  insert into public.announcement_targets (
    announcement_id,
    user_id
  )
  select new_announcement_id, value::uuid
  from jsonb_array_elements_text(
    coalesce(p_target -> 'user_ids', '[]'::jsonb)
  );

  return new_announcement_id;
end;
$$;

revoke all on function public.create_announcement_with_targets(
  jsonb,
  jsonb
) from public;

grant execute on function public.create_announcement_with_targets(
  jsonb,
  jsonb
) to authenticated;

-- ============================================================
-- Update publication with audience targets
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
  requested_content_type text;
  requested_news_category text;
  requested_featured boolean;
  requested_featured_until timestamptz;
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
    raise exception 'Only administrators can update publications'
      using errcode = 'insufficient_privilege';
  end if;

  if p_announcement_id is null then
    raise exception 'Publication identifier is required'
      using errcode = 'invalid_parameter_value';
  end if;

  select *
  into existing_announcement
  from public.announcements
  where id = p_announcement_id
  for update;

  if not found then
    raise exception 'Publication not found'
      using errcode = 'no_data_found';
  end if;

  if nullif(trim(p_announcement ->> 'author_id'), '') is not null
     and (p_announcement ->> 'author_id')::uuid
         <> existing_announcement.author_id then
    raise exception 'The publication author cannot be changed'
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

  requested_content_type := coalesce(
    nullif(trim(p_announcement ->> 'content_type'), ''),
    existing_announcement.content_type
  );

  if requested_content_type not in ('announcement', 'news') then
    raise exception 'Invalid publication content type: %',
      requested_content_type
      using errcode = 'invalid_parameter_value';
  end if;

  requested_all_users := coalesce(
    (p_announcement ->> 'all_users')::boolean,
    existing_announcement.all_users
  );

  requested_news_category := coalesce(
    nullif(trim(p_announcement ->> 'news_category'), ''),
    existing_announcement.news_category
  );

  requested_featured := coalesce(
    (p_announcement ->> 'featured')::boolean,
    existing_announcement.featured
  );

  requested_featured_until := coalesce(
    nullif(
      trim(p_announcement ->> 'featured_until'),
      ''
    )::timestamptz,
    existing_announcement.featured_until
  );

  if requested_content_type = 'announcement' then
    requested_news_category := null;
    requested_featured := false;
    requested_featured_until := null;
  elsif requested_featured is false then
    requested_featured_until := null;
  end if;

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

  if requested_content_type = 'news'
     and not requested_all_users then
    raise exception 'Institutional news must be global'
      using errcode = 'check_violation';
  end if;

  if requested_content_type = 'news'
     and target_count > 0 then
    raise exception 'Institutional news cannot contain audience targets'
      using errcode = 'check_violation';
  end if;

  if requested_all_users and target_count > 0 then
    raise exception
      'An all-users publication cannot contain audience targets'
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
    content_type = requested_content_type,
    news_category = requested_news_category,
    featured = requested_featured,
    featured_until = requested_featured_until,
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
-- Publications visible to the authenticated user
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
    'content_type', announcement.content_type,
    'news_category', announcement.news_category,
    'featured', announcement.featured,
    'featured_until', announcement.featured_until,
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
  order by
    case
      when announcement.content_type = 'news'
       and announcement.featured = true
       and (
         announcement.featured_until is null
         or announcement.featured_until > timezone('utc', now())
       )
      then 0
      else 1
    end,
    announcement.published_at desc
  limit greatest(1, least(coalesce(p_limit, 100), 500));
$$;

revoke all on function public.get_visible_announcements(integer)
from public;

grant execute on function public.get_visible_announcements(integer)
to authenticated;

-- ============================================================
-- Administrative publications
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
    raise exception 'Only administrators can list publications'
      using errcode = 'insufficient_privilege';
  end if;

  if p_status is not null
     and p_status not in (
       'draft',
       'scheduled',
       'published',
       'archived'
     ) then
    raise exception 'Invalid publication status: %', p_status
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
    'content_type', announcement.content_type,
    'news_category', announcement.news_category,
    'featured', announcement.featured,
    'featured_until', announcement.featured_until,
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
