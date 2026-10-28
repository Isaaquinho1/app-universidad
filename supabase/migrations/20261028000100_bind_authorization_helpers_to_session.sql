-- Conecta ITT
-- Bloque 15.4AO: vincular helpers a la identidad de sesión.
-- Preservar firmas, SECURITY DEFINER y permisos existentes.
-- Revisar contra las definiciones vigentes antes de aplicar.

begin;

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
    p_user_id = (select auth.uid())
    and (
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
    and p_user_id = (select auth.uid())
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

commit;
