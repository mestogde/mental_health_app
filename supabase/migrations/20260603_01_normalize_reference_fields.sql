begin;

create extension if not exists pgcrypto;

create table if not exists public.access_levels (
  access_level_id uuid primary key default gen_random_uuid(),
  level_name varchar(100) not null,
  system_value varchar(50) not null unique,
  description text
);

create table if not exists public.access_statuses (
  access_status_id uuid primary key default gen_random_uuid(),
  status_name varchar(100) not null,
  system_value varchar(50) not null unique,
  description text
);

create table if not exists public.consultation_types (
  consultation_type_id uuid primary key default gen_random_uuid(),
  type_name varchar(100) not null,
  system_value varchar(50) not null unique
);

create table if not exists public.consultation_statuses (
  consultation_status_id uuid primary key default gen_random_uuid(),
  status_name varchar(100) not null,
  system_value varchar(50) not null unique,
  description text
);

create table if not exists public.test_types (
  test_type_id uuid primary key default gen_random_uuid(),
  type_name varchar(100) not null,
  system_value varchar(50) not null unique
);

create table if not exists public.material_read_statuses (
  read_status_id uuid primary key default gen_random_uuid(),
  status_name varchar(100) not null,
  system_value varchar(50) not null unique,
  description text
);

create table if not exists public.test_attempt_statuses (
  attempt_status_id uuid primary key default gen_random_uuid(),
  status_name varchar(100) not null,
  system_value varchar(50) not null unique,
  description text
);

create table if not exists public.event_formats (
  event_format_id uuid primary key default gen_random_uuid(),
  format_name varchar(100) not null,
  system_value varchar(50) not null unique
);

create table if not exists public.event_categories (
  event_category_id uuid primary key default gen_random_uuid(),
  category_name varchar(100) not null,
  system_value varchar(50) not null unique
);

create table if not exists public.event_statuses (
  event_status_id uuid primary key default gen_random_uuid(),
  status_name varchar(100) not null,
  system_value varchar(50) not null unique,
  description text
);

create table if not exists public.moderation_types (
  moderation_type_id uuid primary key default gen_random_uuid(),
  type_name varchar(100) not null,
  system_value varchar(50) not null unique
);

create table if not exists public.moderation_decisions (
  moderation_decision_id uuid primary key default gen_random_uuid(),
  decision_name varchar(100) not null,
  system_value varchar(50) not null unique,
  description text
);

create table if not exists public.request_statuses (
  request_status_id uuid primary key default gen_random_uuid(),
  status_name varchar(100) not null,
  system_value varchar(50) not null unique,
  description text
);

insert into public.access_levels (level_name, system_value, description)
values
  ('Гостевой', 'guest', 'Гостевой доступ'),
  ('Расширенный', 'patient', 'Расширенный доступ пациента')
on conflict (system_value) do update
set
  level_name = excluded.level_name,
  description = excluded.description;

insert into public.access_statuses (status_name, system_value, description)
values
  ('Не активирован', 'not_activated', 'Доступ ещё не активирован'),
  ('Активен', 'active', 'Доступ активен'),
  ('Заблокирован', 'blocked', 'Доступ заблокирован')
on conflict (system_value) do update
set
  status_name = excluded.status_name,
  description = excluded.description;

insert into public.consultation_types (type_name, system_value)
values
  ('Первичная', 'primary'),
  ('Повторная', 'repeat'),
  ('Контрольная', 'control')
on conflict (system_value) do update
set type_name = excluded.type_name;

insert into public.consultation_statuses (status_name, system_value, description)
values
  ('Запланирована', 'planned', 'Консультация запланирована'),
  ('Завершена', 'completed', 'Консультация завершена'),
  ('Отменена', 'cancelled', 'Консультация отменена'),
  ('Перенесена', 'rescheduled', 'Консультация перенесена')
on conflict (system_value) do update
set
  status_name = excluded.status_name,
  description = excluded.description;

insert into public.test_types (type_name, system_value)
values
  ('Базовый', 'basic'),
  ('Расширенный', 'extended'),
  ('Повторный', 'repeat')
on conflict (system_value) do update
set type_name = excluded.type_name;

