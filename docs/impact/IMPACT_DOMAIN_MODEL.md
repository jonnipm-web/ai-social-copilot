# Impact — Domain Model

Code: `supabase/functions/_shared/impact/types.ts`.

## 1. Epistemic classes

| Class | Meaning | Example |
|---|---|---|
| FACT | Established by an AUTHORITATIVE source **within its scope** | Registry: "registered, number XA-1234567" |
| CLAIM | Someone asserted it (claimant recorded) | Website: "we built 20 wells" |
| EVIDENCE | Material related to a claim | Water-authority record listing 20 wells |
| INFERENCE | Derived by the system, always labelled | "sources disagree" |
| ALLEGATION | Accusation not established by an authority | News allegation; open investigation |
| CONFLICT | Sources disagree; no side chosen | 20 vs 12 schools |
| UNKNOWN | Not determined | Inconclusive / outdated |
| ABSENCE_OF_EVIDENCE | Nothing found | **Not** evidence of wrongdoing |

Rules: a self-declaration is a CLAIM; a journalistic allegation is not a fact
established in court; missing evidence is not evidence of fraud.

## 2. Entities

Implemented (Foundation core): `Organization`, `ImpactProject`, `Campaign`,
`Source`, `Claim`, `EvidenceItem`, `VerificationResult`, `ConflictRecord`,
`Indicator` (risk/positive/gap), `CanonicalRegistryRecord`,
`FinancialDisclosure`, `ImpactMetric`, `Investigation`, `Dispute`,
`AuditEvent`, `ImpactReport` (VerificationReport/profile).

Modelled only by fields (no dedicated engine yet): `Location` (coarse by
design), `BeneficiaryClaim` (= `Claim` of kind `BENEFICIARY_COUNT`, aggregate
only).

## 3. Organization identity

A name is never identity. `OrganizationIdentity` = legal name, public name,
aliases, registrations (`{jurisdiction, scheme, value}`), domains,
jurisdictions — all optional (informal initiatives may have none).
`entity_resolution.ts` outcomes:

| Outcome | Rule | Merge? |
|---|---|---|
| CONFIRMED_MATCH | same country + scheme + normalized number, no domain contradiction | yes (only this) |
| PROBABLE_MATCH | domain + name agree, no country conflict | no |
| ENTITY_MATCH_UNCERTAIN | name/alias similarity only, or conflicting signals | no |
| DISTINCT | same scheme, different number (even with identical names) | no |
| INSUFFICIENT_IDENTIFIERS | nothing comparable | no |

Registration numbers are compared only within the same country and scheme.
A record's absence from another country's registry says nothing about
legality (no cross-jurisdiction inference).

## 4. Organization types

CHARITY · NGO · NONPROFIT · FOUNDATION · SOCIAL_ENTERPRISE ·
RELIGIOUS_ORGANIZATION · COMMUNITY_PROJECT · CROWDFUNDING_CAMPAIGN ·
INFORMAL_INITIATIVE · OTHER. No type implies a legal framework.

## 5. Jurisdiction

`{country (ISO 3166-1), subdivision?, registry?, legalFrameworkRef?}`.
Nothing is hardcoded to UK/US/BR. Fixtures use the user-assigned code `XA`.

## 6. Organization ≠ Project ≠ Campaign

- A legitimate organization can have a problematic project.
- A legitimate project can be imitated by a fake campaign.
- `Campaign.affiliation` ∈ VERIFIED / CLAIMED / UNKNOWN. **VERIFIED only from
  a SUPPORTED `AFFILIATION` claim about that campaign with a CONFIRMED
  subject** (`deriveAffiliation`). A campaign's own "verified" flag, a
  matching name or logo, or a look-alike domain never verifies it.
- Impersonation signals prepared: `DOMAIN_MISMATCH` (same registration,
  different domain), `UNVERIFIED_AFFILIATION`. Complex brand/lookalike
  detection is future work.

## 7. Claims

`Claim` = original text (never overwritten; language tag), kind, optional
structured quantity + impact level, claimant, subject (org/project/campaign),
period, source where it was made, extractedAt, origin
(MANUAL / STRUCTURED_IMPORT / LLM_EXTRACTED).

Statuses: UNVERIFIED · SUPPORTED · PARTIALLY_SUPPORTED · CONTRADICTED ·
INCONCLUSIVE · OUTDATED · DISPUTED. No TRUE/FALSE.

## 8. Financial transparency

`FinancialDisclosure` lines: revenue, donations, expenses, program,
administrative, fundraising, assets, liabilities; period, currency, source,
audited flag. `spendingShares()` is descriptive and carries
`DESCRIPTIVE_ONLY_NOT_AN_INDICATOR`; high overhead never produces an
indicator.

## 9. Impact chain

INPUT → ACTIVITY → OUTPUT → OUTCOME → IMPACT. Evidence at a lower level
cannot substantiate a higher-level claim (meals delivered ≠ improved
nutrition) — excluded as `LEVEL_MISMATCH`.

## 10. Beneficiaries and child safeguarding

Aggregated figures only. Evidence items must declare `personalData`;
PERSONAL, SENSITIVE and MINOR are rejected by the Foundation
(`SENSITIVE_DATA_REJECTED`). `Location` is country/region only. Photos and
documents about minors require a dedicated future policy.

## 11. Legal / criminal records

`LegalStage`: INVESTIGATION_OPENED, CHARGED, CONVICTED, ACQUITTED, DISMISSED,
SANCTIONED, SETTLED, UNDER_APPEAL, OVERTURNED, CLOSED_NO_ACTION. The exact
stage is always carried; investigation/charge/appeal are never a
contradiction and never guilt.
