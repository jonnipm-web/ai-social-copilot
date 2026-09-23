/**
 * Canonical text form for security-relevant matching (IVE-INTELLIGENCE-CORE-01,
 * Codex Gate 1 IG1-03/IG1-05): intent routing and secret detection must not
 * be evadable with zero-width characters, non-breaking spaces, full-width
 * forms, accents or common Cyrillic/Greek look-alike letters.
 */

// Cyrillic / Greek letters that render like Latin ones.
const HOMOGLYPHS: Record<string, string> = {
  '\u0430': 'a', '\u0435': 'e', '\u043E': 'o', '\u0440': 'p', '\u0441': 'c', '\u0443': 'y', '\u0445': 'x', '\u0456': 'i', '\u0458': 'j', '\u0455': 's', '\u0501': 'd', '\u0261': 'g', '\u04BB': 'h', '\u04CF': 'l', '\u043A': 'k', '\u043C': 'm', '\u043D': 'h', '\u0442': 't', '\u0432': 'b',
  '\u0410': 'a', '\u0412': 'b', '\u0415': 'e', '\u041A': 'k', '\u041C': 'm', '\u041D': 'h', '\u041E': 'o', '\u0420': 'p', '\u0421': 'c', '\u0422': 't', '\u0425': 'x', '\u0423': 'y', '\u0406': 'i', '\u0405': 's',
  '\u03B1': 'a', '\u03B5': 'e', '\u03BF': 'o', '\u03C1': 'p', '\u03C5': 'u', '\u03BD': 'v', '\u03B9': 'i', '\u03BA': 'k', '\u03C4': 't', '\u03C7': 'x',
  '\u0391': 'a', '\u0392': 'b', '\u0395': 'e', '\u0396': 'z', '\u0397': 'h', '\u0399': 'i', '\u039A': 'k', '\u039C': 'm', '\u039D': 'n', '\u039F': 'o', '\u03A1': 'p', '\u03A4': 't', '\u03A5': 'y', '\u03A7': 'x',
};

/** Invisible / formatting code points (zero-width, bidi controls, soft hyphen, BOM). */
const INVISIBLE = /[\u00AD\u034F\u061C\u115F\u1160\u17B4\u17B5\u180E\u200B-\u200F\u202A-\u202E\u2060-\u206F\u3164\uFEFF\uFFA0]/g;

export function canonicalize(text: string): string {
  const nfkc = text.normalize('NFKC').replace(INVISIBLE, '');
  let out = '';
  for (const ch of nfkc) out += HOMOGLYPHS[ch] ?? ch;
  return out
    .toLowerCase()
    .normalize('NFD').replace(/[\u0300-\u036F]/g, '')
    .replace(/\s+/g, ' ');
}

/** Letters-only view: also removes punctuation used to split words
 * ("p.u.b.l.i.q.u.e", "pub-lique"). Used as a second pass for verbs. */
export function squash(text: string): string {
  return canonicalize(text).replace(/[^a-z0-9 ]+/g, '');
}