insert into public.material_read_statuses (status_name, system_value, description)
values
  ('Не начато', 'not_started', 'Материал ещё не открыт'),
  ('В процессе', 'in_progress', 'Материал читается'),
  ('Прочитано', 'completed', 'Материал прочитан')
on conflict (system_value) do update
set
  status_name = excluded.status_name,
  description = excluded.description;

insert into public.test_attempt_statuses (status_name, system_value, description)
values
  ('Начат', 'started', 'Прохождение теста начато'),
  ('Завершён', 'completed', 'Прохождение теста завершено'),
  ('Прерван', 'interrupted', 'Прохождение теста прервано')
on conflict (system_value) do update
set
  status_name = excluded.status_name,
  description = excluded.description;

insert into public.event_formats (format_name, system_value)
values
  ('Онлайн', 'online'),
  ('Офлайн', 'offline')
on conflict (system_value) do update
set format_name = excluded.format_name;

insert into public.event_categories (category_name, system_value)
values
  ('Природа', 'nature'),
  ('Развлечение', 'entertainment'),
  ('Игра', 'game')
on conflict (system_value) do update
set category_name = excluded.category_name;

insert into public.event_statuses (status_name, system_value, description)
values
  ('Ожидает проверку', 'pending', 'Событие ожидает модерацию'),
  ('Опубликовано', 'approved', 'Событие опубликовано'),
  ('Отклонено', 'rejected', 'Событие отклонено'),
  ('Завершено', 'completed', 'Событие завершено'),
  ('Удалено', 'deleted', 'Событие удалено')
on conflict (system_value) do update
set
  status_name = excluded.status_name,
  description = excluded.description;

insert into public.moderation_types (type_name, system_value)
values
  ('Ручная', 'manual'),
  ('Автоматическая', 'automatic')
on conflict (system_value) do update
set type_name = excluded.type_name;

insert into public.moderation_decisions (decision_name, system_value, description)
values
  ('Одобрено', 'approved', 'Событие одобрено'),
  ('Отклонено', 'rejected', 'Событие отклонено'),
  ('Требуется уточнение', 'needs_clarification', 'Нужно уточнение данных')
on conflict (system_value) do update
set
  decision_name = excluded.decision_name,
  description = excluded.description;

insert into public.request_statuses (status_name, system_value, description)
values
  ('Запрос отправлен', 'pending', 'Запрос ещё не обработан'),
  ('Вы участвуете', 'accepted', 'Заявка принята'),
  ('Запрос отклонён', 'rejected', 'Заявка отклонена'),
  ('Отменён пользователем', 'cancelled', 'Заявка отменена пользователем')
on conflict (system_value) do update
set
  status_name = excluded.status_name,
  description = excluded.description;

alter table if exists public.patients
  add column if not exists access_status_id uuid,
  add column if not exists access_level_id uuid;

alter table if exists public.consultations
  add column if not exists consultation_type_id uuid,
  add column if not exists consultation_status_id uuid;

alter table if exists public.materials
  add column if not exists access_level_id uuid;

alter table if exists public.material_views
  add column if not exists read_status_id uuid;

alter table if exists public.tests
  add column if not exists test_type_id uuid,
  add column if not exists access_level_id uuid;

alter table if exists public.test_attempts
  add column if not exists attempt_status_id uuid;

alter table if exists public.events
  add column if not exists event_format_id uuid,
  add column if not exists event_category_id uuid,
  add column if not exists event_status_id uuid;

alter table if exists public.event_moderation
  add column if not exists moderation_type_id uuid,
  add column if not exists moderation_decision_id uuid;

alter table if exists public.event_requests
  add column if not exists request_status_id uuid;

update public.patients p
set access_status_id = s.access_status_id
from public.access_statuses s
where p.access_status_id is null
  and s.system_value = case
    when lower(trim(coalesce(p.access_status, ''))) in ('active', 'активен', 'активна') then 'active'
    when lower(trim(coalesce(p.access_status, ''))) in ('blocked', 'block', 'заблокирован', 'заблокирована') then 'blocked'
    else 'not_activated'
  end;

