begin;

create or replace function public.get_announcement_results(
  p_announcement_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  announcement_record public.announcements;
  result jsonb;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required'
      using errcode = 'insufficient_privilege';
  end if;

  if not public.is_admin() then
    raise exception 'Only administrators can view announcement results'
      using errcode = 'insufficient_privilege';
  end if;

  if p_announcement_id is null then
    raise exception 'Announcement identifier is required'
      using errcode = 'invalid_parameter_value';
  end if;

  select *
  into announcement_record
  from public.announcements
  where id = p_announcement_id;

  if not found then
    raise exception 'Announcement not found'
      using errcode = 'no_data_found';
  end if;

  with audience as (
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
    where profile.active = true
      and (
        announcement_record.all_users

        or exists (
          select 1
          from public.announcement_targets target
          where target.announcement_id = p_announcement_id
            and target.user_id = profile.id
        )

        or (
          exists (
            select 1
            from public.announcement_targets target
            where target.announcement_id = p_announcement_id
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
              where target.announcement_id = p_announcement_id
                and target.role is not null
            )
            or exists (
              select 1
              from public.announcement_targets target
              where target.announcement_id = p_announcement_id
                and target.role = profile.role
            )
          )

          and (
            not exists (
              select 1
              from public.announcement_targets target
              where target.announcement_id = p_announcement_id
                and target.career_id is not null
            )
            or exists (
              select 1
              from public.announcement_targets target
              where target.announcement_id = p_announcement_id
                and target.career_id = profile.career_id
            )
          )

          and (
            not exists (
              select 1
              from public.announcement_targets target
              where target.announcement_id = p_announcement_id
                and target.semester is not null
            )
            or exists (
              select 1
              from public.announcement_targets target
              where target.announcement_id = p_announcement_id
                and target.semester = profile.semester
            )
          )

          and (
            not exists (
              select 1
              from public.announcement_targets target
              where target.announcement_id = p_announcement_id
                and target.group_id is not null
            )
            or exists (
              select 1
              from public.announcement_targets target
              where target.announcement_id = p_announcement_id
                and target.group_id = profile.group_id
            )
          )
        )
      )
  ),
  audience_with_receipts as (
    select
      audience.*,
      receipt.status,
      receipt.receipt_version,
      receipt.delivered_at,
      receipt.seen_at,
      receipt.read_at,
      receipt.confirmed_at,
      receipt.updated_at,

      case
        when receipt.announcement_id is null then 'pending'
        when receipt.receipt_version
             < announcement_record.content_version then 'edited'
        else receipt.status
      end as effective_status

    from audience
    left join public.announcement_receipts receipt
      on receipt.announcement_id = p_announcement_id
     and receipt.user_id = audience.id
  ),
  counts as (
    select
      count(*)::integer as audience_total,

      count(*) filter (
        where effective_status = 'pending'
      )::integer as pending_count,

      count(*) filter (
        where effective_status = 'edited'
      )::integer as edited_count,

      count(*) filter (
        where effective_status = 'delivered'
      )::integer as delivered_count,

      count(*) filter (
        where effective_status = 'seen'
      )::integer as seen_count,

      count(*) filter (
        where effective_status = 'read'
      )::integer as read_count,

      count(*) filter (
        where effective_status = 'confirmed'
      )::integer as confirmed_count

    from audience_with_receipts
  )
  select jsonb_build_object(
    'announcement_id', announcement_record.id,
    'title', announcement_record.title,
    'status', announcement_record.status,
    'content_version', announcement_record.content_version,
    'published_at', announcement_record.published_at,
    'updated_at', announcement_record.updated_at,

    'summary', jsonb_build_object(
      'audience_total', counts.audience_total,
      'pending', counts.pending_count,
      'edited', counts.edited_count,
      'delivered', counts.delivered_count,
      'seen', counts.seen_count,
      'read', counts.read_count,
      'confirmed', counts.confirmed_count
    ),

    'recipients', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'user_id', recipient.id,
            'email', recipient.email,
            'display_name', recipient.display_name,
            'role', recipient.role,
            'career_id', recipient.career_id,
            'semester', recipient.semester,
            'group_id', recipient.group_id,
            'control_number', recipient.control_number,
            'status', recipient.effective_status,
            'receipt_version', recipient.receipt_version,
            'delivered_at', recipient.delivered_at,
            'seen_at', recipient.seen_at,
            'read_at', recipient.read_at,
            'confirmed_at', recipient.confirmed_at,
            'updated_at', recipient.updated_at
          )
          order by
            case recipient.effective_status
              when 'pending' then 0
              when 'edited' then 1
              when 'delivered' then 2
              when 'seen' then 3
              when 'read' then 4
              when 'confirmed' then 5
              else 6
            end,
            recipient.control_number nulls last,
            recipient.display_name nulls last
        )
        from audience_with_receipts recipient
      ),
      '[]'::jsonb
    )
  )
  into result
  from counts;

  return result;
end;
$$;

revoke all on function public.get_announcement_results(uuid)
from public;

grant execute on function public.get_announcement_results(uuid)
to authenticated;

commit;
