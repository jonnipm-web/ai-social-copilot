# InsightValues Quant — Market Calendar (IV-QUANT-DATA-PLANE-AND-API-02)

Replaces the Foundation's CALENDAR_NAIVE freshness for supported venues.
Code: `supabase/functions/_shared/quant/calendar.ts`, `session_freshness.ts`.

## 1. Scope

| MIC | Calendar | Timezone | Session | Early close |
|---|---|---|---|---|
| XNYS | NYSE | America/New_York | 09:30–16:00 | 13:00 (Jul 3 when Jul 4 is Tue–Fri; day after Thanksgiving; Dec 24 Mon–Thu) |
| XNAS | Nasdaq (same holidays) | America/New_York | 09:30–16:00 | same |
| XLON | London Stock Exchange | Europe/London | 08:00–16:30 | 12:30 on Dec 24 / Dec 31 (weekdays) |

Supported years: **2015–2030**. Outside that range, for any other MIC, or
for WEEKLY/MONTHLY data → `CALENDAR_UNKNOWN`: freshness falls back to the
Foundation's calendar-naive policy, `basis = CALENDAR_NAIVE`, and the
result carries the `CALENDAR_NAIVE` warning. An open/closed state is never
invented (`marketState = null`).

## 2. Holiday rules (no dependency, no hand-typed yearly tables)

* **US:** New Year (Sat → not observed, NYSE Rule 7.2; Sun → Mon), MLK (3rd
  Mon Jan), Washington's Birthday (3rd Mon Feb), Good Friday (Easter − 2,
  Meeus/Jones/Butcher computus), Memorial (last Mon May), Juneteenth (from
  2022), Independence Day, Labor (1st Mon Sep), Thanksgiving (4th Thu Nov),
  Christmas; weekend observance Sat → Fri, Sun → Mon. One-off closures:
  2018-12-05, 2025-01-09.
* **UK:** New Year (substitute Mon), Good Friday, Easter Monday, Early May
  (1st Mon; 2020 → 8 May), Spring (last Mon May; 2022 → 2+3 June), Summer
  (last Mon Aug), Christmas/Boxing Day with substitutes. One-off closures:
  2022-09-19, 2023-05-08.

Why rules instead of a package: no maintained, audited TypeScript exchange
calendar exists that is safe to adopt (dependency audit, §54 of the
mission); rules + dated one-offs are verifiable against the published
schedules. Tests CAL-01/02 pin 10 full years of published schedules.

**Documented limitation:** unannounced closures (national mourning,
emergencies, systems outages) cannot be predicted by rules. After any such
event the one-off list must be updated; a vendor calendar feed is the
long-term source (QUANT_VENDOR_ASSESSMENT.md).

## 3. Freshness semantics

* **DAILY:** judged in sessions. `lastCompletedSession` = latest trading
  day whose close + 2 h publication grace ≤ now (exchange time).
  `sessionsBehind` = trading days in (newest bar, lastCompletedSession]:
  0 FRESH · 1 DELAYED · ≥ 2 STALE. Weekends and holidays are not staleness.
  A bar for today's running session → FRESH + `PARTIAL_SESSION_BAR`; a bar
  dated after today → UNKNOWN.
* **INTRADAY:** while the market is closed, age runs from the last session
  close (a Friday 15:59 bar is FRESH all weekend); while open, from now.
* Warnings: `MISSING_SESSIONS` (trading sessions with no bar — never
  filled), `NON_SESSION_BARS` (bars dated on non-trading days).
* Reference time: `provenance.sourceAsOf` when declared (and consistent),
  else the newest bar.

## 4. Timezone

Canonical timestamps stay UTC. Session evaluation converts with `Intl`
(IANA zones) using a two-pass offset resolution, so DST transitions are
exact (tests CAL-04: 14:30Z in EST vs 13:30Z in EDT; 07:00Z London BST).
Date-only daily bars are session-date labels, not instants.

## 5. Codex CXA-03 (rejected, pinned)

Codex claimed 2021-12-31 should be a US holiday. NYSE Rule 7.2: when New
Year's Day falls on a Saturday the market is **not** closed on the
preceding Friday — NYSE traded on 2021-12-31. Test CAL-07 pins this.

## 6. Codex CXF2-01 (rejected, pinned)

Codex Final claimed NYSE closed on 2021-06-18 for Juneteenth. US equity
markets were **open** that day (Fortune, 2021-06-18: "Juneteenth … markets
open"; NY Fed operating policy 2021-06-17); exchanges first closed for
Juneteenth in 2022 (observed Monday 2022-06-20). NYSE filing SR-NYSE-2021-56
adds the holiday from 2022. Test CAL-08 pins this.