update public.patients p
set access_level_id = l.access_level_id
from public.access_levels l
where p.access_level_id is null
  and l.system_value = case
    when lower(trim(coalesce(p.access_level, ''))) = 'guest' then 'guest'
    when lower(trim(coalesce(p.access_level, ''))) in ('patient', 'extended') then 'patient'
    when p.extended_access_activated_at is not null then 'patient'
    else 'guest'
  end;

update public.consultations c
set consultation_type_id = t.consultation_type_id
from public.consultation_types t
where c.consultation_type_id is null
  and t.system_value = case
    when lower(trim(coalesce(c.consultation_type, ''))) in ('repeat', 'повторная') then 'repeat'
    when lower(trim(coalesce(c.consultation_type, ''))) in ('control', 'контрольная') then 'control'
    else 'primary'
  end;

update public.consultations c
set consultation_status_id = s.consultation_status_id
from public.consultation_statuses s
where c.consultation_status_id is null
  and s.system_value = case
    when lower(trim(coalesce(c.consultation_status, ''))) in ('completed', 'завершена') then 'completed'
    when lower(trim(coalesce(c.consultation_status, ''))) in ('cancelled', 'canceled', 'отменена') then 'cancelled'
    when lower(trim(coalesce(c.consultation_status, ''))) in ('rescheduled', 'перенесена') then 'rescheduled'
    else 'planned'
  end;

update public.materials m
set access_level_id = l.access_level_id
from public.access_levels l
where m.access_level_id is null
  and l.system_value = case
    when lower(trim(coalesce(m.access_level, ''))) = 'guest' then 'guest'
    when lower(trim(coalesce(m.access_level, ''))) in ('patient', 'extended') then 'patient'
    else 'guest'
  end;

update public.material_views mv
set read_status_id = s.read_status_id
from public.material_read_statuses s
where mv.read_status_id is null
  and s.system_value = case
    when lower(trim(coalesce(mv.reading_status, ''))) in ('completed', 'прочитано') then 'completed'
    when lower(trim(coalesce(mv.reading_status, ''))) in ('in_progress', 'in progress', 'в процессе') then 'in_progress'
    else 'not_started'
  end;

update public.tests t0
set access_level_id = l.access_level_id
from public.access_levels l
where t0.access_level_id is null
  and l.system_value = case
    when lower(trim(coalesce(t0.access_level, ''))) = 'guest' then 'guest'
    when lower(trim(coalesce(t0.access_level, ''))) in ('patient', 'extended') then 'patient'
    else 'guest'
  end;

update public.tests t0
set test_type_id = tt.test_type_id
from public.test_types tt
where t0.test_type_id is null
  and tt.system_value = case
    when lower(trim(coalesce(t0.test_type, ''))) in ('repeat', 'повторный', 'самонаблюдение', 'мониторинг', 'рефлексия') then 'repeat'
    when lower(trim(coalesce(t0.test_type, ''))) in ('extended', 'расширенный') then 'extended'
    when lower(trim(coalesce(t0.access_level, ''))) in ('patient', 'extended') then 'extended'
    else 'basic'
  end;

update public.test_attempts ta
set attempt_status_id = s.attempt_status_id
from public.test_attempt_statuses s
where ta.attempt_status_id is null
  and s.system_value = case
    when lower(trim(coalesce(ta.attempt_status, ''))) in ('completed', 'завершён', 'завершен') then 'completed'
    when lower(trim(coalesce(ta.attempt_status, ''))) in ('interrupted', 'прерван') then 'interrupted'
    else 'started'
  end;

update public.events e
set event_format_id = f.event_format_id
from public.event_formats f
where e.event_format_id is null
  and f.system_value = case
    when lower(trim(coalesce(e.event_format, ''))) in ('online', 'онлайн') then 'online'
    else 'offline'
  end;

update public.events e
set event_category_id = c.event_category_id
from public.event_categories c
where e.event_category_id is null
  and c.system_value = case
    when lower(trim(coalesce(e.category, ''))) in ('nature', 'природа', 'прогулка', 'walk') then 'nature'
    when lower(trim(coalesce(e.category, ''))) in ('game', 'игра') then 'game'
    else 'entertainment'
  end;

