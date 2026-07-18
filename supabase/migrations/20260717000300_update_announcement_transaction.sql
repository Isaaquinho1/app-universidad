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
  select
    p_announcement_id,
    value
  from jsonb_array_elements_text(
    coalesce(p_target -> 'roles', '[]'::jsonb)
  );

  insert into public.announcement_targets (
    announcement_id,
    career_id
  )
  select
    p_announcement_id,
    value
  from jsonb_array_elements_text(
    coalesce(p_target -> 'career_ids', '[]'::jsonb)
  );

  insert into public.announcement_targets (
    announcement_id,
    semester
  )
  select
    p_announcement_id,
    value::smallint
  from jsonb_array_elements_text(
    coalesce(p_target -> 'semesters', '[]'::jsonb)
  );

  insert into public.announcement_targets (
    announcement_id,
    group_id
  )
  select
    p_announcement_id,
    value
  from jsonb_array_elements_text(
    coalesce(p_target -> 'group_ids', '[]'::jsonb)
  );

  insert into public.announcement_targets (
    announcement_id,
    user_id
  )
  select
    p_announcement_id,
    value::uuid
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
