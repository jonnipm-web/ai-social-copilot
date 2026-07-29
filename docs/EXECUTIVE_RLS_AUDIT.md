# Executive Intelligence — RLS Audit

## Objetivo

Validar que as políticas de Row Level Security garantem isolamento total entre usuários e que não há caminho de acesso a dados de outro usuário.

## Tabelas Auditadas

- `project_events`
- `executive_contexts`

---

## Políticas de `project_events`

### SELECT
```sql
create policy "project_events_select_own"
  on project_events for select
  using (user_id = auth.uid());
```
**Validação:** Usuário A não consegue ler eventos do Usuário B, pois `user_id` de B ≠ `auth.uid()` de A.

### INSERT
```sql
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
```
**Dupla validação:**
1. `user_id = auth.uid()` — impede adulteração do campo user_id
2. `project_id` pertence ao mesmo usuário — impede inserção em projeto alheio

### DELETE
```sql
create policy "project_events_delete_own"
  on project_events for delete
  using (user_id = auth.uid());
```

---

## Políticas de `executive_contexts`

### SELECT
```sql
create policy "executive_contexts_select_own"
  on executive_contexts for select
  using (user_id = auth.uid());
```

### INSERT
```sql
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
```

### UPDATE
```sql
create policy "executive_contexts_update_own"
  on executive_contexts for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
```

### DELETE
```sql
create policy "executive_contexts_delete_own"
  on executive_contexts for delete
  using (user_id = auth.uid());
```

---

## Cenários de Teste RLS (SQL)

### Cenário 1: Usuário sem autenticação não acessa nada
```sql
-- Como usuário anônimo (sem auth.uid())
select * from project_events;  -- deve retornar 0 linhas (RLS ativo)
select * from executive_contexts;  -- deve retornar 0 linhas
```

### Cenário 2: Usuário A não vê dados do Usuário B
```sql
-- Logado como user_A (uuid-A)
select * from project_events where user_id = 'uuid-B';
-- resultado esperado: 0 linhas (RLS filtra)
```

### Cenário 3: INSERT com user_id adulterado é bloqueado
```sql
-- Logado como user_A
insert into project_events (user_id, project_id, event_type, title)
values ('uuid-B', 'proj-de-B', 'check_in', 'Adulterado');
-- resultado esperado: ERROR (policy violation)
```

### Cenário 4: INSERT com project_id de outro usuário é bloqueado
```sql
-- Logado como user_A (que não possui proj-de-B)
insert into project_events (user_id, project_id, event_type, title)
values ('uuid-A', 'proj-de-B', 'check_in', 'Invasão');
-- resultado esperado: ERROR (exists check falha)
```

### Cenário 5: Upsert de executive_contexts respeita isolamento
```sql
-- Logado como user_A
insert into executive_contexts (user_id, project_id)
values ('uuid-A', 'proj-de-B')  -- projeto de B
on conflict (project_id) do update set updated_at = now();
-- resultado esperado: ERROR (insert policy falha)
```

---

## Status de Implementação

| Política | Tabela | Status |
|----------|--------|--------|
| SELECT own | project_events | ✅ Implementado |
| INSERT dupla validação | project_events | ✅ Implementado |
| DELETE own | project_events | ✅ Implementado |
| SELECT own | executive_contexts | ✅ Implementado |
| INSERT dupla validação | executive_contexts | ✅ Implementado |
| UPDATE own | executive_contexts | ✅ Implementado |
| DELETE own | executive_contexts | ✅ Implementado |
| RLS ENABLED | ambas tabelas | ✅ `alter table ... enable row level security` |
