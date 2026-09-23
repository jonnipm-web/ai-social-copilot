# Impact — Source Lineage and Independence (I2, CF-04)

Code: `_shared/impact/source_lineage.ts` (`impact-lineage/1`), used by the
engine (`impact-verification/9`). Tests: L-01..14, MUT-03, gate1 CF-04/FV*,
SQL I2-12..15, PD-03.

## 1. Question

"Did this source publish original information, or is it reproducing
another?" — and, for corroboration, "how many INDEPENDENT voices support the
claim?". **Authority ≠ independence**: a highly authoritative source can be
reproducing another.

## 2. Signals (all server-derived)

| Signal | How | Certainty |
|---|---|---|
| `syndicatedFrom` | provider declaration, or analyst label | declared (merge-only) |
| `derivedFrom` | analyst label: cites / summarizes a publisher | declared (merge-only) |
| identical content | sha-256 of deterministically normalized text | declared → later copy is SYNDICATED |
| near duplicate | MinHash (32 slots, word 5-shingles) ≥ 0.8 | POSSIBLE |
| wire credit / markers | Reuters, AP, AFP, "via X" credit line, "originally published", "republished from" | POSSIBLE (a signal, not proof) |
| primary publisher | the trusted provider publishes its OWN records (registers, courts, government datasets) | the only positive evidence of ORIGINAL |

A client submits content TEXT; the server computes fingerprint, sketch and
markers and keeps only those (never the text). A client can never send
"independent", "original", a fingerprint, a sketch or markers (L-14).

Normalization for fingerprints removes case, accents, punctuation, UI clock
times, "x hours ago" and URL query/fragment tracking; it keeps words, numbers
and dates ("20 wells" ≠ "200 wells").

## 3. States

ORIGINAL (established primary publisher) · SYNDICATED · DERIVED ·
POSSIBLE_LINEAGE · UNKNOWN. **UNKNOWN is not independent.**

## 4. Counting voices

Union-find over every supplied source (publisher identity, declared links,
identical content, near duplicates, wire nodes). Then

    voices = components containing an ESTABLISHED original
             + (1 if none, but other counted components exist)

- different URL, domain, headline or publisher name is never independence;
- two unestablished sources are one voice at most (`INDEPENDENCE_NOT_ESTABLISHED`);
- MULTI_SOURCE_SUPPORT needs two independent established originals.

Lineage only MERGES voices: it never removes evidence, never creates
SUPPORTED/CONTRADICTED and never decides a conflict. A similarity false
positive can therefore only understate corroboration, and a POSSIBLE link
asks for human review (`POSSIBLE_LINEAGE` gap + review reason) — L-08.

Lineage inputs of all sources are part of `evidenceSetHash`; results are
order-independent; comparisons are bounded (200 sources, 50 reported links);
marker regexes are linear (L-13).

## 5. CF-04 — CLOSED

Criterion (mission §32): known syndication / republication must never be
counted as independence. Demonstrated by L-01..L-10 and MUT-03 (removing the
detection turns a copy into a second voice). Honest limits: an unlabelled copy
with materially rewritten text may evade detection — it is then UNKNOWN and
still counts as at most one voice together with other unestablished sources,
so it cannot inflate independence; only two *established* originals produce
multi-source corroboration.

## 6. Policy change vs Foundation/I1

Foundation counted distinct publisher names as voices unless linked. I2
requires positive evidence: golden case G (government record + academic
study) moved from MULTI_SOURCE_SUPPORT to INDEPENDENT_SUPPORT — the academic
study's independence from the government data is not established. Status is
unchanged (SUPPORTED); only the corroboration label is more conservative.
