-- ============================================================
-- FASE 11: executive_contexts
-- Contexto executivo persistido por projeto — saúde, prioridade,
-- decisões e check-in
-- ============================================================

create table if not exists executive_contexts (
  id                  uuid        primary key default gen_random_uuid(),
  user_id             uuid        not null references auth.users(id) on delete cascade,
  project_id          uuid        not null unique references projects(id) on delete cascade,
  executive_summary   text        not null default '',
  health              jsonb       not null default '{}',
  decisions           jsonb       not null default '[]',
  risks               jsonb       not null default '[]',
  relationships       jsonb       not null default '[]',
  priority_score      integer     not null default 0
                                  check (priority_score >= 0 and priority_score <= 100),
  check_in_due        boolean     not null default false,
  last_activity_at    timestamptz,
  last_analysis_at    timestamptz,
  context_version     integer     not null default 1,
  generated_at        timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- Índices para consultas comuns
create index if not exists executive_contexts_user_id_idx
  on executive_contexts (user_id);

create index if not exists executive_contexts_project_id_idx
  on executive_contexts (project_id);

create index if not exists executive_contexts_priority_idx
  on executive_contexts (user_id, priority_score desc);

create index if not exists executive_contexts_check_in_idx
  on executive_contexts (user_id, check_in_due)
  where check_in_due = true;

-- ── Row Level Security ───────────────────────────────────────

alter table executive_contexts enable row level security;

-- Usuário lê apenas seus próprios contextos
create policy "executive_contexts_select_own"
  on executive_contexts for select
  using (user_id = auth.uid());

-- INSERT: user_id deve ser o próprio usuário E o project_id deve pertencer ao usuário
create policy "executive_contexts_insert_own"
  on executive_contexts for insert
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from projects
      where projects.id = executive_contexts.project_id
        and projects.user_id = auth.uid()
    )
  );

-- UPDATE: somente o próprio usuário pode atualizar
create policy "executive_contexts_update_own"
  on executive_contexts for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- DELETE: somente o próprio usuário pode excluir
create policy "executive_contexts_delete_own"
  on executive_contexts for delete
  using (user_id = auth.uid());

-- Trigger para atualizar updated_at automaticamente
create or replace function update_executive_contexts_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger executive_contexts_updated_at
  before update on executive_contexts
  for each row execute function update_executive_contexts_updated_at();
