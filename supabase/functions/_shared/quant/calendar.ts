/**
 * Market calendars — IV-QUANT-DATA-PLANE-AND-API-02 (QUANT_MARKET_CALENDAR.md).
 *
 * Rule-based exchange calendars for the launch markets: US equities (XNYS,
 * XNAS — same holiday schedule) and London (XLON). No dependency: holidays
 * are computed from their published RULES (Easter computus, "n-th weekday
 * of month", weekend observance) plus a short, dated list of one-off
 * closures. Session evaluation happens in the exchange's IANA timezone via
 * Intl; canonical timestamps stay UTC.
 *
 * Supported range is explicit (SUPPORTED_FROM_YEAR..SUPPORTED_TO_YEAR).
 * Outside it, or for any other MIC, the answer is CALENDAR_UNKNOWN — the
 * engine never invents an open/closed state. Unannounced future closures
 * (national mourning, emergencies) cannot be predicted by rules: documented
 * residual, to be closed by a vendor calendar feed.
 */

export type CalendarId = 'XNYS' | 'XNAS' | 'XLON';
export const SUPPORTED_FROM_YEAR = 2015;
export const SUPPORTED_TO_YEAR = 2030;

interface CalendarDef {
  readonly id: CalendarId;
  readonly timezone: string;
  /** Local session times, minutes after midnight. */
  readonly open: number;
  readonly close: number;
  readonly earlyClose: number;
  readonly holidays: (year: number) => ReadonlySet<string>;
  readonly earlyCloses: (year: number) => ReadonlySet<string>;
}

// ---------------------------------------------------------------- date helpers (UTC-date arithmetic on YYYY-MM-DD)

const DAY_MS = 86_400_000;

