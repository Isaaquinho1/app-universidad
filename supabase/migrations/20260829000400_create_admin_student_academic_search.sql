-- ============================================================
-- Administrative student academic search
-- ============================================================
--
-- Provides admin and superAdmin users with the minimum
-- institutional data required to manage student academic
-- identity.
-- ============================================================

create or replace function public.search_student_academic_profiles_as_admin(
  p_query text default null,
  p_limit integer default 50
)
returns table (
  id uuid,
  email text,
  display_name text,
  control_number text,
  career_id text,
  semester smallint,
  group_id text,
  active boolean,
  profile_completed boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  normalized_query text;
  effective_limit integer;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  if not public.is_admin() then
    raise exception 'Admin privileges required'
      using errcode = '42501';
  end if;

  normalized_query :=
    nullif(trim(coalesce(p_query, '')), '');

  effective_limit :=
    greatest(
      1,
      least(coalesce(p_limit, 50), 100)
    );

  return query
  select
    profile.id,
    profile.email,
    profile.display_name,
    profile.control_number,
    profile.career_id,
    profile.semester,
    profile.group_id,
    profile.active,
    profile.profile_completed
  from public.profiles as profile
  where profile.role = 'student'
    and (
      normalized_query is null
      or profile.email ilike '%' || normalized_query || '%'
      or profile.display_name ilike '%' || normalized_query || '%'
      or profile.control_number ilike '%' || normalized_query || '%'
    )
  order by
    profile.display_name nulls last,
    profile.control_number nulls last,
    profile.email nulls last
  limit effective_limit;
end;
$$;

revoke all
on function public.search_student_academic_profiles_as_admin(
  text,
  integer
)
from public;

grant execute
on function public.search_student_academic_profiles_as_admin(
  text,
  integer
)
to authenticated;

comment on function public.search_student_academic_profiles_as_admin(
  text,
  integer
) is
  'Searches student academic profiles for authenticated admin and superAdmin users.';
