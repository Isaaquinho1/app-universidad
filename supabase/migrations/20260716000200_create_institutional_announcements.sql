-- Conecta ITT
-- Institutional announcements, segmentation and receipt tracking.

begin;

-- ============================================================
-- Announcements
-- ============================================================

create table public.announcements (
  id uuid primary key default gen_random_uuid(),

  title text not null,
  summary text,
  body text not null,

  author_id uuid not null references public.profiles(id)
    on update cascade
    on delete restrict,

  author_name text,

  status text not null default 'draft',
  priority text not null default 'normal',

  all_users boolean not null default false,

  attachment_urls text[] not null default '{}',

  published_at timestamptz,
  expires_at timestamptz,

  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint announcements_title_not_blank
    check (length(trim(title)) > 0),

  constraint announcements_body_not_blank
    check (length(trim(body)) > 0),

  constraint announcements_status_valid
    check (
      status in (
        'draft',
        'scheduled',
        'published',
        'archived'
      )
    ),

  constraint announcements_priority_valid
    check (
      priority in (
        'low',
        'normal',
        'high',
        'urgent'
      )
    ),

  constraint announcements_expiration_after_publication
    check (
      expires_at is null
      or published_at is null
      or expires_at > published_at
    )
);

comment on table public.announcements is
  'Institutional announcements created by authorized staff.';

comment on column public.announcements.all_users is
  'When true, the announcement is visible to every active profile.';

create index announcements_status_published_at_idx
  on public.announcements(status, published_at desc);

create index announcements_priority_idx
  on public.announcements(priority);

create index announcements_author_id_idx
  on public.announcements(author_id);

create index announcements_expires_at_idx
  on public.announcements(expires_at);

drop trigger if exists announcements_set_updated_at
  on public.announcements;

create trigger announcements_set_updated_at
before update on public.announcements
for each row
execute function public.set_updated_at();

-- ============================================================
-- Normalized announcement targets
-- ============================================================

create table public.announcement_targets (
  id uuid primary key default gen_random_uuid(),

  announcement_id uuid not null
    references public.announcements(id)
    on update cascade
    on delete cascade,

  role text,
  career_id text references public.careers(id)
    on update cascade
    on delete restrict,

  semester smallint,

  group_id text references public.academic_groups(id)
    on update cascade
    on delete restrict,

  created_at timestamptz not null default timezone('utc', now()),

  constraint announcement_targets_exactly_one_dimension
    check (
      num_nonnulls(
        role,
        career_id,
        semester,
        group_id
      ) = 1
    ),

  constraint announcement_targets_role_valid
    check (
      role is null
      or role in (
        'student',
        'teacher',
        'admin',
        'superAdmin'
      )
    ),

  constraint announcement_targets_semester_range
    check (
      semester is null
      or semester between 1 and 14
    )
);

comment on table public.announcement_targets is
  'Audience criteria. Dimensions are combined with AND and values within a dimension with OR.';

create index announcement_targets_announcement_id_idx
  on public.announcement_targets(announcement_id);

create index announcement_targets_role_idx
  on public.announcement_targets(role)
  where role is not null;

create index announcement_targets_career_id_idx
  on public.announcement_targets(career_id)
  where career_id is not null;

create index announcement_targets_semester_idx
  on public.announcement_targets(semester)
  where semester is not null;

create index announcement_targets_group_id_idx
  on public.announcement_targets(group_id)
  where group_id is not null;

create unique index announcement_targets_unique_role_idx
  on public.announcement_targets(announcement_id, role)
  where role is not null;

create unique index announcement_targets_unique_career_idx
  on public.announcement_targets(announcement_id, career_id)
  where career_id is not null;

create unique index announcement_targets_unique_semester_idx
  on public.announcement_targets(announcement_id, semester)
  where semester is not null;

create unique index announcement_targets_unique_group_idx
  on public.announcement_targets(announcement_id, group_id)
  where group_id is not null;

-- ============================================================
-- Announcement receipts
-- ============================================================

