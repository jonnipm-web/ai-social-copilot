/**
 * Linear XML tag tokenizer for OOXML parts — IV-IMPACT-I3 (Codex I3G1-01).
 *
 * Replaces regex scanning over attacker-controlled XML: every character is
 * visited a bounded number of times (indexOf only moves forward), so a part
 * full of unterminated `<`, `<si>` or `<c>` costs O(n), never O(n²).
 * Not a validating parser: no DTD, no entity expansion (only the predefined
 * entities and numeric references, decoded by the caller), no namespaces
 * beyond the literal prefix. An unterminated tag stops the scan and is
 * reported as `malformed`, never guessed.
 */

export type XmlToken =
  | { readonly kind: 'open' | 'close' | 'self'; readonly name: string; readonly attrs: string }
  | { readonly kind: 'text'; readonly text: string };

export interface XmlScan {
  readonly tokens: Generator<XmlToken>;
  /** True once the scan stopped at an unterminated tag / comment / CDATA. */
  malformed(): boolean;
}

const WS = new Set([' ', '\t', '\n', '\r']);

export function scanXml(xml: string): XmlScan {
  let bad = false;
  function* gen(): Generator<XmlToken> {
    const n = xml.length;
    let i = 0;
    while (i < n) {
      const lt = xml.indexOf('<', i);
      if (lt < 0) {
        yield { kind: 'text', text: xml.slice(i) };
        return;
      }
      if (lt > i) yield { kind: 'text', text: xml.slice(i, lt) };
      if (xml.startsWith('<!--', lt)) {
        const end = xml.indexOf('-->', lt + 4);
        if (end < 0) { bad = true; return; }
        i = end + 3;
        continue;
      }
      if (xml.startsWith('<![CDATA[', lt)) {
        const end = xml.indexOf(']]>', lt + 9);
        if (end < 0) { bad = true; return; }
        yield { kind: 'text', text: xml.slice(lt + 9, end).replaceAll('&', '&amp;').replaceAll('<', '&lt;') };
        i = end + 3;
        continue;
      }
      const gt = xml.indexOf('>', lt + 1);
      if (gt < 0) { bad = true; return; }
      i = gt + 1;
      const c = xml[lt + 1];
      if (c === '?' || c === '!') continue; // declaration / processing instruction / doctype: ignored
      const close = c === '/';
      const self = !close && xml[gt - 1] === '/';
      const from = close ? lt + 2 : lt + 1;
      const to = self ? gt - 1 : gt;
      let k = from;
      while (k < to && !WS.has(xml[k]) && xml[k] !== '/') k++;
      const name = xml.slice(from, k);
      if (!name) continue;
      yield { kind: close ? 'close' : self ? 'self' : 'open', name, attrs: close ? '' : xml.slice(k, to) };
    }
  }
  return { tokens: gen(), malformed: () => bad };
}

/** Value of attribute `key` (first occurrence preceded by whitespace), linear. */
export function xmlAttr(attrs: string, key: string): string | undefined {
  const needle = `${key}="`;
  let at = attrs.indexOf(needle);
  while (at >= 0) {
    if (at === 0 || WS.has(attrs[at - 1])) {
      const start = at + needle.length;
      const end = attrs.indexOf('"', start);
      return end < 0 ? undefined : attrs.slice(start, end);
    }
    at = attrs.indexOf(needle, at + 1);
  }
  return undefined;
}
