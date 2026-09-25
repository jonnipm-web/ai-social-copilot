/**
 * Human-readable Verification Dossier (PT/EN) — IV-IMPACT-I4.
 *
 * Plain text in sections, summary first (progressive disclosure: a mobile
 * client can collapse every section after the summary). Two kinds of text
 * only:
 *   - PLATFORM text: fixed templates (dossier_i18n.ts / i18n.ts);
 *   - DATA: every value that comes from persisted rows (names, publishers,
 *     refs, claim texts, excerpts, ids) is rendered inside « » and
 *     neutralized so it cannot leave its quote marks (Codex I4G1-N03).
 * The WHOLE rendered text, with the « » spans removed, must be free of
 * verdict language — the renderer throws otherwise. Conflicts are rendered
 * with every position and no winner (Codex I4G1-N04).
 */
import type { DossierDocument } from './dossier.ts';
import {
  CONFLICT_BASIS_LABEL,
  CONFLICT_KIND_LABEL,
  DOSSIER_STATUS_LABEL,
  GAP_LABEL,
  IDENTITY_LABEL,
  LIMITATION_LABEL,
  LOCATOR_STATE_LABEL,
  MISC_LABEL,
  NON_FINDING_LABEL,
  REVERIFY_REASON_LABEL,
  SECTION,
} from './dossier_i18n.ts';
import { CLASS_LABEL, type Lang, STATUS_LABEL, SUFFICIENCY_LABEL } from './i18n.ts';
import { findVerdictLanguage } from './safety.ts';

/** DATA stays inside its quote marks: « » in it are neutralized, newlines flattened. */
function q(s: string | number | null | undefined): string {
  if (s === null || s === undefined || s === '') return '—';
  return `«${String(s).replace(/[«»]/g, '"').replace(/[\r\n]+/g, ' ')}»`;
}

/** Text outside every « » span (what the platform itself says). */
export function platformText(text: string): string {
  return text.replace(/«[^«»]*»/g, '«»');
}

