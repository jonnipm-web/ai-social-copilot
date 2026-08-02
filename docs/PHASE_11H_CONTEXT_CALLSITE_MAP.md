# PHASE 11H — Context Call-Site Map
**Branch:** `claude/phase-11h-market-intelligence-integration-p0`  
**Base commit:** `1c128c6`  
**Generated:** 2026-08-02  
**Status:** DIAGNOSTIC COMPLETE — Ready for implementation

---

## 1. Executive Summary

`ProjectIntelligenceContextService` exists and is fully implemented but is **dead code**: no screen, notifier, or provider ever calls `buildForProject()` or `buildForInput()` before invoking any of the 6 AI write methods. The `context:` parameter on every service method is permanently `null` at every call site. AI Edge Functions never receive `context_snapshot`, `source_ids`, or `coverage`.

Additionally, `project_id` is not forwarded to `analyze()` from the market intelligence entry screen, so all analyses are saved unlinked (`project_id = null`).

**Full list of gaps:**

| # | Gap | Severity |
|---|-----|----------|
| G1 | `ProjectIntelligenceContextService` never called from any screen | Critical |
| G2 | `analyze` — `projectId` not passed from `MarketIntelligenceScreen` | High |
| G3 | `buildRevenuePlan` — `projectId` available in screen but not forwarded | High |
| G4 | `buildContentCluster` — no `context` or `projectId` param in service at all | Medium |
| G5 | `vaultItems` hardcoded to `[]` in service — vault never fetched | Medium |
| G6 | `_fetchPersonaNames` filters by `user_id` only, not `project_id` | Low |
| G7 | DB insert in `analyze()` missing: `context_snapshot`, `source_ids`, `coverage`, `version`, `supersedes_id` columns | Critical |
| G8 | `delete()` is hard delete — no `deleted_at` soft delete | Medium |
| G9 | `ProjectCommandCenterScreen._analyzeWithKnowledge` calls Edge Function directly, bypasses `MarketAnalysisService` entirely | High |

---

## 2. MarketAnalysisService — Full API Surface

**File:** `lib/data/services/market_analysis_service.dart`

| Method | `projectId` param | `context` param | AI call? |
|--------|-------------------|-----------------|----------|
| `fetchAll({String? projectId})` | filter only | — | no |
| `fetchById(String id)` | — | — | no |
| `delete(String id)` | — | — | no |
| **`analyze`** | optional named | `ProjectIntelligenceContext?` | **yes** |
| `fetchCompetitors(id)` | — | — | no |
| **`discoverCompetitors`** | — | `ProjectIntelligenceContext?` | **yes** |
| `fetchGapAnalysis(id)` | — | — | no |
| **`runGapAnalysis`** | — | `ProjectIntelligenceContext?` | **yes** |
| `fetchOpportunities(id)` | — | — | no |
| **`discoverOpportunities`** | — | `ProjectIntelligenceContext?` | **yes** |
| `fetchNiches(id)` | — | — | no |
| **`discoverNiches`** | — | `ProjectIntelligenceContext?` | **yes** |
| `fetchContentCluster(id)` | — | — | no |
| **`buildContentCluster`** | — | **MISSING** | **yes** |
| `fetchAllRevenuePlans({String? projectId})` | filter only | — | no |
| `fetchRevenuePlan(id)` | — | — | no |
| **`buildRevenuePlan`** | optional named | `ProjectIntelligenceContext?` | **yes** |

**AI write methods: 6 with context hook, 1 missing it entirely (`buildContentCluster`).**

---

## 3. Call Site Map — AI Write Methods

### 3.1 `analyze`

**File:** `lib/features/market_intelligence/screens/market_intelligence_screen.dart`  
**Entry point:** `_MarketIntelligenceScreenState._analyze()` → line 64–73  
**Notifier path:** `ref.read(marketAnalysisNotifierProvider.notifier).analyze(input, inputType: _inputType)`  
**Notifier:** `MarketAnalysisNotifier.analyze(String input, {String inputType, String? projectId})` in `lib/providers/market_analysis_provider.dart` lines 90–112

**Current call:**
```dart
// market_intelligence_screen.dart ~line 67–68
final notifier = ref.read(marketAnalysisNotifierProvider.notifier);
final result = await notifier.analyze(input, inputType: _inputType);
// → notifier calls: _service.analyze(input, inputType: inputType, projectId: projectId)
// → projectId is null — no selector in screen UI
// → context: is null — ProjectIntelligenceContextService never called
```

