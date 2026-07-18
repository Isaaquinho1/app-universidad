begin;

-- ============================================================
-- Direct recipients
-- ============================================================

alter table public.announcement_targets
add column if not exists user_id uuid
references public.profiles(id)
on update cascade
on delete restrict;

alter table public.announcement_targets
drop constraint if exists announcement_targets_exactly_one_dimension;

alter table public.announcement_targets
add constraint announcement_targets_exactly_one_dimension
check (
  num_nonnulls(
    role,
    career_id,
    semester,
    group_id,
    user_id
  ) = 1
);

create index if not exists announcement_targets_user_id_idx
on public.announcement_targets(user_id)
where user_id is not null;

create unique index if not exists announcement_targets_unique_user_idx
on public.announcement_targets(announcement_id, user_id)
where user_id is not null;

comment on column public.announcement_targets.user_id is
  'Specific recipient selected directly by an authorized administrator.';

comment on table public.announcement_targets is
  'Academic criteria are combined with AND between dimensions and OR within each dimension. Direct user targets are combined with the academic criteria using OR.';

-- ============================================================
-- Visibility: all users OR direct recipient OR academic criteria
-- ============================================================

create or replace function public.announcement_is_visible_to_user(
  p_announcement_id uuid,
  p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select
        profile.active
        and announcement.status = 'published'
        and announcement.published_at is not null
        and announcement.published_at <= timezone('utc', now())
        and (
          announcement.expires_at is null
          or announcement.expires_at > timezone('utc', now())
        )
        and (
          announcement.all_users

          or exists (
            select 1
            from public.announcement_targets target
            where target.announcement_id = announcement.id
              and target.user_id = profile.id
          )

          or (
            exists (
              select 1
              from public.announcement_targets target
              where target.announcement_id = announcement.id
                and (
                  target.role is not null
                  or target.career_id is not null
                  or target.semester is not null
                  or target.group_id is not null
                )
            )

            and (
              not exists (
                select 1
                from public.announcement_targets target
                where target.announcement_id = announcement.id
                  and target.role is not null
              )
              or exists (
                select 1
                from public.announcement_targets target
                where target.announcement_id = announcement.id
                  and target.role = profile.role
              )
            )

            and (
              not exists (
                select 1
                from public.announcement_targets target
                where target.announcement_id = announcement.id
                  and target.career_id is not null
              )
              or exists (
                select 1
                from public.announcement_targets target
                where target.announcement_id = announcement.id
                  and target.career_id = profile.career_id
              )
            )

            and (
              not exists (
                select 1
                from public.announcement_targets target
                where target.announcement_id = announcement.id
                  and target.semester is not null
              )
              or exists (
                select 1
                from public.announcement_targets target
                where target.announcement_id = announcement.id
                  and target.semester = profile.semester
              )
            )

            and (
              not exists (
                select 1
                from public.announcement_targets target
                where target.announcement_id = announcement.id
                  and target.group_id is not null
              )
              or exists (
                select 1
                from public.announcement_targets target
                where target.announcement_id = announcement.id
                  and target.group_id = profile.group_id
              )
            )
          )
        )
      from public.announcements announcement
      join public.profiles profile
        on profile.id = p_user_id
      where announcement.id = p_announcement_id
    ),
    false
  );
$$;

revoke all on function public.announcement_is_visible_to_user(
  uuid,
  uuid
) from public;

grant execute on function public.announcement_is_visible_to_user(
  uuid,
  uuid
) to authenticated;

-- ============================================================
-- Visible announcements payload
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
-- Secure recipient lookup for admin and superAdmin
-- ============================================================

create or replace function public.search_announcement_recipients(
  p_query text,
  p_limit integer default 20
)
returns table (
  id uuid,
  email text,
  display_name text,
  role text,
  career_id text,
  semester smallint,
  group_id text,
  control_number text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    profile.id,
    profile.email,
    profile.display_name,
    profile.role,
    profile.career_id,
    profile.semester,
    profile.group_id,
    profile.control_number
  from public.profiles profile
  where public.is_admin()
    and profile.active
    and length(trim(coalesce(p_query, ''))) >= 2
    and (
      profile.control_number ilike '%' || trim(p_query) || '%'
      or profile.email ilike '%' || trim(p_query) || '%'
      or profile.display_name ilike '%' || trim(p_query) || '%'
    )
  order by
    case
      when lower(profile.control_number) = lower(trim(p_query)) then 0
      when lower(profile.email) = lower(trim(p_query)) then 1
      else 2
    end,
    profile.display_name nulls last,
    profile.control_number nulls last
  limit greatest(1, least(coalesce(p_limit, 20), 50));
$$;

revoke all on function public.search_announcement_recipients(
  text,
  integer
) from public;

grant execute on function public.search_announcement_recipients(
  text,
  integer
) to authenticated;

commit;
