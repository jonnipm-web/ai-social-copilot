# Executive Intelligence — Database Schema

## Tables

### `project_events`

Timeline executiva persistida de todos os eventos relevantes de um projeto.

| Coluna | Tipo | Nullable | Descrição |
|--------|------|----------|-----------|
| `id` | uuid | NOT NULL | PK gerado automaticamente |
| `user_id` | uuid | NOT NULL | FK → `auth.users.id` (cascade delete) |
| `project_id` | uuid | NOT NULL | FK → `projects.id` (cascade delete) |
| `event_type` | text | NOT NULL | Ver catálogo abaixo. CHECK constraint. |
| `title` | text | NOT NULL | Título legível do evento |
| `description` | text | NOT NULL | Detalhe opcional do evento |
| `metadata` | jsonb | NOT NULL | Dados extras estruturados. Default `{}` |
| `source_module` | text | NULL | Módulo que originou o evento |
| `source_entity_id` | uuid | NULL | ID da entidade de origem (para rastreabilidade) |
| `idempotency_key` | text | NULL | Chave única para evitar duplicação |
| `created_at` | timestamptz | NOT NULL | Auto-gerado |
| `updated_at` | timestamptz | NOT NULL | Auto-atualizado via trigger |

**Índices:**
- `project_events_idempotency_key_idx` — UNIQUE PARTIAL (WHERE idempotency_key IS NOT NULL)
- `project_events_project_created_idx` — `(project_id, created_at DESC)`
- `project_events_user_created_idx` — `(user_id, created_at DESC)`
- `project_events_event_type_idx` — `(event_type)`

**Tipos de evento válidos (CHECK constraint):**
```
project_created, stage_changed, analysis_completed, decision_taken,
opportunity_created, document_added, action_completed, check_in,
interview_completed, relationship_detected, health_changed, priority_changed
```

**RLS Policies:**
- `project_events_select_own`: SELECT WHERE `user_id = auth.uid()`
- `project_events_insert_own`: INSERT WITH CHECK `user_id = auth.uid() AND project_id belongs to same user`
- `project_events_delete_own`: DELETE WHERE `user_id = auth.uid()`

---

### `executive_contexts`

Contexto executivo persistente por projeto — snapshot do estado estratégico.

| Coluna | Tipo | Nullable | Descrição |
|--------|------|----------|-----------|
| `id` | uuid | NOT NULL | PK |
| `user_id` | uuid | NOT NULL | FK → `auth.users.id` (cascade delete) |
| `project_id` | uuid | NOT NULL UNIQUE | FK → `projects.id` (cascade delete) |
| `executive_summary` | text | NOT NULL | Resumo executivo gerado |
| `health` | jsonb | NOT NULL | Dados de saúde executiva. Default `{}` |
| `decisions` | jsonb | NOT NULL | Array de decisões tomadas. Default `[]` |
| `risks` | jsonb | NOT NULL | Array de riscos abertos. Default `[]` |
| `relationships` | jsonb | NOT NULL | Array de relações detectadas. Default `[]` |
| `priority_score` | integer | NOT NULL | Score 0–100. CHECK constraint |
| `check_in_due` | boolean | NOT NULL | Se revisão está vencida. Default false |
| `last_activity_at` | timestamptz | NULL | Última atividade registrada |
| `last_analysis_at` | timestamptz | NULL | Última análise de mercado executada |
| `context_version` | integer | NOT NULL | Versão incremental. Default 1 |
| `generated_at` | timestamptz | NULL | Quando contexto foi gerado |
| `created_at` | timestamptz | NOT NULL | Auto-gerado |
| `updated_at` | timestamptz | NOT NULL | Auto-atualizado |

**Constraint CHECK:** `priority_score >= 0 AND priority_score <= 100`

**Upsert key:** `project_id` (UNIQUE) — usado em `onConflict: 'project_id'`

**RLS Policies:**
- SELECT: `user_id = auth.uid()`
- INSERT: `user_id = auth.uid() AND project_id belongs to same user`
- UPDATE: `user_id = auth.uid()`
- DELETE: `user_id = auth.uid()`

---

## Migration Files

| Arquivo | Tabela | Versão |
|---------|--------|--------|
| `022_phase11_project_events.sql` | `project_events` | Fase 11B |
| `023_phase11_executive_contexts.sql` | `executive_contexts` | Fase 11B |