create table public.announcement_receipts (
  announcement_id uuid not null
    references public.announcements(id)
    on update cascade
    on delete cascade,

  user_id uuid not null
    references public.profiles(id)
    on update cascade
    on delete cascade,

  status text not null default 'delivered',

  delivered_at timestamptz,
  seen_at timestamptz,
  read_at timestamptz,
  confirmed_at timestamptz,

  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  primary key (announcement_id, user_id),

  constraint announcement_receipts_status_valid
    check (
      status in (
        'delivered',
        'seen',
        'read',
        'confirmed'
      )
    )
);

comment on table public.announcement_receipts is
  'Per-user delivery and reading progress for institutional announcements.';

create index announcement_receipts_user_id_idx
  on public.announcement_receipts(user_id);

create index announcement_receipts_status_idx
  on public.announcement_receipts(status);

drop trigger if exists announcement_receipts_set_updated_at
  on public.announcement_receipts;

create trigger announcement_receipts_set_updated_at
before update on public.announcement_receipts
for each row
execute function public.set_updated_at();

-- ============================================================
-- Visibility helper
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
          or (
            exists (
              select 1
              from public.announcement_targets target
              where target.announcement_id = announcement.id
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
-- Visible announcements RPC
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
-- Receipt advancement
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

  select case status
    when 'delivered' then 0
    when 'seen' then 1
    when 'read' then 2
    when 'confirmed' then 3
  end
  into current_level
  from public.announcement_receipts
  where announcement_id = p_announcement_id
    and user_id = current_user_id
  for update;

  if current_level is not null
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
    delivered_at,
    seen_at,
    read_at,
    confirmed_at
  )
  values (
    p_announcement_id,
    current_user_id,
    p_status,
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

    delivered_at = coalesce(
      public.announcement_receipts.delivered_at,
      excluded.delivered_at
    ),

    seen_at = coalesce(
      public.announcement_receipts.seen_at,
      excluded.seen_at
    ),

    read_at = coalesce(
      public.announcement_receipts.read_at,
      excluded.read_at
    ),

    confirmed_at = coalesce(
      public.announcement_receipts.confirmed_at,
      excluded.confirmed_at
    ),

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
-- Row Level Security
-- ============================================================

alter table public.announcements enable row level security;
alter table public.announcement_targets enable row level security;
alter table public.announcement_receipts enable row level security;

create policy announcements_student_read
on public.announcements
for select
to authenticated
using (
  public.announcement_is_visible_to_user(
    id,
    (select auth.uid())
  )
);

create policy announcements_admin_read
on public.announcements
for select
to authenticated
using ((select public.is_admin()));

create policy announcements_admin_insert
on public.announcements
for insert
to authenticated
with check (
  (select public.is_admin())
  and author_id = (select auth.uid())
);

create policy announcements_admin_update
on public.announcements
for update
to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

create policy announcements_admin_delete
on public.announcements
for delete
to authenticated
using ((select public.is_admin()));

create policy announcement_targets_admin_read
on public.announcement_targets
for select
to authenticated
using ((select public.is_admin()));

create policy announcement_targets_admin_insert
on public.announcement_targets
for insert
to authenticated
with check ((select public.is_admin()));

create policy announcement_targets_admin_update
on public.announcement_targets
for update
to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

create policy announcement_targets_admin_delete
on public.announcement_targets
for delete
to authenticated
using ((select public.is_admin()));

create policy announcement_receipts_read_own
on public.announcement_receipts
for select
to authenticated
using (user_id = (select auth.uid()));

create policy announcement_receipts_admin_read
on public.announcement_receipts
for select
to authenticated
using ((select public.is_admin()));

-- Client-side inserts and updates are intentionally denied.
-- Receipt progression must use advance_announcement_receipt().

-- ============================================================
-- Data API privileges
-- ============================================================

revoke all on table public.announcements from anon;
revoke all on table public.announcement_targets from anon;
revoke all on table public.announcement_receipts from anon;

grant select, insert, update, delete
  on table public.announcements
  to authenticated;

grant select, insert, update, delete
  on table public.announcement_targets
  to authenticated;

grant select
  on table public.announcement_receipts
  to authenticated;

commit;