update public.events e
set event_status_id = s.event_status_id
from public.event_statuses s
where e.event_status_id is null
  and s.system_value = case
    when lower(trim(coalesce(e.event_status, ''))) in ('approved', 'published', 'active', 'опубликовано') then 'approved'
    when lower(trim(coalesce(e.event_status, ''))) in ('rejected', 'declined', 'отклонено') then 'rejected'
    when lower(trim(coalesce(e.event_status, ''))) in ('completed', 'завершено') then 'completed'
    when lower(trim(coalesce(e.event_status, ''))) in ('deleted', 'removed', 'удалено') then 'deleted'
    else 'pending'
  end;

update public.event_moderation em
set moderation_type_id = mt.moderation_type_id
from public.moderation_types mt
where em.moderation_type_id is null
  and mt.system_value = case
    when lower(trim(coalesce(em.moderation_type, ''))) in ('manual', 'ручная', 'ручной') then 'manual'
    else 'automatic'
  end;

update public.event_moderation em
set moderation_decision_id = md.moderation_decision_id
from public.moderation_decisions md
where em.moderation_decision_id is null
  and md.system_value = case
    when lower(trim(coalesce(em.moderation_decision, ''))) in ('approved', 'одобрено') then 'approved'
    when lower(trim(coalesce(em.moderation_decision, ''))) in ('rejected', 'отклонено') then 'rejected'
    else 'needs_clarification'
  end;

update public.event_requests er
set request_status_id = s.request_status_id
from public.request_statuses s
where er.request_status_id is null
  and s.system_value = case
    when lower(trim(coalesce(er.request_status, ''))) in ('accepted', 'approved', 'вы участвуете') then 'accepted'
    when lower(trim(coalesce(er.request_status, ''))) in ('rejected', 'declined', 'отклонён', 'отклонен') then 'rejected'
    when lower(trim(coalesce(er.request_status, ''))) in ('cancelled', 'canceled', 'отменён', 'отменен') then 'cancelled'
    else 'pending'
  end;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'patients_access_status_id_fkey'
  ) then
    alter table public.patients
      add constraint patients_access_status_id_fkey
      foreign key (access_status_id)
      references public.access_statuses (access_status_id);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'patients_access_level_id_fkey'
  ) then
    alter table public.patients
      add constraint patients_access_level_id_fkey
      foreign key (access_level_id)
      references public.access_levels (access_level_id);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'consultations_consultation_type_id_fkey'
  ) then
    alter table public.consultations
      add constraint consultations_consultation_type_id_fkey
      foreign key (consultation_type_id)
      references public.consultation_types (consultation_type_id);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'consultations_consultation_status_id_fkey'
  ) then
    alter table public.consultations
      add constraint consultations_consultation_status_id_fkey
      foreign key (consultation_status_id)
      references public.consultation_statuses (consultation_status_id);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'materials_access_level_id_fkey'
  ) then
    alter table public.materials
      add constraint materials_access_level_id_fkey
      foreign key (access_level_id)
      references public.access_levels (access_level_id);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'material_views_read_status_id_fkey'
  ) then
    alter table public.material_views
      add constraint material_views_read_status_id_fkey
      foreign key (read_status_id)
      references public.material_read_statuses (read_status_id);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'tests_test_type_id_fkey'
  ) then
    alter table public.tests
      add constraint tests_test_type_id_fkey
      foreign key (test_type_id)
      references public.test_types (test_type_id);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'tests_access_level_id_fkey'
  ) then
    alter table public.tests
      add constraint tests_access_level_id_fkey
      foreign key (access_level_id)
      references public.access_levels (access_level_id);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'test_attempts_attempt_status_id_fkey'
  ) then
    alter table public.test_attempts
      add constraint test_attempts_attempt_status_id_fkey
      foreign key (attempt_status_id)
      references public.test_attempt_statuses (attempt_status_id);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'events_event_format_id_fkey'
  ) then
    alter table public.events
      add constraint events_event_format_id_fkey
      foreign key (event_format_id)
      references public.event_formats (event_format_id);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'events_event_category_id_fkey'
  ) then
    alter table public.events
      add constraint events_event_category_id_fkey
      foreign key (event_category_id)
      references public.event_categories (event_category_id);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'events_event_status_id_fkey'
  ) then
    alter table public.events
      add constraint events_event_status_id_fkey
      foreign key (event_status_id)
      references public.event_statuses (event_status_id);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'event_moderation_moderation_type_id_fkey'
  ) then
    alter table public.event_moderation
      add constraint event_moderation_moderation_type_id_fkey
      foreign key (moderation_type_id)
      references public.moderation_types (moderation_type_id);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'event_moderation_moderation_decision_id_fkey'
  ) then
    alter table public.event_moderation
      add constraint event_moderation_moderation_decision_id_fkey
      foreign key (moderation_decision_id)
      references public.moderation_decisions (moderation_decision_id);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'event_requests_request_status_id_fkey'
  ) then
    alter table public.event_requests
      add constraint event_requests_request_status_id_fkey
      foreign key (request_status_id)
      references public.request_statuses (request_status_id);
  end if;
