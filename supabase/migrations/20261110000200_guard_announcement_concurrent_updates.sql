-- Conecta ITT | Optimistic concurrency for publication editing
-- Requires the client to provide expected_content_version.
-- Existing publication and audience rules are preserved.
-- This migration must be tested before deployment.

begin;

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
  expected_version_text text;
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

  -- Optimistic concurrency control.
  -- Reject missing, invalid or stale client versions before any mutation.
  expected_version_text := nullif(
    trim(p_announcement ->> 'expected_content_version'),
    ''
  );

  if expected_version_text is null
     or expected_version_text !~ '^[1-9][0-9]*$' then
    raise exception
      'A valid expected_content_version is required'
      using errcode = '22023';
  end if;

  if expected_version_text::numeric > 2147483647 then
    raise exception
      'expected_content_version is outside the supported range'
      using errcode = '22023';
  end if;

  if expected_version_text::integer
     <> existing_announcement.content_version then
    raise exception 'PUBLICATION_VERSION_CONFLICT'
      using errcode = 'P0001';
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

commit;
