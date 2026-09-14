# Commercial UI Standard

Status: PROPOSED (architecture mission COMMERCIAL-PRODUCT-ARCHITECTURE-10)
Owner gate: Agente Martins
Implements: mission brief Sections 11 (visual parts), 19, 20, 27, 28

## 1. Readability / responsive baseline

**Finding, not assumption**: `dashboard_screen.dart` (the literal
`DashboardScreen`) uses 10-18px text and does not obviously explain a
150%-zoom need on its own. The owner's readability complaints trace
concretely to `executive_decision_center_screen.dart`, where 9-12px text
is common (`_GateMetricRow`, `_SimpleCard`, badges) — this is a real,
located contributor, not a vague "make things bigger everywhere"
request.

Note for whoever scopes Phase F: "Dashboard" is ambiguous in this repo —
`lib/features/dashboard/screens/dashboard_screen.dart` (simple shortcut
grid, not read for full readability audit) and `executive_dashboard_
screen.dart` (separate file, not read in this mission) both exist.
Confirm which one the owner meant before changing either.

**Rule**: define a small typography scale (e.g. 3-4 named sizes:
label/body/title/heading) with a floor no smaller than ~12-13px for any
user-facing metric or label text, applied first to
`executive_decision_center_screen.dart`'s dense cards, then audited
elsewhere. Do not blanket-increase every screen 50% — the owner
explicitly warned against over-correcting ("Do NOT blindly increase
everything 50%" — mission Section 27).

## 2. Modals/dialogs

No modal-width defect was independently confirmed in this audit's file
reads (the owner's report is taken as valid input; no specific
overflowing dialog was pinned to a file:line in the research performed
for this mission). Standard to apply going forward: dialogs/modals must
fit a normal desktop viewport at 100% zoom, adapt responsively at phone
width, never force horizontal dragging, and expose vertical scrolling
when content exceeds viewport height. `showModalBottomSheet` (already
used by `showCopilotChat` and the Copilot sheet) is the existing pattern
to standardize on rather than introducing a second dialog primitive.

## 3. Project selector — architecture smell, not just a UX bug

The same horizontal project-chip picker is independently re-implemented
in at least 6 files: `content_library_screen.dart`,
`opportunity_lab_screen.dart`, `action_engine_screen.dart`,
`knowledge_vault_screen.dart`, `ecosystem_view_screen.dart`,
`knowledge_item_form_screen.dart`. Each defines its own private
`_FilterChip` class. Confirmed shape (`content_library_screen.dart`
lines 57-76): `SizedBox(height: 48, child: ListView(scrollDirection:
Axis.horizontal, ...))` with no scrollbar/fade/affordance indicating
more content off-screen — this is exactly the "projects hidden outside
viewport with no visible affordance" defect the owner reported, and it
is duplicated 6 times over.

**Standard**: extract one canonical `ProjectSelector` shared widget
(searchable dropdown/combobox for large project counts, or scrollable
chips with a visible scroll affordance for small counts — pick one
pattern consistent with the existing design system, per mission Section
20) and replace all 6 private implementations with it. This is a
consolidation, not 6 separate redesigns.

## 4. I18N standard

Infrastructure is solid and does not need rework: `LanguageNotifier`
already supports PT/EN with a deterministic fallback and persistence,
backed by standard Flutter `.arb` files
(`lib/l10n/app_localizations.dart` + arb resources).

**The gap is pure adoption, concentrated in one module.** All 8 Market
Intelligence screens have zero `AppLocalizations.of(context)` usage —
100% hardcoded strings. Confirmed AppBar titles alone:

| Screen | Title | Language |
|---|---|---|
| `market_intelligence_hub_screen.dart:141` | "Inteligência de Mercado" | PT |
| `market_intelligence_screen.dart:81` | "Market Intelligence" | **EN** |
| `competitor_discovery_screen.dart:47` | "Concorrentes" | PT |
| `gap_analysis_screen.dart:42` | "Gap Analysis" | **EN** |
| `content_cluster_screen.dart:56` | "Content Cluster Engine" | **EN** |
| `niche_discovery_screen.dart:43` | "Nichos & Sub-nichos" | PT |
| `opportunity_discovery_screen.dart:45` | "Oportunidades" | PT |
| `revenue_planner_screen.dart:62` | "Revenue Planner" | **EN** |

Worse than title-level mixing: `content_cluster_screen.dart` labels the
**same field** in two languages on the same screen — "Palavra-chave:"
(line 137) and "Keyword:" (line 253). `market_intelligence_screen.dart`
shows an English header ("Market Intelligence Engine", line 109)
directly above an all-Portuguese description (line 120).

**Rule**: every user-facing string in these 8 screens moves into the
existing `.arb`/`AppLocalizations` system — no new i18n mechanism is
needed, this is a migration of literal strings into the mechanism that
already works correctly everywhere else it's been adopted. Fast-track
this specifically for Market Intelligence per owner instruction
("already generally good, refine, don't redesign" — this is the
refinement).

**Scope boundary (Codex adversarial review, round 1, P2 — ACCEPTED):**
this migration applies only to **fixed product copy** — titles, labels,
buttons, badges, empty states, error strings, processing-state text. It
explicitly does **not** apply to AI-generated analysis content (gap
descriptions, competitor summaries, recommended-action text, etc.),
which cannot be pre-translated via `.arb` and must not be silently
treated as if it were localized UI. The standard for AI-generated text
is:
- Preserve the source language the model actually returned.
- If the interaction's requested language is known and differs from the
  content's language, label the content's language explicitly (e.g. a
  small badge) rather than presenting it as if it matched the UI
  language.
- User-authored content (e.g. a manual project description) is
  preserved verbatim, never auto-translated.
- Translation of AI/user content, if ever offered, is an explicit,
  separate user action — never an implicit side effect of an i18n
  migration meant for fixed UI strings.
This mirrors the mission brief's own caveat ("no mixed-language screens
unless the AI-generated source itself is in another language and
clearly marked") — the Market Intelligence migration must not blur this
line while fixing the AppBar-title-level mixing above.

## 5. Data/source truth standard

**Confirmed violation**: `opportunity_detail_screen.dart:477-482`
renders a raw truncated UUID directly to the user as if it were a
readable reference:
```dart
if (item.marketAnalysisId != null)
  _InfoRow(..., label: 'Análise de mercado',
    value: item.marketAnalysisId!.substring(0, 8) + '…'),
```
**Rule**: replace with the human-readable title/label of the referenced
analysis (already resolvable via existing `MarketAnalysis` lookups), not
a truncated ID. This is the concrete instance of Section 28's "never
expose raw internal DB IDs as sources" rule — not a hypothetical
concern.

`_SourcesList` in the same file renders `item.sources` strings verbatim
with no format sanitization — flagged as a **plausible but unconfirmed**
risk (depends on how the Knowledge/AI pipeline populates that field);
worth a targeted check in Phase D before or during the Opportunity Lab
work, not assumed broken.

**AI output labeling**: no screen audited in this mission currently
distinguishes SOURCE/EVIDENCE from INFERENCE from RECOMMENDATION in AI
output — this is Section 28's second rule and is net-new UX work,
scoped to whichever screens present AI-generated justifications
(Opportunity Lab detail, Market Intelligence recommended actions/
highlighted opportunities, per Sections 09/17).

## 6. Score explainability

`competitor_discovery_screen.dart`'s `_ScoreItem` renders
`similarityScore`/`authorityScore`/`relevanceScore`/`overallScore` as
raw integers with no explanation, tooltip, or IVE-explain affordance —
confirmed opaque-number pattern the owner flagged for Section 18. Also
confirmed: `competitor.weaknesses` exists on the model but is never
rendered anywhere in this screen (only `strengths` is shown) — an
asymmetry to fix alongside adding score explanation, not a separate
effort.
