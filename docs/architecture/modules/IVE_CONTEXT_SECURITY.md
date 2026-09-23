# IVE Context Security

Mission: `IVE-INTELLIGENCE-CORE-01`. Threat → control → proof. "Proof" names
the executed test; everything is VERIFIED in Module Lab tests and
NOT_VERIFIED in production (nothing deployed).

| # | Threat | Control | Proof |
|---|---|---|---|
| 1 | Missing / anon JWT | `resolveAuthenticatedUser` before anything | AD-01, GH-* |
| 2 | User A asks for project B | ownership verified before any project read; 403 `PROJECT_FORBIDDEN`; no quota | AD-02 |
| 3 | A reads B's knowledge / memory (incl. unassigned rows) | explicit `user_id` filters + RLS + assembler re-filters every row by owner (rows without owner rejected) | AD-03/04/05 with a data source that ignores filters |
| 4 | Another project of the same user leaks | project filter on every row; knowledge = verified project + unassigned; memory = project + user scope | AD-03, IS-01 |
| 5 | Forged module id / plan / role / flags / context in the body | not read by any code path; capabilities from the Entitlement Core | AD-06..09, client contract test |
| 6 | Prompt injection in documents, memory, project text | every user-authored item inside `<dados_nao_confiaveis>`; envelope tags inside data neutralized; policy is a separate system message; sources/actions server-built | AD-10..13 (mutation-checked) |
| 7 | Forged `assistant` turns / stale transcript | transcript never sent as native turns — one enveloped data block labelled unverified | G1-01 |
| 8 | Bypass of AEF by wording, obfuscation, history, capability hint | canonicalized routing + latest user turns + `CONSEQUENTIAL` modules; no execution tool exists | AD-14/15, G1-02 (mutation-checked) |
| 9 | Forged / future surface | enum validation; inactive surfaces rejected | AD-16 |
| 10 | Malformed locale / project id / conversation; PostgREST filter injection via `project_id` | strict validation (UUID) before any query | AD-17 |
| 11 | Gigantic context | per-category budgets, message/turn caps | AD-18 |
| 12 | Provider failure / upstream text leak | normalized errors, refund | AD-19 |
| 13 | Entitlement outage | fail closed before reads | AD-20 |
| 14 | Quota abuse | quota after every free check; denials never reserve | AD-01/02/14/16/17/20/21/22 |
| 15 | Audit forgery via client correlation id | server-owned correlation id | G1-03 |
| 16 | Secrets persisted to memory | policy on raw + canonical text; RLS size cap | MM-01, ME-03 |
| 17 | Cross-user leak on a shared device (logout/login) | session reset + owner-bound device memory + race guard | `ive_session_isolation_test.dart` (mutation-checked) |
| 18 | Telemetry leakage | shape-only logs | IS-03 |
| 19 | Memory written into a foreign project | RLS WITH CHECK ownership | `ive_memory_rls_test.sql` T02/T06 (mutation-checked) |

Residual risks (documented, not closed here): lexical intent routing can
still miss novel phrasing (mitigated: no execution capability exists);
secret detection is pattern-based; quota refund is best-effort in the shared
helper; origin labels are not cryptographically attested (provenance only).
