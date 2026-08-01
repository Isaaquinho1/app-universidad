-- Conecta ITT
-- Administrative review workflow for institutional profile photographs.

begin;

-- ============================================================
-- Administrative review queue
-- ============================================================

create or replace function public.get_profile_photo_review_queue(
  p_status text default 'pending'
)
returns setof public.profiles
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  normalized_status text;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required'
      using errcode = 'insufficient_privilege';
  end if;

  if not public.is_admin() then
    raise exception 'Only administrators can review profile photographs'
      using errcode = 'insufficient_privilege';
  end if;

  normalized_status := lower(trim(coalesce(p_status, 'pending')));

  if normalized_status not in (
    'pending',
    'approved',
    'rejected',
    'all'
  ) then
    raise exception 'Invalid photograph review status'
      using errcode = 'invalid_parameter_value';
  end if;

  return query
  select profile.*
  from public.profiles as profile
  where
    profile.photo_path is not null
    and length(trim(profile.photo_path)) > 0
    and (
      normalized_status = 'all'
      or profile.photo_status = normalized_status
    )
  order by
    case
      when profile.photo_status = 'pending' then 0
      when profile.photo_status = 'rejected' then 1
      else 2
    end,
    profile.photo_updated_at asc nulls last,
    profile.display_name asc nulls last;
end;
$$;

comment on function public.get_profile_photo_review_queue(text) is
  'Returns private institutional photograph submissions visible to admin and superAdmin users.';

revoke all on function public.get_profile_photo_review_queue(text)
from public;

grant execute on function public.get_profile_photo_review_queue(text)
to authenticated;

-- ============================================================
-- Administrative approval or rejection
-- ============================================================

create or replace function public.review_profile_photo(
  p_profile_id uuid,
  p_decision text,
  p_rejection_reason text default null
)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  reviewer_id uuid;
  normalized_decision text;
  normalized_reason text;
  reviewed_profile public.profiles;
begin
  reviewer_id := (select auth.uid());

  if reviewer_id is null then
    raise exception 'Authentication required'
      using errcode = 'insufficient_privilege';
  end if;

  if not public.is_admin() then
    raise exception 'Only administrators can review profile photographs'
      using errcode = 'insufficient_privilege';
  end if;

  if p_profile_id is null then
    raise exception 'A profile identifier is required'
      using errcode = 'not_null_violation';
  end if;

  normalized_decision := lower(trim(coalesce(p_decision, '')));
  normalized_reason := nullif(trim(coalesce(p_rejection_reason, '')), '');

  if normalized_decision not in ('approved', 'rejected') then
    raise exception 'The decision must be approved or rejected'
      using errcode = 'invalid_parameter_value';
  end if;

  if normalized_decision = 'rejected'
     and normalized_reason is null then
    raise exception 'A rejection reason is required'
      using errcode = 'not_null_violation';
  end if;

  if normalized_reason is not null
     and length(normalized_reason) > 500 then
    raise exception 'The rejection reason cannot exceed 500 characters'
      using errcode = 'string_data_right_truncation';
  end if;

  update public.profiles
  set
    photo_status = normalized_decision,
    photo_reviewed_at = timezone('utc', now()),
    photo_reviewed_by = reviewer_id,
    photo_rejection_reason =
      case
        when normalized_decision = 'rejected'
          then normalized_reason
        else null
      end,
    updated_at = timezone('utc', now())
  where id = p_profile_id
    and photo_status = 'pending'
    and photo_path is not null
    and length(trim(photo_path)) > 0
  returning *
  into reviewed_profile;

  if reviewed_profile.id is null then
    raise exception
      'The photograph is no longer pending or the profile was not found'
      using errcode = 'no_data_found';
  end if;

  return reviewed_profile;
end;
$$;

comment on function public.review_profile_photo(uuid, text, text) is
  'Approves or rejects one pending institutional profile photograph and records its reviewer.';

revoke all on function public.review_profile_photo(uuid, text, text)
from public;

grant execute on function public.review_profile_photo(uuid, text, text)
to authenticated;

commit;
