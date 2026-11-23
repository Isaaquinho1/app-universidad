BEGIN;

DO $preflight$
BEGIN
  IF md5(pg_get_functiondef(
    'public.handle_new_auth_user()'::regprocedure
  )) <> 'a2e9dd5f1fb4a6c1d9f40442a130eca8' THEN
    RAISE EXCEPTION
      'La funcion original ha cambiado; despliegue detenido';
  END IF;
END;
$preflight$;

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  normalized_email text;
  local_part text;
  detected_account_type text;
  detected_control_number text;
  approval_pending boolean;

  metadata_display_name text;
  metadata_career_id text;
  metadata_group_id text;
  metadata_semester smallint;

  selected_group public.academic_groups%rowtype;
  academic_data_complete boolean;
begin
  normalized_email := lower(trim(coalesce(new.email, '')));
  local_part := split_part(normalized_email, '@', 1);

  -- Account classification is authoritative and server-side.
  if normalized_email ~ '^l[0-9]{9}@tlalpan\.tecnm\.mx$' then
    detected_account_type := 'student';
    detected_control_number := substring(local_part from 2);
    approval_pending := false;

  elsif normalized_email ~ '^[a-z0-9._%+-]+@tlalpan\.tecnm\.mx$' then
    detected_account_type := 'campusStaff';
    detected_control_number := null;
    approval_pending := true;

  elsif normalized_email ~ '^[a-z0-9._%+-]+@tecnm\.mx$' then
    detected_account_type := 'tecnmStaff';
    detected_control_number := null;
    approval_pending := true;

  else
    raise exception
      'Unsupported institutional email domain: %',
      normalized_email
      using errcode = 'check_violation';
  end if;

  metadata_display_name := nullif(
    trim(
      coalesce(
        new.raw_user_meta_data ->> 'display_name',
        new.raw_user_meta_data ->> 'name',
        ''
      )
    ),
    ''
  );

  -- Academic metadata is accepted only for student accounts.
  if detected_account_type = 'student' then
    metadata_career_id := nullif(
      lower(trim(coalesce(
        new.raw_user_meta_data ->> 'careerId',
        new.raw_user_meta_data ->> 'career_id',
        ''
      ))),
      ''
    );

    metadata_group_id := nullif(
      trim(coalesce(
        new.raw_user_meta_data ->> 'groupId',
        new.raw_user_meta_data ->> 'group_id',
        ''
      )),
      ''
    );

    begin
      metadata_semester := nullif(
        trim(coalesce(new.raw_user_meta_data ->> 'semester', '')),
        ''
      )::smallint;
    exception
      when invalid_text_representation or numeric_value_out_of_range then
        raise exception 'Invalid semester metadata'
          using errcode = 'check_violation';
    end;

    if metadata_semester is not null
       and (metadata_semester < 1 or metadata_semester > 14) then
      raise exception 'Semester must be between 1 and 14'
        using errcode = 'check_violation';
    end if;

    if metadata_career_id is not null
       and not exists (
         select 1
         from public.careers
         where id = metadata_career_id
           and active = true
       ) then
      raise exception 'Invalid or inactive career'
        using errcode = 'foreign_key_violation';
    end if;

    if metadata_group_id is not null then
      select *
      into selected_group
      from public.academic_groups
      where id = metadata_group_id;

      if selected_group.id is null then
        raise exception 'Invalid or inactive academic group'
          using errcode = 'foreign_key_violation';
      end if;

      if metadata_career_id is null
         or selected_group.career_id is distinct from metadata_career_id then
        raise exception 'Academic group does not belong to selected career'
          using errcode = 'check_violation';
      end if;

      if metadata_semester is null
         or selected_group.semester is distinct from metadata_semester then
        raise exception 'Academic group does not belong to selected semester'
          using errcode = 'check_violation';
      end if;
    end if;


    -- Oferta academica correspondiente a la fecha
    -- institucional de Ciudad de Mexico.
    --
    -- El grupo es obligatorio cuando hay grupos
    -- ofertados para la carrera y semestre.
    -- Sin oferta se permite una asignacion pendiente.

    if metadata_career_id is not null
       and metadata_semester is not null then

      if (
        select count(*)
        from public.academic_periods as period
        where
          (now() at time zone 'America/Mexico_City')::date
            between period.starts_on and period.ends_on
      ) > 1 then
        raise exception
          'Overlapping academic offering periods'
          using errcode = '23514';
      end if;

      if metadata_group_id is not null then

        if not exists (
          select 1
          from public.academic_group_offerings as offering
          join public.academic_periods as period
            on period.id = offering.academic_period_id
          where offering.group_id = metadata_group_id
            and offering.is_offered = true
            and
              (now() at time zone 'America/Mexico_City')::date
                between period.starts_on and period.ends_on
        ) then
          raise exception
            'Academic group is not offered in current period'
            using errcode = '23514';
        end if;

      else

        if exists (
          select 1
          from public.academic_group_offerings as offering
          join public.academic_groups as academic_group
            on academic_group.id = offering.group_id
          join public.academic_periods as period
            on period.id = offering.academic_period_id
          where academic_group.career_id = metadata_career_id
            and academic_group.semester = metadata_semester
            and offering.is_offered = true
            and
              (now() at time zone 'America/Mexico_City')::date
                between period.starts_on and period.ends_on
        ) then
          raise exception
            'Academic group selection is required'
            using errcode = '23514';
        end if;

      end if;
    elsif metadata_group_id is not null then
      raise exception
        'Career and semester are required for group assignment'
        using errcode = '23514';
    end if;

    academic_data_complete :=
      metadata_display_name is not null
      and metadata_career_id is not null
      and metadata_semester is not null
      and metadata_group_id is not null;
  else
    -- Staff accounts must not carry student segmentation metadata.
    metadata_career_id := null;
    metadata_semester := null;
    metadata_group_id := null;

    academic_data_complete := metadata_display_name is not null;
  end if;

  insert into public.profiles (
    id,
    email,
    display_name,
    role,
    career_id,
    semester,
    group_id,
    control_number,
    account_type,
    staff_approval_pending,
    profile_completed,
    active
  )
  values (
    new.id,
    nullif(normalized_email, ''),
    metadata_display_name,

    -- Safe provisional role. Privileged roles require trusted authorization.
    'student',

    metadata_career_id,
    metadata_semester,
    metadata_group_id,
    detected_control_number,
    detected_account_type,
    approval_pending,
    academic_data_complete,
    true
  )
  on conflict (id) do update
  set
    email = excluded.email,
    display_name = coalesce(
      public.profiles.display_name,
      excluded.display_name
    ),
    career_id = coalesce(
      public.profiles.career_id,
      excluded.career_id
    ),
    semester = coalesce(
      public.profiles.semester,
      excluded.semester
    ),
    group_id = coalesce(
      public.profiles.group_id,
      excluded.group_id
    ),
    control_number = coalesce(
      public.profiles.control_number,
      excluded.control_number
    ),
    account_type = excluded.account_type,
    staff_approval_pending =
      public.profiles.staff_approval_pending
      or excluded.staff_approval_pending,
    profile_completed =
      public.profiles.profile_completed
      or excluded.profile_completed,
    updated_at = timezone('utc', now());

  return new;
end;
$function$;

DO $verify$
DECLARE
  installed text;
BEGIN
  SELECT pg_get_functiondef(
    'public.handle_new_auth_user()'::regprocedure
  )
  INTO installed;

  IF installed NOT LIKE '%academic_group_offerings%' THEN
    RAISE EXCEPTION 'Falta validacion de oferta';
  END IF;

  IF installed NOT LIKE '%Academic group selection is required%' THEN
    RAISE EXCEPTION 'Falta validacion de seleccion';
  END IF;

  IF installed NOT LIKE '%selected_group.career_id%' THEN
    RAISE EXCEPTION 'Falta validacion de carrera';
  END IF;

  IF installed NOT LIKE '%selected_group.semester%' THEN
    RAISE EXCEPTION 'Falta validacion de semestre';
  END IF;

  IF NOT (
    SELECT prosecdef
    FROM pg_proc
    WHERE oid = 'public.handle_new_auth_user()'::regprocedure
  ) THEN
    RAISE EXCEPTION 'SECURITY DEFINER missing';
  END IF;

  RAISE NOTICE 'PASS: validaciones de registro instaladas';
END;
$verify$;

COMMIT;
