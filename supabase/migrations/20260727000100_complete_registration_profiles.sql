-- Conecta ITT
-- Completes institutional profiles from trusted registration metadata.
--
-- The account type is always inferred from the normalized email.
-- Roles are never accepted from client metadata.

begin;

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
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
      where id = metadata_group_id
        and active = true;

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
$$;

comment on function public.handle_new_auth_user() is
  'Creates a safe institutional profile, infers account type from email, '
  'and validates optional student academic metadata.';

commit;