**What's missing:**
- No project selector widget in `MarketIntelligenceScreen`
- Notifier receives no `projectId:`, passes `null` to service
- Service receives no `context:`, passes no `context_snapshot` to Edge Function
- DB insert at service lines ~65–75 lacks columns: `context_snapshot`, `source_ids`, `coverage`, `version`, `supersedes_id`

**Implementation target:**
- Add project selector to `MarketIntelligenceScreen` (optional — skip if UX is out of scope)
- Pass `projectId:` through the notifier call chain
- Before service call: call `ProjectIntelligenceContextService.buildForProject(projectId)` or `buildForInput(input)`
- Pass built context as `context:` to `_service.analyze(..., context: ctx)`
- Add missing columns to DB insert in service

---

### 3.2 `discoverCompetitors`

**File:** `lib/features/market_intelligence/screens/competitor_discovery_screen.dart`  
**Entry point:** `_CompetitorDiscoveryScreenState._discover()` → lines 25–35  
**Pattern:** Direct `ref.read(marketAnalysisServiceProvider)` — no notifier

**Current call:**
```dart
final analysis = await ref.read(marketAnalysisByIdProvider(widget.analysisId).future);
await ref.read(marketAnalysisServiceProvider)
    .discoverCompetitors(widget.analysisId, analysis.input);
// → context: null
```

**What's missing:**
- `analysis.projectId` is available via the already-fetched `analysis` object
- `context:` not passed — `ProjectIntelligenceContextService` never called
- If `analysis.projectId` is null (due to G2 above), context would be empty anyway

**Implementation target:**
- After fetching `analysis`, if `analysis.projectId != null`, call `ProjectIntelligenceContextService.buildForProject(analysis.projectId!)`
- Pass as `context:` to `discoverCompetitors`

**Providers invalidated on success:** `competitorsByAnalysisProvider(widget.analysisId)`

---

### 3.3 `runGapAnalysis`

**File:** `lib/features/market_intelligence/screens/gap_analysis_screen.dart`  
**Entry point:** `_GapAnalysisScreenState._run()` → lines 20–30  
**Pattern:** Direct `ref.read(marketAnalysisServiceProvider)`

**Current call:**
```dart
final analysis = await ref.read(marketAnalysisByIdProvider(widget.analysisId).future);
await ref.read(marketAnalysisServiceProvider).runGapAnalysis(widget.analysisId, analysis.input);
// → context: null
```

**Implementation target:** Same pattern as 3.2 — fetch context via `analysis.projectId`, pass as `context:`.

**Providers invalidated on success:** `gapAnalysisByAnalysisProvider(widget.analysisId)`

---

### 3.4 `discoverNiches`

**File:** `lib/features/market_intelligence/screens/niche_discovery_screen.dart`  
**Entry point:** `_NicheDiscoveryScreenState._discover()` → lines 21–29  
**Pattern:** Direct `ref.read(marketAnalysisServiceProvider)`

**Current call:**
```dart
final analysis = await ref.read(marketAnalysisByIdProvider(widget.analysisId).future);
await ref.read(marketAnalysisServiceProvider).discoverNiches(widget.analysisId, analysis.input);
// → context: null
```

**Implementation target:** Same pattern as 3.2.

**Providers invalidated on success:** `nichesByAnalysisProvider(widget.analysisId)`

---

### 3.5 `discoverOpportunities`

**File:** `lib/features/market_intelligence/screens/opportunity_discovery_screen.dart`  
**Entry point:** `_OpportunityDiscoveryScreenState._discover()` → lines 23–33  
**Pattern:** Direct `ref.read(marketAnalysisServiceProvider)`

**Current call:**
```dart
final analysis = await ref.read(marketAnalysisByIdProvider(widget.analysisId).future);
await ref.read(marketAnalysisServiceProvider).discoverOpportunities(widget.analysisId, analysis.input);
// → context: null
```

**Implementation target:** Same pattern as 3.2.

**Providers invalidated on success:** `opportunitiesByAnalysisProvider(widget.analysisId)`

---

### 3.6 `buildRevenuePlan`

