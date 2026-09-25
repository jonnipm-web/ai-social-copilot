# Impact — Product UX (IV-IMPACT-I5-PRODUCT-UX-01)

**Status: EXPERIMENTAL, admin/Lab only. Not deployed; not public; no
commercial exposure.** The `impact` module stays `inDevelopment`
(lifecycle EXPERIMENTAL, `commercialEnabled: false`); I5 only sets
`adminClickable: true` and `route: /impact`.

## Principle

The UI is a **consumer** of the I4 dossier contract. It never computes a
status, a class, a sufficiency, a count, a hash or a verdict; it never
re-translates the truth vocabulary (the server sends audited PT/EN labels
in `data.labels`). If the server document is not understood, nothing is
shown (fail closed) — a half-rendered dossier is worse than an error.

## Entry and navigation

| Route | Screen | Gate |
|---|---|---|
| `/impact` | Investigations of the caller (`list_investigations`) | route policy (EXPERIMENTAL ⇒ admin) + screen admin check + server admin entitlement |
| `/impact/:id` | Dossier of one investigation (`get_dossier`) | same; malformed id → "not available" with **no request** |
| (push) | Claim detail — from the dossier already loaded | inherits the dossier screen gate |

The screen check is fail-closed (renders only when the profile positively
resolved as admin; loading → spinner, error → admin-only message, **zero
requests** either way). The real authority is the server: admin
entitlement in `impact-lab`, ownership + RLS below it, rate limit.

## Dossier screen — reading order

1. **What it is**: subject name, *Live view* vs *Issued snapshot*, as-of
   date, and the standing note "organizes evidence; no score, ranking or
   verdict".
2. **Summary**: dossier status + server counts (claims/evidence/sources,
   by status, not verified, re-verification pending, open disputes,
   limitations).
3. **What this dossier does NOT establish** (emphasized) and
   **Limitations** (emphasized, grouped by code with the refs they apply
   to) — both **before** any claim, so no reader meets a claim without its
   caveats.
4. **Identity**: identity status (confirmed only by a registry), declared
   identity (quoted), registry records (official / test data / freshness
   at as-of), registry disagreements. No registry record ⇒ "this does not
   mean the organization is unregistered".
5. **Claims** (paged by 20, "show more (N)"; nothing is dropped): quoted
   text («…», attribution), status + class chips, re-verification pending,
   disputes. Tap → claim detail.
6. **Disputes**, **Sources & provenance** (publisher vs cloud host — the
   host is never the publisher; user uploads are context, never
   authority), **Integrity** (hash + algorithm + canonicalization; "the
   hash proves the content was not altered — not that it is true").
7. **Export** (see below).

Layout: one column below 1024 px; two columns (summary/caveats/identity |
claims/disputes/sources/integrity/export) at ≥ 1024 px; content max width
1280 px (840 px single column).

## Claim detail

Status / class / sufficiency chips; independent voices vs documents ("several
documents do not mean several independent sources"); evidence grouped as
the engine classified it (for / partial / against / context / excluded) with
excerpt (or "withheld for privacy"), publisher, host, user-submitted note and
document location (artifact · lines · locator state); disagreements with
**every position side by side, none chosen** (stacked on phones); gaps;
rules applied + policy version + evaluation time; re-verification reasons;
disputes.

## Export

- Pre-export confirmation lists the number of limitations that travel with
  the dossier, every "does not establish" statement, that a snapshot is a
  historical record, that the export is private (no public link, no
  sharing) and the formats (JSON, text; **no PDF**).
- `export_dossier` → SNAPSHOT; the UI shows snapshot ref + content hash.
- *Copy JSON* copies the server document; *Copy text* the server rendering.
  Nothing else: no URL, no share sheet, no file upload anywhere.
- *Verify snapshot* presents the issued hash + envelope to `verify_dossier`;
  the answer (CURRENT / STALE / NOT_ISSUED, envelope MISMATCH) is the
  server's. A MISMATCH is shown **before** "current".

## States

Loading (spinner), empty (no investigations / no claims), errors mapped
from the server (401 session, 403/404 *one* message "not found or
unavailable" — no oracle, 413 "exceeds the limit and was not truncated —
nothing partial is shown", 429 "try again in N s" from `retry_after`,
network, 5xx, unsupported contract). Retry only for network/5xx/429, and
only on user action.

## Visual language

Status is always **text + icon** in neutral tones (secondary container for
"needs attention": open dispute, pending re-verification, limitations). No
red/green verdict colours, no gauges, progress bars or score-like numbers.
Quoted text is italic in «» with its attribution; redaction and withholding
are stated explicitly.

## Accessibility and i18n

- Section titles are semantic headers (own semantics container — the card
  does not swallow the section into the heading); chips expose their label;
  each claim tile is one button labelled "Claim detail <ref>…".
- Tested: text-contrast and Android tap-target guidelines; text scale 2.0 on
  a 360 px phone with no overflow; sizes 320×640 → 1920×1080.
- UI chrome in ARB (`lib/l10n/app_pt.arb`, `app_en.arb`, keys `impact*`);
  dossier vocabulary from the server in the language requested
  (`lang` follows the app locale: `en` → en, anything else → pt).

## Out of scope (by mission rule)

No score (trust/fraud/corruption/donation), no people intelligence, no LLM
in the dossier path, no AEF actions (donate/report/publish), no public
sharing, no PDF, no deploy. Physical-device validation: see the mission
report.
