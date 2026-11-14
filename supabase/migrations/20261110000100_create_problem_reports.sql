-- Conecta ITT: reportes de problemas
-- REVISAR en un entorno seguro antes de aplicar a producción.

create table if not exists public.problem_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  category text not null
    check (category in (
      'app_error', 'account', 'notifications', 'academic', 'other'
    )),
  description text not null
    check (
      char_length(btrim(description)) between 20 and 2000
    ),
  steps_to_reproduce text
    check (
      steps_to_reproduce is null or
      char_length(steps_to_reproduce) <= 1500
    ),
  status text not null default 'pending'
    check (status in ('pending', 'in_review', 'resolved')),
  admin_response text
    check (
      admin_response is null or
      char_length(admin_response) <= 2000
    ),
  handled_by uuid references auth.users(id) on delete set null,
  handled_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists problem_reports_reporter_idx
  on public.problem_reports(reporter_id, created_at desc);

create index if not exists problem_reports_status_idx
  on public.problem_reports(status, created_at desc);

alter table public.problem_reports enable row level security;

-- Los clientes pueden consultar reportes, pero solo insertar
-- las columnas expresamente autorizadas.
revoke all on public.problem_reports from public, anon, authenticated;

grant select on public.problem_reports to authenticated;

grant insert (
  category,
  description,
  steps_to_reproduce
) on public.problem_reports to authenticated;

-- Los cambios de estado se implementarán mediante una
-- operación administrativa segura y auditada.
-- No otorgar UPDATE directamente a clientes móviles.

create policy "Reporters can create own reports"
on public.problem_reports for insert
to authenticated
with check (
  reporter_id = (select auth.uid())
  and status = 'pending'
  and admin_response is null
);

create policy "Reporters can read own reports"
on public.problem_reports for select
to authenticated
using (reporter_id = (select auth.uid()));

create policy "Administrators can read reports"
on public.problem_reports for select
to authenticated
using ((select public.is_admin()));

-- ============================================================
-- Administración segura de reportes
-- ============================================================

create or replace function public.review_problem_report(
  p_report_id uuid,
  p_status text,
  p_admin_response text default null
)
returns public.problem_reports
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  normalized_status text;
  normalized_response text;
  updated_report public.problem_reports;
begin
  actor_id := (select auth.uid());

  if actor_id is null or not public.is_admin() then
    raise exception 'Administrator authorization required'
      using errcode = 'insufficient_privilege';
  end if;

  if p_report_id is null then
    raise exception 'Report identifier is required'
      using errcode = 'invalid_parameter_value';
  end if;

  normalized_status := lower(trim(coalesce(p_status, '')));
  normalized_response := nullif(trim(coalesce(p_admin_response, '')), '');

  if normalized_status not in ('pending', 'in_review', 'resolved') then
    raise exception 'Invalid report status'
      using errcode = 'invalid_parameter_value';
  end if;

  if char_length(coalesce(normalized_response, '')) > 2000 then
    raise exception 'Administrator response exceeds 2000 characters'
      using errcode = 'check_violation';
  end if;

  update public.problem_reports
  set
    status = normalized_status,
    admin_response = normalized_response,
    handled_by = actor_id,
    handled_at = timezone('utc', now())
  where id = p_report_id
  returning * into updated_report;

  if updated_report.id is null then
    raise exception 'Report not found'
      using errcode = 'no_data_found';
  end if;

  return updated_report;
end;
$$;

revoke all on function public.review_problem_report(
  uuid, text, text
) from public;

grant execute on function public.review_problem_report(
  uuid, text, text
) to authenticated;

comment on function public.review_problem_report(uuid, text, text) is
  'Allows active institutional administrators to review problem reports without direct table update privileges.';
