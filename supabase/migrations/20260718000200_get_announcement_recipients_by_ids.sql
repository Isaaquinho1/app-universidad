begin;

create or replace function public.get_announcement_recipients_by_ids(
  p_user_ids jsonb
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
    raise exception 'Only administrators can read announcement recipients'
      using errcode = 'insufficient_privilege';
  end if;

  if p_user_ids is null then
    return;
  end if;

  if jsonb_typeof(p_user_ids) <> 'array' then
    raise exception 'p_user_ids must be a JSON array'
      using errcode = 'invalid_parameter_value';
  end if;

  return query
  select jsonb_build_object(
    'id', profile.id,
    'email', profile.email,
    'display_name', profile.display_name,
    'role', profile.role,
    'career_id', profile.career_id,
    'semester', profile.semester,
    'group_id', profile.group_id,
    'control_number', profile.control_number
  )
  from public.profiles profile
  where profile.active = true
    and profile.id in (
      select value::uuid
      from jsonb_array_elements_text(p_user_ids)
    )
  order by
    profile.control_number nulls last,
    profile.display_name nulls last,
    profile.email nulls last;
end;
$$;

revoke all on function public.get_announcement_recipients_by_ids(
  jsonb
) from public;

grant execute on function public.get_announcement_recipients_by_ids(
  jsonb
) to authenticated;

commit;
