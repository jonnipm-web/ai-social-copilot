# Impact — Dossier UI Contract (IV-IMPACT-I5)

What the Flutter UI (`lib/features/impact/`) relies on from the I4 contract
(`impact-dossier/1`, see IMPACT_DOSSIER_SCHEMA.md), and what it refuses.

## Transport

`functions.invoke('impact-lab', body)` with the caller's session. Body is
exactly the action + its params — never a role, user id or key:

| Call | Body |
|---|---|
| list | `{action:'list_investigations'}` |
| live dossier | `{action:'get_dossier', investigation_id, lang}` |
| snapshot | `{action:'export_dossier', investigation_id, lang}` |
| verify | `{action:'verify_dossier', investigation_id, content_hash, envelope}` |

`functions_client 2.6.0` throws `FunctionException(status, details)` on
non-2xx; `impactErrorFrom(status, body)` maps it (401 auth · 403/404
notAvailable · 413 or `DOSSIER_TOO_LARGE` tooLarge · 429 rateLimited +
`retry_after` (default 60) · ≥500 server · other invalidRequest). Any other
failure → network.

## Success envelope — accepted only if

- `ok === true` and `action` equals the action sent, and `data` is an object;
- `data.dossier.schemaVersion` and `data.dossier.content.schemaVersion` are
  `impact-dossier/1`;
- `content.isFindingOfWrongdoing === false` and `content.isPublication === false`;
- `integrity.contentHash` and `envelope.kind` are present;
- for `export_dossier`: `envelope.kind === 'SNAPSHOT'`;
- for `verify_dossier`: `state` present and `integrityIsNotTruth === true`.

Otherwise → `contract` error; **nothing** of the document is rendered.

## Fields read (all optional unless listed above; missing → empty / "—")

- `content`: `asOf`, `dossierStatus`, `investigation.status`, `subject`
  (`declaredIdentity.{legalName, registrations, domains}`, `identityStatus`,
  `identityConfirmed`), `registryFacts[]`, `registryConflicts[]`,
  `claims[]` (`text`, `textWithheld`, `textRedacted`, `textAttribution`,
  `verification`, `reverificationPending`, `reverificationReasons`,
  `disputeRefs`), `evidence[]` (`excerpt`, `excerptWithheld`,
  `excerptRedacted`, `excerptAttribution`, `locator.artifact`,
  `locatorState`), `sources[]` (`publisher`, `host.provider`,
  `userSubmitted`), `disputes[]`, `limitations[]`, `doesNotEstablish[]`,
  `summary` (incl. `byStatus`).
- `verification`: `status`, `displayClass`, `sufficiency`, `gaps`,
  `rulesApplied`, `policyVersion`, `evaluatedAt`, `supporting`,
  `partiallySupporting`, `contradicting`, `contextual`, `excluded`,
  `conflicts[].positions[]`, `independence.{independentVoices, sources}`.
- `data.text` (server text rendering), `data.labels` (server vocabulary).

## Invariants the UI keeps

- **Counts** come from `content.summary`; the UI never recounts.
- **Labels** come from `data.labels`; an unknown code is shown raw, never
  replaced with an invented word.
- **Export** copies `data.dossier` (re-indented JSON of the same object) and
  `data.text` as received. The content hash is over the canonical content
  (IMPACT_DOSSIER_EXPORT.md), so indentation does not affect verification.
- **Verify** sends `envelope` as the exact object received.
- **Withheld** text is never requested or reconstructed; only the fact of
  withholding is shown.
- **Conflicts**: positions rendered in server order, side by side, none
  highlighted.

## Fixtures and drift

`test/fixtures/impact/*.json` (13 files) are produced by the real Lab
service (`_shared/impact/fixtures/ui_fixtures.ts`, synthetic XA
organizations, fixed clock). `ui_fixtures_test.ts` (UI-FIX-01, in the Impact
core CI) fails when the committed files drift from what the engine produces.
Regenerate: `deno run --allow-read --allow-write supabase/tests/impact_ui_fixtures.ts`.

## Tests

`test/features/impact/`: `impact_domain_test.dart` (UI-DOM-01..11,
UI-API-01..08), `impact_screens_test.dart` (UI-GATE, UI-HOME, UI-DOS §48
scenarios A–F + empty, UI-CLM, UI-ERR, UI-EXP, UI-RSP, UI-A11Y),
`impact_routing_test.dart` (UI-RT-01..05 incl. deep link);
`test/core/modules/route_policy_test.dart` lists both routes.
