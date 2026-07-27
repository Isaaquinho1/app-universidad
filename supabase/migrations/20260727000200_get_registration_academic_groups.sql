-- Conecta ITT
-- Public registration catalog for active academic groups.
--
-- Allows unauthenticated registration screens to retrieve only the
-- active group identifiers required for a selected career and semester.

begin;

create or replace function public.get_registration_academic_groups(
  p_career_id text,
  p_semester smallint
)
returns table (
  id text,
  career_id text,
  name text,
  semester smallint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_career_id is null or length(trim(p_career_id)) = 0 then
    return;
  end if;

  if p_semester is null or p_semester < 1 or p_semester > 14 then
    return;
  end if;

  return query
  select
    academic_group.id,
    academic_group.career_id,
    academic_group.name,
    academic_group.semester
  from public.academic_groups as academic_group
  inner join public.careers as career
    on career.id = academic_group.career_id
  where academic_group.career_id = lower(trim(p_career_id))
    and academic_group.semester = p_semester
    and academic_group.active = true
    and career.active = true
  order by academic_group.name;
end;
$$;

comment on function public.get_registration_academic_groups(text, smallint) is
  'Returns active academic groups for registration without exposing the '
  'academic_groups table directly.';

revoke all on function public.get_registration_academic_groups(
  text,
  smallint
) from public;

grant execute on function public.get_registration_academic_groups(
  text,
  smallint
) to anon;

grant execute on function public.get_registration_academic_groups(
  text,
  smallint
) to authenticated;

commit;
