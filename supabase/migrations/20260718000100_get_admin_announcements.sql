begin;

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
