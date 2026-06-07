begin;

do $$
begin
  if exists (select 1 from public.patients where access_status_id is null or access_level_id is null) then
    raise exception 'patients still has null access_status_id/access_level_id';
  end if;

  if exists (select 1 from public.consultations where consultation_type_id is null or consultation_status_id is null) then
    raise exception 'consultations still has null consultation_type_id/consultation_status_id';
  end if;

  if exists (select 1 from public.materials where access_level_id is null) then
    raise exception 'materials still has null access_level_id';
  end if;

  if exists (select 1 from public.material_views where read_status_id is null) then
    raise exception 'material_views still has null read_status_id';
  end if;

  if exists (select 1 from public.tests where test_type_id is null or access_level_id is null) then
    raise exception 'tests still has null test_type_id/access_level_id';
  end if;

  if exists (select 1 from public.test_attempts where attempt_status_id is null) then
    raise exception 'test_attempts still has null attempt_status_id';
  end if;

  if exists (select 1 from public.events where event_format_id is null or event_category_id is null or event_status_id is null) then
    raise exception 'events still has null event_format_id/event_category_id/event_status_id';
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'event_moderation'
      and column_name in ('moderation_type_id', 'moderation_decision_id')
    group by table_name
    having count(*) = 2
  ) and exists (
    select 1
    from public.event_moderation
    where moderation_type_id is null or moderation_decision_id is null
  ) then
    raise exception 'event_moderation still has null moderation_type_id/moderation_decision_id';
  end if;

  if exists (select 1 from public.event_requests where request_status_id is null) then
    raise exception 'event_requests still has null request_status_id';
  end if;
end $$;

alter table if exists public.patients
  alter column access_status_id set not null,
  alter column access_level_id set not null,
  drop column if exists access_status,
  drop column if exists access_level,
  drop column if exists profile_status;

alter table if exists public.specialists
  drop column if exists activity_status;

alter table if exists public.consultations
  alter column consultation_type_id set not null,
  alter column consultation_status_id set not null,
  drop column if exists consultation_type,
  drop column if exists consultation_status;

alter table if exists public.materials
  alter column access_level_id set not null,
  drop column if exists access_level,
  drop column if exists publication_status;

alter table if exists public.material_views
  alter column read_status_id set not null,
  drop column if exists reading_status;

alter table if exists public.tests
  alter column test_type_id set not null,
  alter column access_level_id set not null,
  drop column if exists test_type,
  drop column if exists access_level,
  drop column if exists activity_status;

alter table if exists public.test_attempts
  alter column attempt_status_id set not null,
  drop column if exists attempt_status;

alter table if exists public.recommendations
  drop column if exists recommendation_status;

alter table if exists public.events
  alter column event_format_id set not null,
  alter column event_category_id set not null,
  alter column event_status_id set not null,
  drop column if exists event_format,
  drop column if exists category,
  drop column if exists event_status;

alter table if exists public.event_moderation
  drop column if exists moderation_type,
  drop column if exists moderation_decision;

alter table if exists public.event_requests
  alter column request_status_id set not null,
  drop column if exists request_status;

commit;