**File:** `lib/features/market_intelligence/screens/revenue_planner_screen.dart`  
**Entry point:** `_RevenuePlannerScreenState._build()` → lines 46–63  
**Pattern:** Direct `ref.read(marketAnalysisServiceProvider)`

**Current call:**
```dart
final analysis = await ref.read(marketAnalysisByIdProvider(widget.analysisId).future);
await ref.read(marketAnalysisServiceProvider)
    .buildRevenuePlan(widget.analysisId, analysis.input, name);
// → projectId: null (omitted — analysis.projectId known but not forwarded)
// → context: null
```

**Note:** The screen already fetches `analysis.projectId` in `_autoFillProjectName()` (lines 30–36) to look up the project name for the text field, but this is not reused in the service call.

**Implementation target:**
- Pass `projectId: analysis.projectId` in the service call
- Call `ProjectIntelligenceContextService.buildForProject(analysis.projectId!)` if projectId is non-null
- Pass as `context:` to `buildRevenuePlan`

**Providers invalidated on success:** `revenuePlanByAnalysisProvider(widget.analysisId)`

---

### 3.7 `buildContentCluster`

**File:** `lib/features/market_intelligence/screens/content_cluster_screen.dart`  
**Entry point:** `_ContentClusterScreenState._build()` → lines 27–44  
**Pattern:** Direct `ref.read(marketAnalysisServiceProvider)`

**Current call:**
```dart
final analysis = await ref.read(marketAnalysisByIdProvider(widget.analysisId).future);
await ref.read(marketAnalysisServiceProvider)
    .buildContentCluster(widget.analysisId, analysis.input, kw);
// → NO context parameter exists in service method
```

**What's missing:** The service method `buildContentCluster` (line 333) has no `context` or `projectId` parameter. This is the only AI write method without a context hook.

**Implementation target:** Add `{ProjectIntelligenceContext? context}` named parameter to `buildContentCluster` in the service, and send `context_snapshot` to the Edge Function body when non-null.

**Providers invalidated on success:** `contentClusterByAnalysisProvider(widget.analysisId)`

---

### 3.8 `delete` (hard delete — needs soft delete)

**File:** `lib/features/market_intelligence/screens/market_intelligence_screen.dart`  
**Entry point:** `_MarketIntelligenceScreenState._confirmDelete()` → lines 29–61  
**Current:** `await ref.read(marketAnalysisServiceProvider).delete(id)` — hard delete via Supabase `.delete()`

**Implementation target:** Change to soft delete: set `deleted_at = now()` instead of row deletion. Requires `deleted_at` column in `market_analyses` table.

**Providers invalidated on success:** `marketAnalysesProvider`

---

## 4. ProjectCommandCenterScreen — Bypasses MarketAnalysisService

**File:** `lib/features/projects/screens/project_command_center_screen.dart`  
**Method:** `_analyzeWithKnowledge()`

This screen calls `Supabase.instance.client.functions.invoke('edgeFunctionGenerateOpportunities', ...)` **directly** — it does not go through `MarketAnalysisService` at all. The result is not persisted via the service layer, so `context_snapshot`, `source_ids`, and `coverage` cannot be injected from the service.

**Implementation target:** Either:
a. Route through `MarketAnalysisService.analyze()` (preferred — consistent persistence), or  
b. Build context locally and inject into the direct Edge Function call

---

## 5. ProjectIntelligenceContextService — Known Gaps

**File:** `lib/data/services/project_intelligence_context_service.dart`

### G5 — `vaultItems` hardcoded to `[]`
```dart
// line 74
vaultItems: [],  // ← NEVER fetched — vault/cofre table never queried
```
Fix: Add `_fetchVaultItems(projectId)` fetching from the vault/cofre table and populate the field.

### G6 — `_fetchPersonaNames` filters by `user_id` only
```dart
// lines 138–149
final rows = await _client
    .from('personas')
    .select('name')
    .eq('user_id', _client.auth.currentUser?.id ?? '')
    .limit(5);
// ← no .eq('project_id', projectId) — returns ALL user's personas regardless of project
```
Fix: Add `.eq('project_id', projectId)` filter (only if the `personas` table has a `project_id` column — verify schema first).

---

## 6. Database Migration — Required Columns

**Table:** `market_analyses`

