-- Conecta ITT
-- Enriched institutional publications and managed media assets.
--
-- Existing announcements remain fully compatible and are classified
-- automatically as institutional announcements.

begin;

-- ============================================================
-- Publication classification
-- ============================================================

alter table public.announcements
  add column if not exists content_type text
    not null
    default 'announcement';

alter table public.announcements
  add column if not exists news_category text;

alter table public.announcements
  add column if not exists featured boolean
    not null
    default false;

alter table public.announcements
  add column if not exists featured_until timestamptz;

alter table public.announcements
  drop constraint if exists announcements_content_type_valid;

alter table public.announcements
  add constraint announcements_content_type_valid
  check (
    content_type in (
      'announcement',
      'news'
    )
  );

alter table public.announcements
  drop constraint if exists announcements_news_category_not_blank;

alter table public.announcements
  add constraint announcements_news_category_not_blank
  check (
    news_category is null
    or length(trim(news_category)) > 0
  );

alter table public.announcements
  drop constraint if exists announcements_featured_until_valid;

alter table public.announcements
  add constraint announcements_featured_until_valid
  check (
    featured_until is null
    or featured = true
  );

comment on column public.announcements.content_type is
  'Publication type: operational announcement or institutional news.';

comment on column public.announcements.news_category is
  'Optional editorial category used by institutional news.';

comment on column public.announcements.featured is
  'Whether a news publication should receive prominent visual placement.';

comment on column public.announcements.featured_until is
  'Optional UTC time until which a publication remains featured.';

create index if not exists
  announcements_content_type_status_published_idx
on public.announcements(
  content_type,
  status,
  published_at desc
);

create index if not exists
  announcements_featured_published_idx
on public.announcements(
  featured,
  published_at desc
)
where featured = true;

create index if not exists
  announcements_news_category_idx
on public.announcements(news_category)
where news_category is not null;

-- ============================================================
-- Managed publication assets
-- ============================================================

create table if not exists public.publication_assets (
  id uuid primary key default gen_random_uuid(),

  publication_id uuid not null
    references public.announcements(id)
    on update cascade
    on delete cascade,

  asset_type text not null,

  storage_bucket text not null
    default 'institutional-publications',

  storage_path text not null,

  original_name text not null,
  mime_type text not null,
  size_bytes bigint not null,

  display_order integer not null default 0,

  uploaded_by uuid not null
    references public.profiles(id)
    on update cascade
    on delete restrict,

  created_at timestamptz not null
    default timezone('utc', now()),

  updated_at timestamptz not null
    default timezone('utc', now()),

  constraint publication_assets_type_valid
    check (
      asset_type in (
        'cover',
        'image',
        'attachment'
      )
    ),

  constraint publication_assets_bucket_not_blank
    check (length(trim(storage_bucket)) > 0),

  constraint publication_assets_path_not_blank
    check (length(trim(storage_path)) > 0),

  constraint publication_assets_original_name_not_blank
    check (length(trim(original_name)) > 0),

  constraint publication_assets_mime_type_not_blank
    check (length(trim(mime_type)) > 0),

  constraint publication_assets_size_valid
    check (
      size_bytes > 0
      and size_bytes <= 26214400
    ),

  constraint publication_assets_display_order_valid
    check (display_order >= 0),

  constraint publication_assets_storage_object_unique
    unique (storage_bucket, storage_path)
);

comment on table public.publication_assets is
  'Managed cover images, gallery images and document attachments '
  'for announcements and institutional news.';

comment on column public.publication_assets.storage_path is
  'Private Supabase Storage object path; not a permanent public URL.';

comment on column public.publication_assets.size_bytes is
  'Validated file size. Maximum 25 MiB per asset.';

create index if not exists
  publication_assets_publication_idx
on public.publication_assets(
  publication_id,
  asset_type,
  display_order
);

create index if not exists
  publication_assets_uploaded_by_idx
on public.publication_assets(uploaded_by);

create unique index if not exists
  publication_assets_one_cover_idx
on public.publication_assets(publication_id)
where asset_type = 'cover';

drop trigger if exists publication_assets_set_updated_at
  on public.publication_assets;

create trigger publication_assets_set_updated_at
before update on public.publication_assets
for each row
execute function public.set_updated_at();

-- ============================================================
-- Asset authorization helper
-- ============================================================

create or replace function public.can_manage_publication_assets(
  p_user_id uuid,
  p_publication_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    p_user_id is not null
    and exists (
      select 1
      from public.profiles as profile
      where profile.id = p_user_id
        and profile.active = true
        and profile.role in ('admin', 'superAdmin')
    )
    and exists (
      select 1
      from public.announcements as publication
      where publication.id = p_publication_id
    );
$$;

revoke all on function public.can_manage_publication_assets(
  uuid,
  uuid
) from public;

grant execute on function public.can_manage_publication_assets(
  uuid,
  uuid
) to authenticated;

-- ============================================================
-- RLS
-- ============================================================

alter table public.publication_assets enable row level security;

drop policy if exists
  publication_assets_select_visible
on public.publication_assets;

create policy publication_assets_select_visible
on public.publication_assets
for select
to authenticated
using (
  public.announcement_is_visible_to_user(
    publication_id,
    auth.uid()
  )
  or public.is_admin()
);

drop policy if exists
  publication_assets_insert_managers
on public.publication_assets;

create policy publication_assets_insert_managers
on public.publication_assets
for insert
to authenticated
with check (
  uploaded_by = auth.uid()
  and public.can_manage_publication_assets(
    auth.uid(),
    publication_id
  )
);

drop policy if exists
  publication_assets_update_managers
on public.publication_assets;

create policy publication_assets_update_managers
on public.publication_assets
for update
to authenticated
using (
  public.can_manage_publication_assets(
    auth.uid(),
    publication_id
  )
)
with check (
  public.can_manage_publication_assets(
    auth.uid(),
    publication_id
  )
);

drop policy if exists
  publication_assets_delete_managers
on public.publication_assets;

create policy publication_assets_delete_managers
on public.publication_assets
for delete
to authenticated
using (
  public.can_manage_publication_assets(
    auth.uid(),
    publication_id
  )
);

-- Direct anonymous access is never required.
revoke all on table public.publication_assets from anon;

grant select, insert, update, delete
on table public.publication_assets
to authenticated;

-- Explicitly classify all historic rows.
update public.announcements
set content_type = 'announcement'
where content_type is null;

commit;