end $$;

create index if not exists idx_patients_access_status_id on public.patients (access_status_id);
create index if not exists idx_patients_access_level_id on public.patients (access_level_id);
create index if not exists idx_consultations_type_id on public.consultations (consultation_type_id);
create index if not exists idx_consultations_status_id on public.consultations (consultation_status_id);
create index if not exists idx_materials_access_level_id on public.materials (access_level_id);
create index if not exists idx_material_views_read_status_id on public.material_views (read_status_id);
create index if not exists idx_tests_test_type_id on public.tests (test_type_id);
create index if not exists idx_tests_access_level_id on public.tests (access_level_id);
create index if not exists idx_test_attempts_attempt_status_id on public.test_attempts (attempt_status_id);
create index if not exists idx_events_event_format_id on public.events (event_format_id);
create index if not exists idx_events_event_category_id on public.events (event_category_id);
create index if not exists idx_events_event_status_id on public.events (event_status_id);
create index if not exists idx_event_moderation_type_id on public.event_moderation (moderation_type_id);
create index if not exists idx_event_moderation_decision_id on public.event_moderation (moderation_decision_id);
create index if not exists idx_event_requests_status_id on public.event_requests (request_status_id);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'event_requests_event_id_patient_id_key'
  ) then
    if exists (
      select 1
      from public.event_requests
      group by event_id, patient_id
      having count(*) > 1
    ) then
      raise notice 'Skipped unique constraint event_requests(event_id, patient_id): duplicate rows exist';
    else
      alter table public.event_requests
        add constraint event_requests_event_id_patient_id_key
        unique (event_id, patient_id);
    end if;
  end if;
end $$;

alter table public.access_levels enable row level security;
alter table public.access_statuses enable row level security;
alter table public.consultation_types enable row level security;
alter table public.consultation_statuses enable row level security;
alter table public.test_types enable row level security;
alter table public.material_read_statuses enable row level security;
alter table public.test_attempt_statuses enable row level security;
alter table public.event_formats enable row level security;
alter table public.event_categories enable row level security;
alter table public.event_statuses enable row level security;
alter table public.moderation_types enable row level security;
alter table public.moderation_decisions enable row level security;
alter table public.request_statuses enable row level security;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'access_levels',
    'access_statuses',
    'consultation_types',
    'consultation_statuses',
    'test_types',
    'material_read_statuses',
    'test_attempt_statuses',
    'event_formats',
    'event_categories',
    'event_statuses',
    'moderation_types',
    'moderation_decisions',
    'request_statuses'
  ]
  loop
    if not exists (
      select 1
      from pg_policies
      where schemaname = 'public'
        and tablename = table_name
        and policyname = table_name || '_select_all'
    ) then
      execute format(
        'create policy %I on public.%I for select using (true)',
        table_name || '_select_all',
        table_name
      );
    end if;
  end loop;
end $$;

comment on column public.tests.test_type_id is
  'Backfill maps legacy free-text values to basic/extended/repeat. Review rows migrated from custom labels.';

comment on column public.events.event_category_id is
  'Backfill maps legacy categories like ''культура'' to entertainment. Review if a broader catalog is needed.';

commit;