export function renderDossierText(doc: DossierDocument, lang: Lang): string {
  const c = doc.content;
  const lines: string[] = [];
  const out = (s = '') => lines.push(s);
  const t = (k: keyof typeof SECTION) => SECTION[k][lang];
  const m = (k: string) => MISC_LABEL[k][lang];

  out(`# ${t('TITLE')} — ${q(c.subject.declaredIdentity.legalName ?? c.subject.ref)}`);
  out(t('EXPERIMENTAL'));
  out(`${t('AS_OF')}: ${q(c.asOf)} · ${doc.envelope.kind === 'SNAPSHOT' ? t('SNAPSHOT') : t('LIVE')}`);
  out(DOSSIER_STATUS_LABEL[c.dossierStatus][lang]);
  out();

  // IV-IMPACT-I5 (Codex I5G3-03): the caveats come FIRST — before the summary
  // and before any claim or status — so a copied or cropped excerpt from the
  // top of the text always carries what the dossier does NOT establish.
  out(`## ${t('NOT_ESTABLISHED')}`);
  for (const n of c.doesNotEstablish) out(`- ${NON_FINDING_LABEL[n][lang]}`);
  out();

  out(`## ${t('LIMITATIONS')}`);
  const seen = new Set<string>();
  for (const l of c.limitations) {
    if (seen.has(l.code)) continue;
    seen.add(l.code);
    const refs = c.limitations.filter((x) => x.code === l.code && x.ref).map((x) => q(x.ref)).join(', ');
    out(`- ${LIMITATION_LABEL[l.code][lang]}${refs ? ` (${refs})` : ''}`);
  }
  out();

  out(`## ${t('SUMMARY')}`);
  for (const [status, n] of Object.entries(c.summary.byStatus)) {
    if (n > 0) out(`- ${STATUS_LABEL[status as keyof typeof STATUS_LABEL][lang]}: ${n}`);
  }
  if (c.summary.notVerified) out(`- ${t('NOT_VERIFIED')} ${c.summary.notVerified}`);
  if (c.summary.reverificationPending) out(`- ${t('REVERIFY')}: ${c.summary.reverificationPending}`);
  if (c.summary.openDisputes) out(`- ${t('OPEN_DISPUTE')}: ${c.summary.openDisputes}`);
  if (c.summary.conflicts || c.summary.registryConflicts) out(`- ${m('CONFLICTS')}: ${c.summary.conflicts + c.summary.registryConflicts}`);
  out();

  out(`## ${t('IDENTITY')}`);
  out(`- ${q(c.subject.declaredIdentity.legalName ?? c.subject.ref)} (${q(c.subject.type)})`);
  out(`- ${IDENTITY_LABEL[c.subject.identityStatus][lang]}`);
  out();

  if (c.registryFacts.length) {
    out(`## ${t('REGISTRY')}`);
    const now = new Map(doc.envelope.registryFreshAtGeneration.map((f) => [f.sourceRef, f.fresh]));
    for (const r of c.registryFacts) {
      const freshNow = now.get(r.sourceRef);
      out(`- ${q(r.legalName)} · ${q(r.canonicalOrgId)} · ${q(r.registryStatus)}${r.statusAsOf ? ` ${q(r.statusAsOf)}` : ''} · ${q(r.providerId)}${r.authority?.official ? ` (${m('OFFICIAL')})` : ''} · ${q(r.retrievedAt)}${r.synthetic ? ` · ${m('SYNTHETIC')}` : ''}`);
      out(`  - ${m(r.freshAtAsOf ? 'FRESH_AT_AS_OF' : 'NOT_FRESH_AT_AS_OF')}${freshNow === undefined ? '' : ` · ${m(freshNow ? 'FRESH_NOW' : 'NOT_FRESH_NOW')}`}`);
    }
    for (const x of c.registryConflicts) out(`- ${LIMITATION_LABEL.REGISTRY_CONFLICT[lang]} ${q(x.kind)} · ${q(x.sourceRef)} / ${q(x.otherSourceRef)}`);
    out();
  }

  out(`## ${t('CLAIMS')}`);
  for (const cl of c.claims) {
    out(`### ${q(cl.ref)} — ${cl.text !== null ? q(cl.text) : `[${SECTION.WITHHELD[lang]}]`}`);
    const v = cl.verification;
    if (!v) {
      out(`- ${t('NOT_VERIFIED')}`);
    } else {
      out(`- ${STATUS_LABEL[v.status][lang]} · ${CLASS_LABEL[v.displayClass][lang]} · ${SUFFICIENCY_LABEL[v.sufficiency][lang]}`);
      out(`- ${t('VOICES')}: ${v.independence.independentVoices}`);
      const group = (label: keyof typeof SECTION, xs: readonly { evidenceRef: string; sourceRef: string; authority: string }[]) => {
        if (xs.length) out(`- ${t(label)}: ${xs.map((x) => `${q(x.evidenceRef)} (${q(x.sourceRef)}, ${q(x.authority)})`).join('; ')}`);
      };
      group('EVIDENCE_FOR', v.supporting);
      group('EVIDENCE_PARTIAL', v.partiallySupporting);
      group('EVIDENCE_AGAINST', v.contradicting);
      group('EVIDENCE_CONTEXT', v.contextual);
      for (const k of v.conflicts) {
        out(`- ${m('CONFLICTS')}: ${CONFLICT_KIND_LABEL[k.kind][lang]}, ${CONFLICT_BASIS_LABEL[k.basis][lang]} · ${m('UNRESOLVED')}`);
        for (const p of k.positions) {
          out(`  - ${q(p.evidenceId)} · ${q(p.sourceId)} · ${q(p.publisher)} · ${q(p.relationship)}${p.reportedValue !== undefined ? ` · ${q(p.reportedValue)}` : ''}`);
        }
      }
      if (v.gaps.length) out(`- ${v.gaps.map((x) => GAP_LABEL[x as keyof typeof GAP_LABEL]?.[lang] ?? q(x)).join(' · ')}`);
      out(`- ${m('RULES')}: ${v.rulesApplied.map((r) => q(r)).join(', ')} · ${q(v.policyVersion)} · ${q(v.evaluatedAt)}`);
    }
    if (cl.reverificationPending) out(`- ${t('REVERIFY')}: ${cl.reverificationReasons.map((r) => REVERIFY_REASON_LABEL[r][lang]).join(', ')}`);
    if (cl.disputeRefs.length) out(`- ${t('DISPUTES')}: ${cl.disputeRefs.map((r) => q(r)).join(', ')}`);
    for (const e of c.evidence.filter((x) => x.claimRef === cl.ref)) {
      const where = e.locator?.artifact ? ` ${q(e.locator.artifact.ref)} ${q(e.locator.artifact.hash.slice(0, 12))} ${q(JSON.stringify(e.locator.artifact.locator))}` : '';
      const text = e.excerpt !== null ? ` ${q(e.excerpt)}` : e.excerptWithheld ? ` [${SECTION.WITHHELD[lang]}]` : '';
      out(`  - ${q(e.ref)} · ${q(e.sourceRef)} · ${q(e.relationship)}${text}${where} · ${LOCATOR_STATE_LABEL[e.locatorState][lang]}`);
    }
  }
  out(t('QUOTE_NOTE'));
  out();

  out(`## ${t('SOURCES')}`);
  for (const s of c.sources) {
    out(`- ${q(s.ref)} · ${q(s.type)} · ${q(s.publisher)}${s.host ? ` · ${t('HOST')} ${q(s.host.provider)}` : ''} · ${q(s.acquisition)} · ${q(s.status)} · ${q(s.retrievedAt)}`);
  }
  out();

  if (c.disputes.length) {
    out(`## ${t('DISPUTES')}`);
    for (const d of c.disputes) {
      out(`- ${q(d.ref)} · ${q(d.claimRef)} · ${q(d.kind)} · ${q(d.openedAt)} · ${d.open ? t('OPEN_DISPUTE') : `${q(d.resolution)} ${q(d.resolvedAt)}`}`);
    }
    out();
  }

  out(`## ${t('INTEGRITY')}`);
  out(`- ${q(doc.schemaVersion)} · SHA-256 ${q(doc.integrity.contentHash)}`);
  if (doc.envelope.snapshotRef) out(`- ${q(doc.envelope.snapshotRef)} · ${q(doc.envelope.generatedAt)}`);
  out(`- ${t('HASH_NOTE')}`);

  const text = lines.join('\n');
  // Everything the PLATFORM says (outside « ») must be free of verdict language.
  if (findVerdictLanguage(platformText(text)).length > 0) throw new Error('INTERNAL_ERROR: dossier text produced verdict language');
  return text;
}
