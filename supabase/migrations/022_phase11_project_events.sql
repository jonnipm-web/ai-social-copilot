-- ============================================================
-- FASE 11: project_events
-- Timeline executiva persistida por projeto e usuário
-- ============================================================

create table if not exists project_events (
  id               uuid        primary key default gen_random_uuid(),
  user_id          uuid        not null references auth.users(id) on delete cascade,
  project_id       uuid        not null references projects(id)   on delete cascade,
  event_type       text        not null,
  title            text        not null default '',
  description      text        not null default '',
  metadata         jsonb       not null default '{}',
  source_module    text,
  source_entity_id uuid,
  idempotency_key  text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),

  constraint project_events_event_type_check check (event_type in (
    'project_created', 'stage_changed', 'analysis_completed', 'decision_taken',
    'opportunity_created', 'document_added', 'action_completed', 'check_in',
    'interview_completed', 'relationship_detected', 'health_changed', 'priority_changed'
  ))
);

-- Unicidade para idempotência (ignora NULLs automaticamente no PostgreSQL)
create unique index if not exists project_events_idempotency_key_idx
  on project_events (idempotency_key)
  where idempotency_key is not null;

-- Índices para consultas comuns
create index if not exists project_events_project_created_idx
  on project_events (project_id, created_at desc);

create index if not exists project_events_user_created_idx
  on project_events (user_id, created_at desc);

create index if not exists project_events_event_type_idx
  on project_events (event_type);

create index if not exists project_events_created_idx
  on project_events (created_at desc);

-- ── Row Level Security ───────────────────────────────────────

alter table project_events enable row level security;

-- Usuário lê apenas seus próprios eventos
create policy "project_events_select_own"
  on project_events for select
  using (user_id = auth.uid());

-- Usuário insere apenas para seus projetos (dupla verificação: user_id + project_id)
create policy "project_events_insert_own"
  on project_events for insert
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from projects
      where projects.id = project_events.project_id
        and projects.user_id = auth.uid()
    )
  );

-- Usuário pode excluir apenas seus próprios eventos
create policy "project_events_delete_own"
  on project_events for delete
  using (user_id = auth.uid());

-- Trigger para atualizar updated_at automaticamente
create or replace function update_project_events_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger project_events_updated_at
  before update on project_events
  for each row execute function update_project_events_updated_at();