The following columns are referenced in service code but do not exist in the current schema (DB insert skips them when context is null, but they must exist for when context is non-null):

| Column | Type | Nullable | Default | Purpose |
|--------|------|----------|---------|---------|
| `context_snapshot` | `jsonb` | YES | `null` | Full `toPromptSnapshot()` result sent to AI |
| `source_ids` | `text[]` | YES | `'{}'` | IDs of knowledge/vault/library items used |
| `coverage` | `float4` | YES | `null` | 0.0–1.0 context coverage score |
| `missing_data` | `text[]` | YES | `'{}'` | Labels for missing data at analysis time |
| `version` | `int4` | YES | `1` | Monotonic version number per project |
| `supersedes_id` | `uuid` | YES | `null` | FK → `market_analyses.id` for versioning chain |
| `confidence` | `float4` | YES | `null` | AI-reported confidence score |
| `generated_at` | `timestamptz` | YES | `null` | Timestamp from `ProjectIntelligenceContext.generatedAt` |
| `deleted_at` | `timestamptz` | YES | `null` | Soft delete timestamp |

**Migration must be:** idempotent, non-destructive (all new columns nullable or with defaults).

---

## 7. Read-Only Providers — No Changes Needed

All fetch/read providers in `lib/providers/market_analysis_provider.dart` call only `fetch*` methods. No context integration needed. Schema changes require updating `fetchAll()` to filter `WHERE deleted_at IS NULL`.

| Provider | Service method |
|----------|---------------|
| `marketAnalysesProvider` | `fetchAll()` — **must add `deleted_at IS NULL` filter after migration** |
| `marketAnalysesByProjectProvider` | `fetchAll(projectId: projectId)` — same |
| `marketAnalysisByIdProvider` | `fetchById(id)` — add check or rely on RLS |
| `competitorsByAnalysisProvider` | `fetchCompetitors(id)` |
| `gapAnalysisByAnalysisProvider` | `fetchGapAnalysis(id)` |
| `opportunitiesByAnalysisProvider` | `fetchOpportunities(id)` |
| `nichesByAnalysisProvider` | `fetchNiches(id)` |
| `contentClusterByAnalysisProvider` | `fetchContentCluster(id)` |
| `revenuePlanByAnalysisProvider` | `fetchRevenuePlan(id)` |
| `allRevenuePlansProvider` | `fetchAllRevenuePlans()` |
| `revenuePlansByProjectProvider` | `fetchAllRevenuePlans(projectId: projectId)` |

---

## 8. KnowledgeVaultScreen / ContentLibraryScreen

Both screens are pure CRUD — they do not call `MarketAnalysisService`. No integration changes needed in these screens for Phase 11H. They are the *sources* consumed by `ProjectIntelligenceContextService.buildForProject()`, which already calls `KnowledgeService.fetchAll()` and `ContentService.fetchAll()`.

---

## 9. IveOverlay Context Integration

**File:** `lib/shared/widgets/ive_overlay.dart`

`_buildCopilotContext()` (lines 175–194) already passes `topProjectsSnapshot` and `knowledgeItemsSummary` to `CopilotContextData`. This is the IVE chat path — separate from the `MarketAnalysisService` write path.

The IVE contextual buttons inside market intelligence result screens (competitor, gap, revenue, allocation) need `IveContextData` to include `marketAnalysisId` so the copilot can reference the current analysis. Current `IveContextData` model must be checked for this field.

---

## 10. Implementation Order (post-map)

1. **Database migration** (G7, G8) — add 9 columns to `market_analyses`, update `fetchAll` filters
2. **Fix `ProjectIntelligenceContextService`** (G5) — fetch vault items; (G6) filter personas by projectId
3. **Wire `ProjectIntelligenceContextService` into call sites** (G1) — all 6+1 screens
4. **Fix `analyze` projectId forwarding** (G2) — screen → notifier → service
5. **Fix `buildRevenuePlan` projectId forwarding** (G3) — screen → service
6. **Add `context` param to `buildContentCluster`** (G4) — service method + screen
7. **Fix `ProjectCommandCenterScreen._analyzeWithKnowledge`** — route through service or inject context
8. **Soft delete** — `delete()` → set `deleted_at`, `fetchAll` excludes soft-deleted rows
9. **Write tests** — 25+ covering all above scenarios
10. **Build APK** and generate final audit documents
