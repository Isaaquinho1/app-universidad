begin;

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
    raise exception 'Only administrators can create announcements'
      using errcode = 'insufficient_privilege';
  end if;

  requested_author_id :=
    nullif(trim(p_announcement ->> 'author_id'), '')::uuid;

  if requested_author_id is null
     or requested_author_id <> current_user_id then
    raise exception 'The announcement author must match the authenticated user'
      using errcode = 'insufficient_privilege';
  end if;

  requested_status :=
    coalesce(nullif(trim(p_announcement ->> 'status'), ''), 'draft');

  requested_priority :=
    coalesce(nullif(trim(p_announcement ->> 'priority'), ''), 'normal');

  requested_all_users :=
    coalesce((p_announcement ->> 'all_users')::boolean, false);

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

  insert into public.announcements (
    id,
    title,
    summary,
    body,
    author_id,
    author_name,
    status,
    priority,
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
  select
    new_announcement_id,
    value
  from jsonb_array_elements_text(
    coalesce(p_target -> 'roles', '[]'::jsonb)
  );

  insert into public.announcement_targets (
    announcement_id,
    career_id
  )
  select
    new_announcement_id,
    value
  from jsonb_array_elements_text(
    coalesce(p_target -> 'career_ids', '[]'::jsonb)
  );

  insert into public.announcement_targets (
    announcement_id,
    semester
  )
  select
    new_announcement_id,
    value::smallint
  from jsonb_array_elements_text(
    coalesce(p_target -> 'semesters', '[]'::jsonb)
  );

  insert into public.announcement_targets (
    announcement_id,
    group_id
  )
  select
    new_announcement_id,
    value
  from jsonb_array_elements_text(
    coalesce(p_target -> 'group_ids', '[]'::jsonb)
  );

  insert into public.announcement_targets (
    announcement_id,
    user_id
  )
  select
    new_announcement_id,
    value::uuid
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

commit;
