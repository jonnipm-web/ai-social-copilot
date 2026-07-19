# ASSET INTELLIGENCE FOUNDATION
## AI Social Copilot — Fase A

---

### OBJETIVO

Criar a fundação técnica para a camada:

```
PROJECT
  └── ASSETS
        └── ASSET INTELLIGENCE
```

Um projeto pode ter múltiplos ativos. Cada ativo pode ter filhos (hierarquia).
A camada é genérica — não depende do tipo de negócio.

---

### MODELO: Asset

Arquivo: `lib/data/models/asset.dart`

```
id                  String      — UUID (gerado pelo Supabase)
userId              String      — user_id da sessão (nunca do cliente)
projectId           String      — projeto ao qual pertence
parentAssetId       String?     — asset pai (opcional, mesmo projeto)
name                String      — nome do ativo
type                AssetType   — tipo (enum extensível)
subtype             String?     — subtipo livre
description         String?     — descrição
status              AssetStatus — ciclo de vida (enum)
category            String?
niche               String?
targetMarket        String?
targetAudience      String?
businessModel       String?
revenueModel        String?
lifecycleStage      String?
strategicPriority   int?
metadata            Map<String, dynamic>  — JSONB extensível
createdAt           DateTime
updatedAt           DateTime
```

---

### TIPOS DE ASSET (AssetType)

| Enum                  | DB value               |
|-----------------------|------------------------|
| product               | product                |
| service               | service                |
| book                  | book                   |
| series                | series                 |
| website               | website                |
| app                   | app                    |
| course                | course                 |
| contentProperty       | content_property       |
| brand                 | brand                  |
| module                | module                 |
| market                | market                 |
| niche                 | niche                  |
| technology            | technology             |
| intellectualProperty  | intellectual_property  |
| other                 | other                  |

Conversão: `AssetType.fromDb(String?)` e `.dbValue`.

---

### STATUS DO ASSET (AssetStatus)

idea → research → validation → planned → active → paused → completed → archived

Conversão: `AssetStatus.fromDb(String?)` e `.dbValue`.

---

### HIERARQUIA

- `parentAssetId` é nullable.
- Asset filho deve pertencer ao mesmo `userId` e `projectId`.
- Constraint SQL: `id != parent_asset_id` impede self-reference direta.
- Trigger `validate_asset_parent_ownership` impede parent de outro usuário/projeto.
- Ciclos profundos (A→B→A) são responsabilidade da camada de aplicação.

---

### OWNERSHIP — REGRAS

- `create()`: `user_id` vem da sessão, não do payload.
- Antes de criar: projeto validado como pertencente ao usuário.
- Antes de criar com parent: parent validado no mesmo projeto/usuário.
- Antes de `update/archive/delete`: asset validado como pertencente ao usuário.
- Nunca retorna dados sem sessão autenticada.
- `projectId` vazio lança exceção antes de qualquer chamada ao banco.

---

### ROW-LEVEL SECURITY

Tabela: `public.assets`

```sql
SELECT : USING (auth.uid() = user_id)
INSERT : WITH CHECK (auth.uid() = user_id)
UPDATE : USING/WITH CHECK (auth.uid() = user_id)
DELETE : USING (auth.uid() = user_id)
```

Trigger adicional: `validate_asset_parent_ownership` valida hierarquia.

---

### SERVICE

Arquivo: `lib/data/services/asset_service.dart`

Interface: `AssetServiceInterface`

Métodos:
- `fetchAll(projectId)` — filtra user_id + project_id
- `fetchById(assetId)` — filtra user_id
- `fetchChildren(parentAssetId)` — filtra user_id
- `create(data)` — injeta user_id da sessão
- `update(assetId, data)` — verifica ownership
- `archive(assetId)` — status → archived
- `restore(assetId)` — status → active
- `delete(assetId)` — verifica ownership

---

### PROVIDER

Arquivo: `lib/providers/asset_provider.dart`

```dart
assetServiceProvider            — Provider<AssetServiceInterface>
assetsForProjectProvider(id)    — FutureProvider.family
assetByIdProvider(id)           — FutureProvider.family
assetChildrenProvider(id)       — FutureProvider.family
assetsNotifierProvider(projectId) — AsyncNotifierProvider.family (CRUD)
```

---

### MIGRATION PROPOSTA

Arquivo: `supabase/migrations/022_asset_intelligence_foundation.sql`

Status: **PROPOSTA — NÃO APLICADA**

Tabela: `public.assets`

Inclui:
- Todos os campos do modelo
- Constraints de domínio (status_valid, type_valid, no_self_reference)
- 7 índices (user_id, project_id, composto user+project, parent, type, status, niche)
- Trigger updated_at (reutiliza `set_updated_at` existente)
- Trigger de hierarquia (valida parent ownership)
- RLS para SELECT/INSERT/UPDATE/DELETE

---

### COMPATIBILIDADE

- Projetos sem assets: válidos — nenhuma tabela existente foi alterada.
- Oportunidades sem assets: válidas.
- Ações sem assets: válidas.
- A camada Asset é **aditiva**.

---

### ROLLBACK DA MIGRATION

```sql
DROP TABLE IF EXISTS public.assets CASCADE;
DROP FUNCTION IF EXISTS public.validate_asset_parent_ownership CASCADE;
```

O CASCADE remove índices, triggers e políticas automaticamente.
Nenhuma tabela existente é afetada.

---

### FUTURAS EXTENSÕES (NÃO IMPLEMENTAR NESTA FASE)

#### Fase B — Asset Intelligence Scores
```sql
ALTER TABLE public.assets ADD COLUMN opportunity_score INTEGER DEFAULT 0;
ALTER TABLE public.assets ADD COLUMN roi_score         FLOAT   DEFAULT 0;
ALTER TABLE public.assets ADD COLUMN momentum_score    INTEGER DEFAULT 0;
```

#### Fase C — Opportunity Lab por Asset
```sql
ALTER TABLE public.opportunity_lab ADD COLUMN asset_id UUID REFERENCES public.assets(id);
ALTER TABLE public.action_queue    ADD COLUMN asset_id UUID REFERENCES public.assets(id);
```
Ambos os campos serão NULLABLE para garantir retrocompatibilidade.

#### Fase D — Asset Scores Provider
`assetScoresProvider(assetId)` — computado a partir de `metadata` JSONB.

#### Fase E — ROI/Performance por Asset
Extensão de `roi_metrics` com `asset_id` nullable.

#### Fase F — Evidence Layer
Campo `evidence` JSONB dentro de `metadata` do asset.

---

*Documento criado em: 2026-07-19*
*Branch: integration/build-week-ive-v1*
*Status: Fase A concluída — aguardando aprovação de migration para Fase B*
