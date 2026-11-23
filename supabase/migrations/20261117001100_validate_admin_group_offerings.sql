BEGIN;

CREATE OR REPLACE FUNCTION public.update_student_academic_profile_as_admin(p_user_id uuid, p_career_id text, p_semester smallint, p_group_id text DEFAULT NULL::text)
 RETURNS profiles
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  actor_id uuid;
  target_profile public.profiles;
  selected_group public.academic_groups;
  updated_profile public.profiles;
  normalized_career_id text;
  normalized_group_id text;
begin
  actor_id := (select auth.uid());

  if actor_id is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  if not public.is_admin() then
    raise exception 'Admin privileges required'
      using errcode = '42501';
  end if;

  if p_user_id is null then
    raise exception 'Target user is required'
      using errcode = '22004';
  end if;

  normalized_career_id := nullif(trim(coalesce(p_career_id, '')), '');
  normalized_group_id := nullif(trim(coalesce(p_group_id, '')), '');

  if normalized_career_id is null then
    raise exception 'Career is required'
      using errcode = '22023';
  end if;

  if p_semester is null or p_semester < 1 or p_semester > 14 then
    raise exception 'Semester must be between 1 and 14'
      using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public.careers
    where id = normalized_career_id
      and active = true
  ) then
    raise exception 'Invalid or inactive career'
      using errcode = '23503';
  end if;

  select *
  into target_profile
  from public.profiles
  where id = p_user_id
  for update;

  if not found then
    raise exception 'Institutional profile not found'
      using errcode = 'P0002';
  end if;

  if target_profile.role <> 'student' then
    raise exception
      'Academic identity can only be changed for student accounts'
      using errcode = '42501';
  end if;

  if not target_profile.active then
    raise exception 'Student profile is inactive'
      using errcode = '42501';
  end if;

  if normalized_group_id is not null then
    select *
    into selected_group
    from public.academic_groups
    where id = normalized_group_id;

    if not found then
      raise exception 'Invalid or inactive academic group'
        using errcode = '23503';
    end if;

    if selected_group.career_id is distinct from normalized_career_id then
      raise exception
        'Academic group does not belong to selected career'
        using errcode = '23514';
    end if;

    if selected_group.semester is distinct from p_semester then
      raise exception
        'Academic group does not belong to selected semester'
        using errcode = '23514';
    end if;
  end if;


  -- Solo validar oferta cuando se asigna un grupo nuevo
  -- o cambia la ubicacion academica.
  -- La asignacion historica sin cambios se conserva.
  if normalized_group_id is not null
     and (
       target_profile.group_id is distinct from normalized_group_id
       or target_profile.career_id is distinct from normalized_career_id
       or target_profile.semester is distinct from p_semester
     ) then

    if (
      select count(*)
      from public.academic_periods as period
      where
        (now() at time zone 'America/Mexico_City')::date
        between period.starts_on and period.ends_on
    ) <> 1 then
      raise exception
        'No unique academic offering period is configured'
        using errcode = '23514';
    end if;

    if not exists (
      select 1
      from public.academic_group_offerings as offering
      join public.academic_periods as period
        on period.id = offering.academic_period_id
      where offering.group_id = normalized_group_id
        and offering.is_offered = true
        and
          (now() at time zone 'America/Mexico_City')::date
          between period.starts_on and period.ends_on
    ) then
      raise exception
        'Academic group is not offered in the current period'
        using errcode = '23514';
    end if;
  end if;

  if target_profile.career_id is not distinct from normalized_career_id
     and target_profile.semester is not distinct from p_semester
     and target_profile.group_id is not distinct from normalized_group_id then
    return target_profile;
  end if;

  update public.profiles
  set
    career_id = normalized_career_id,
    semester = p_semester,
    group_id = normalized_group_id,
    profile_completed = true,
    updated_at = timezone('utc', now())
  where id = p_user_id
  returning *
  into updated_profile;

  insert into public.student_academic_profile_change_audit (
    actor_user_id,
    target_user_id,
    previous_career_id,
    new_career_id,
    previous_semester,
    new_semester,
    previous_group_id,
    new_group_id
  )
  values (
    actor_id,
    p_user_id,
    target_profile.career_id,
    updated_profile.career_id,
    target_profile.semester,
    updated_profile.semester,
    target_profile.group_id,
    updated_profile.group_id
  );

  return updated_profile;
end;
$function$;


REVOKE ALL ON FUNCTION public.update_student_academic_profile_as_admin(uuid,text,smallint,text)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.update_student_academic_profile_as_admin(uuid,text,smallint,text)
TO authenticated;

DO $check$
DECLARE
  function_id oid;
  installed_definition text;
BEGIN
  function_id := 'public.update_student_academic_profile_as_admin(uuid,text,smallint,text)'::regprocedure;

  SELECT pg_get_functiondef(function_id)
  INTO installed_definition;

  IF NOT (
    SELECT prosecdef
    FROM pg_proc
    WHERE oid = function_id
  ) THEN
    RAISE EXCEPTION 'SECURITY DEFINER missing';
  END IF;

  IF has_function_privilege(
    'anon', function_id, 'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'Anonymous access not allowed';
  END IF;

  IF NOT has_function_privilege(
    'authenticated', function_id, 'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'Authenticated access missing';
  END IF;

  IF installed_definition NOT LIKE
     '%academic_group_offerings%' THEN
    RAISE EXCEPTION 'Offering validation missing';
  END IF;

  IF installed_definition NOT LIKE
     '%student_academic_profile_change_audit%' THEN
    RAISE EXCEPTION 'Original audit missing';
  END IF;

  RAISE NOTICE 'PASS: funcion administrativa verificada';
END;
$check$;

COMMIT;
