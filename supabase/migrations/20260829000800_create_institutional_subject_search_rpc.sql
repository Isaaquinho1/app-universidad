-- ============================================================
-- Conecta ITT
-- Administrative institutional subject search
-- ============================================================

begin;

create or replace function public.search_institutional_subjects_as_admin(
  p_query text default null,
  p_include_inactive boolean default false,
  p_limit integer default 100
)
returns table (
  id uuid,
  code text,
  name text,
  active boolean,
  created_at timestamptz,
  updated_at timestamptz
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
      least(coalesce(p_limit, 100), 250)
    );

  return query
  select
    subject.id,
    subject.code,
    subject.name,
    subject.active,
    subject.created_at,
    subject.updated_at
  from public.institutional_subjects as subject
  where
    (
      p_include_inactive
      or subject.active = true
    )
    and (
      normalized_query is null
      or subject.code ilike '%' || normalized_query || '%'
      or subject.name ilike '%' || normalized_query || '%'
    )
  order by
    subject.active desc,
    subject.name,
    subject.code nulls last
  limit effective_limit;
end;
$$;

revoke all
on function public.search_institutional_subjects_as_admin(
  text,
  boolean,
  integer
)
from public;

grant execute
on function public.search_institutional_subjects_as_admin(
  text,
  boolean,
  integer
)
to authenticated;

comment on function public.search_institutional_subjects_as_admin(
  text,
  boolean,
  integer
) is
  'Searches the institutional subject catalog for admin and superAdmin users.';

commit;