export function ymd(y: number, m: number, d: number): string {
  return `${String(y).padStart(4, '0')}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
}
function toDayNumber(date: string): number {
  const [y, m, d] = date.split('-').map(Number);
  return Math.floor(Date.UTC(y, m - 1, d) / DAY_MS);
}
function fromDayNumber(n: number): string {
  const dt = new Date(n * DAY_MS);
  return ymd(dt.getUTCFullYear(), dt.getUTCMonth() + 1, dt.getUTCDate());
}
export function addDays(date: string, n: number): string {
  return fromDayNumber(toDayNumber(date) + n);
}
/** 0 = Sunday … 6 = Saturday. */
export function weekday(date: string): number {
  return new Date(toDayNumber(date) * DAY_MS).getUTCDay();
}
function isWeekend(date: string): boolean {
  const w = weekday(date);
  return w === 0 || w === 6;
}
/** n-th (1-based) given weekday of a month; n = -1 → last. */
function nthWeekday(y: number, m: number, wd: number, n: number): string {
  if (n > 0) {
    const first = ymd(y, m, 1);
    const offset = (wd - weekday(first) + 7) % 7;
    return addDays(first, offset + 7 * (n - 1));
  }
  const last = addDays(ymd(m === 12 ? y + 1 : y, m === 12 ? 1 : m + 1, 1), -1);
  return addDays(last, -((weekday(last) - wd + 7) % 7));
}
/** Gregorian Easter Sunday (anonymous Gregorian / Meeus–Jones–Butcher). */
export function easterSunday(y: number): string {
  const a = y % 19, b = Math.floor(y / 100), c = y % 100, d = Math.floor(b / 4), e = b % 4;
  const f = Math.floor((b + 8) / 25), g = Math.floor((b - f + 1) / 3), h = (19 * a + b - d - g + 15) % 30;
  const i = Math.floor(c / 4), k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7, m = Math.floor((a + 11 * h + 22 * l) / 451);
  const month = Math.floor((h + l - 7 * m + 114) / 31), day = ((h + l - 7 * m + 114) % 31) + 1;
  return ymd(y, month, day);
}

// ---------------------------------------------------------------- US (NYSE / Nasdaq)

/** NYSE Rule 7.2 observance: Saturday → preceding Friday, Sunday → following Monday. */
function usObserved(date: string): string {
  const w = weekday(date);
  return w === 6 ? addDays(date, -1) : w === 0 ? addDays(date, 1) : date;
}

/** One-off full-day closures inside the supported range (national days of mourning). */
const US_SPECIAL_CLOSURES = ['2018-12-05', '2025-01-09'];

function usHolidays(y: number): ReadonlySet<string> {
  const s = new Set<string>();
  // New Year's Day: a Saturday Jan 1 is NOT moved to Friday Dec 31 (NYSE rule).
  const ny = ymd(y, 1, 1);
  if (weekday(ny) !== 6) s.add(usObserved(ny));
  s.add(nthWeekday(y, 1, 1, 3)); // Martin Luther King Jr. Day
  s.add(nthWeekday(y, 2, 1, 3)); // Washington's Birthday
  s.add(addDays(easterSunday(y), -2)); // Good Friday
  s.add(nthWeekday(y, 5, 1, -1)); // Memorial Day
  if (y >= 2022) s.add(usObserved(ymd(y, 6, 19))); // Juneteenth
  s.add(usObserved(ymd(y, 7, 4))); // Independence Day
  s.add(nthWeekday(y, 9, 1, 1)); // Labor Day
  s.add(nthWeekday(y, 11, 4, 4)); // Thanksgiving
  s.add(usObserved(ymd(y, 12, 25))); // Christmas
  for (const d of US_SPECIAL_CLOSURES) if (d.startsWith(`${y}-`)) s.add(d);
  return s;
}

/** 13:00 ET early closes: July 3 when July 4 falls Tue–Fri; day after Thanksgiving; Dec 24 Mon–Thu. */
function usEarlyCloses(y: number): ReadonlySet<string> {
  const s = new Set<string>();
  const j4 = weekday(ymd(y, 7, 4));
  if (j4 >= 2 && j4 <= 5) s.add(ymd(y, 7, 3));
  s.add(addDays(nthWeekday(y, 11, 4, 4), 1));
  const x24 = weekday(ymd(y, 12, 24));
  if (x24 >= 1 && x24 <= 4) s.add(ymd(y, 12, 24));
  return s;
}

// ---------------------------------------------------------------- UK (London Stock Exchange)

/** One-off closures inside the supported range (state funeral, coronation). */
const UK_SPECIAL_CLOSURES = ['2022-09-19', '2023-05-08'];

function ukHolidays(y: number): ReadonlySet<string> {
  const s = new Set<string>();
  const ny = ymd(y, 1, 1);
  s.add(weekday(ny) === 6 ? addDays(ny, 2) : weekday(ny) === 0 ? addDays(ny, 1) : ny);
  const easter = easterSunday(y);
  s.add(addDays(easter, -2)); // Good Friday
  s.add(addDays(easter, 1)); // Easter Monday
  // Early May bank holiday (moved to Fri 8 May in 2020 for VE Day).
  s.add(y === 2020 ? '2020-05-08' : nthWeekday(y, 5, 1, 1));
  // Spring bank holiday (moved to Thu 2 + Fri 3 June in 2022, Platinum Jubilee).
  if (y === 2022) {
    s.add('2022-06-02');
    s.add('2022-06-03');
  } else s.add(nthWeekday(y, 5, 1, -1));
  s.add(nthWeekday(y, 8, 1, -1)); // Summer bank holiday
  // Christmas + Boxing Day with substitute days.
  const xmas = ymd(y, 12, 25), w = weekday(xmas);
  if (w === 6) {
    s.add(ymd(y, 12, 27));
    s.add(ymd(y, 12, 28));
  } else if (w === 0) {
    s.add(ymd(y, 12, 26));
    s.add(ymd(y, 12, 27));
  } else if (w === 5) {
    s.add(xmas);
    s.add(ymd(y, 12, 28));
  } else {
    s.add(xmas);
    s.add(ymd(y, 12, 26));
  }
  for (const d of UK_SPECIAL_CLOSURES) if (d.startsWith(`${y}-`)) s.add(d);
  return s;
}

/** 12:30 London early closes on Dec 24 and Dec 31 when they are weekdays. */
function ukEarlyCloses(y: number): ReadonlySet<string> {
  const s = new Set<string>();
  for (const d of [ymd(y, 12, 24), ymd(y, 12, 31)]) if (!isWeekend(d)) s.add(d);
  return s;
}

// ---------------------------------------------------------------- registry

const US_DEF = { timezone: 'America/New_York', open: 9 * 60 + 30, close: 16 * 60, earlyClose: 13 * 60, holidays: usHolidays, earlyCloses: usEarlyCloses };
const CALENDARS: Readonly<Record<CalendarId, CalendarDef>> = {
  XNYS: { id: 'XNYS', ...US_DEF },
  XNAS: { id: 'XNAS', ...US_DEF },
  XLON: { id: 'XLON', timezone: 'Europe/London', open: 8 * 60, close: 16 * 60 + 30, earlyClose: 12 * 60 + 30, holidays: ukHolidays, earlyCloses: ukEarlyCloses },
};

export interface MarketCalendar {
  readonly id: CalendarId;
  readonly timezone: string;
}

/** Calendar for an ISO 10383 MIC, or null (→ CALENDAR_UNKNOWN). */
export function calendarForMic(mic: string | undefined): MarketCalendar | null {
  return mic !== undefined && Object.prototype.hasOwnProperty.call(CALENDARS, mic)
    ? { id: CALENDARS[mic as CalendarId].id, timezone: CALENDARS[mic as CalendarId].timezone }
    : null;
}

function inRange(date: string): boolean {
  const y = Number(date.slice(0, 4));
  return y >= SUPPORTED_FROM_YEAR && y <= SUPPORTED_TO_YEAR;
}

/** Trading day? null when outside the supported range (unknown, not "closed"). */
export function isTradingDay(cal: MarketCalendar, date: string): boolean | null {
  if (!inRange(date)) return null;
  return !isWeekend(date) && !CALENDARS[cal.id].holidays(Number(date.slice(0, 4))).has(date);
}

// ---------------------------------------------------------------- timezone conversion (Intl, no dependency)

const formatters = new Map<string, Intl.DateTimeFormat>();
function fmt(tz: string): Intl.DateTimeFormat {
  let f = formatters.get(tz);
  if (!f) {
    f = new Intl.DateTimeFormat('en-US', {
      timeZone: tz, hourCycle: 'h23', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit',
    });
    formatters.set(tz, f);
  }
  return f;
}

/** Exchange-local calendar date and minute-of-day of a UTC instant. */
export function localDateTime(ms: number, tz: string): { date: string; minutes: number } {
  const p = Object.fromEntries(fmt(tz).formatToParts(new Date(ms)).map((x) => [x.type, x.value]));
  return { date: `${p.year}-${p.month}-${p.day}`, minutes: Number(p.hour) * 60 + Number(p.minute) };
}

/** UTC instant of a local wall-clock time in `tz` (two-pass offset resolution, DST-safe for session hours). */
export function localToUtc(date: string, minutes: number, tz: string): number {
  const [y, m, d] = date.split('-').map(Number);
  const guess = Date.UTC(y, m - 1, d, Math.floor(minutes / 60), minutes % 60);
  let utc = guess;
  for (let i = 0; i < 2; i++) {
    const l = localDateTime(utc, tz);
    const [ly, lm, ld] = l.date.split('-').map(Number);
    const localAsUtc = Date.UTC(ly, lm - 1, ld, Math.floor(l.minutes / 60), l.minutes % 60);
    utc = guess - (localAsUtc - utc);
  }
  return utc;
}

export interface SessionTimes {
  readonly date: string;
  readonly openMs: number;
  readonly closeMs: number;
  readonly earlyClose: boolean;
}

export function sessionTimes(cal: MarketCalendar, date: string): SessionTimes | null {
  const trading = isTradingDay(cal, date);
  if (!trading) return null;
  const def = CALENDARS[cal.id];
  const early = def.earlyCloses(Number(date.slice(0, 4))).has(date);
  return {
    date,
    openMs: localToUtc(date, def.open, def.timezone),
    closeMs: localToUtc(date, early ? def.earlyClose : def.close, def.timezone),
    earlyClose: early,
  };
}

/** Walks back at most 20 days (longest closure run in range is far shorter); null if unknown. */
export function previousTradingDay(cal: MarketCalendar, date: string): string | null {
  let d = date;
  for (let i = 0; i < 20; i++) {
    d = addDays(d, -1);
    const t = isTradingDay(cal, d);
    if (t === null) return null;
    if (t) return d;
  }
  return null;
}

/** Trading days in the half-open interval (from, to]; null if any day is outside the supported range. */
export function tradingDaysBetween(cal: MarketCalendar, from: string, to: string): string[] | null {
  const out: string[] = [];
  for (let n = toDayNumber(from) + 1; n <= toDayNumber(to); n++) {
    const d = fromDayNumber(n);
    const t = isTradingDay(cal, d);
    if (t === null) return null;
    if (t) out.push(d);
  }
  return out;
}

export type MarketState = 'OPEN' | 'CLOSED';

export interface MarketClock {
  readonly localDate: string;
  readonly state: MarketState;
  /** Latest session whose close is at or before `now` (+ publication grace for EOD data). */
  readonly lastCompletedSession: string | null;
  /** Close instant of the latest session that has closed at or before `now`. */
  readonly lastCloseMs: number | null;
  readonly currentSession: SessionTimes | null;
}

/** Grace after the close before an end-of-day bar for that session is expected to exist. */
export const EOD_PUBLICATION_GRACE_MS = 2 * 60 * 60 * 1000;

/** Market state at `nowMs`, or null when the calendar cannot answer (out of range). */
export function marketClock(cal: MarketCalendar, nowMs: number): MarketClock | null {
  if (!Number.isFinite(nowMs)) return null;
  const local = localDateTime(nowMs, cal.timezone);
  if (isTradingDay(cal, local.date) === null) return null;
  const today = sessionTimes(cal, local.date);
  const open = today !== null && nowMs >= today.openMs && nowMs < today.closeMs;
  let lastClose: SessionTimes | null = today !== null && nowMs >= today.closeMs ? today : null;
  if (!lastClose) {
    const prev = previousTradingDay(cal, local.date);
    if (prev === null) return null;
    lastClose = sessionTimes(cal, prev);
  }
  let completed: string | null = null;
  if (today !== null && nowMs >= today.closeMs + EOD_PUBLICATION_GRACE_MS) completed = today.date;
  else {
    const prev = previousTradingDay(cal, local.date);
    if (prev === null) return null;
    const prevTimes = sessionTimes(cal, prev);
    // The previous session's grace can only straddle `now` just after midnight local time.
    completed = prevTimes && nowMs >= prevTimes.closeMs + EOD_PUBLICATION_GRACE_MS ? prev : previousTradingDay(cal, prev);
  }
  return {
    localDate: local.date,
    state: open ? 'OPEN' : 'CLOSED',
    lastCompletedSession: completed,
    lastCloseMs: lastClose?.closeMs ?? null,
    currentSession: today,
  };
}
