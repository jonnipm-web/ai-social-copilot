/**
 * Human-readable Verification Dossier (PT/EN) — IV-IMPACT-I4.
 *
 * Plain text in sections, summary first (progressive disclosure: a mobile
 * client can collapse every section after the summary). Every GENERATED line
 * comes from fixed templates (dossier_i18n.ts / i18n.ts) and is checked
 * against the verdict-language guard; quoted source excerpts are marked with
 * « » and attributed — they are the sources' words, never the platform's.
 * The rendering carries the integrity hash of the content it was made from.
 */
import type { DossierDocument } from './dossier.ts';
import {
  DOSSIER_STATUS_LABEL,
  GAP_LABEL,
  IDENTITY_LABEL,
  LIMITATION_LABEL,
  LOCATOR_STATE_LABEL,
  NON_FINDING_LABEL,
  REVERIFY_REASON_LABEL,
  SECTION,
} from './dossier_i18n.ts';
import { CLASS_LABEL, type Lang, STATUS_LABEL, SUFFICIENCY_LABEL } from './i18n.ts';
import { findVerdictLanguage } from './safety.ts';

export function renderDossierText(doc: DossierDocument, lang: Lang): string {
  const c = doc.content;
  const generated: string[] = [];
  const quoted: string[] = [];
  const lines: string[] = [];
  const g = (s: string) => { generated.push(s); return s; };
  const out = (s = '') => lines.push(s);
  const t = (k: keyof typeof SECTION) => g(SECTION[k][lang]);

  out(`# ${t('TITLE')} — ${c.subject.ref}`);
  out(t('EXPERIMENTAL'));
  out(`${t('AS_OF')}: ${c.asOf ?? '—'} · ${doc.envelope.kind === 'SNAPSHOT' ? t('SNAPSHOT') : t('LIVE')}`);
  out(g(DOSSIER_STATUS_LABEL[c.dossierStatus][lang]));
  out();

  out(`## ${t('SUMMARY')}`);
  for (const [status, n] of Object.entries(c.summary.byStatus)) {
    if (n > 0) out(`- ${g(STATUS_LABEL[status as keyof typeof STATUS_LABEL][lang])}: ${n}`);
  }
  if (c.summary.notVerified) out(`- ${t('NOT_VERIFIED')} ${c.summary.notVerified}`);
  if (c.summary.reverificationPending) out(`- ${t('REVERIFY')}: ${c.summary.reverificationPending}`);
  if (c.summary.openDisputes) out(`- ${t('OPEN_DISPUTE')}: ${c.summary.openDisputes}`);
  out();

  out(`## ${t('IDENTITY')}`);
  out(`- ${c.subject.declaredIdentity.legalName ?? c.subject.ref} (${c.subject.type})`);
  out(`- ${g(IDENTITY_LABEL[c.subject.identityStatus][lang])}`);
  out();

  if (c.registryFacts.length) {
    out(`## ${t('REGISTRY')}`);
    for (const r of c.registryFacts) {
      out(`- ${r.legalName} · ${r.canonicalOrgId} · ${r.registryStatus}${r.statusAsOf ? ` (${r.statusAsOf})` : ''} · ${r.providerId}${r.authority?.official ? " (official)" : ""} · ${r.retrievedAt}${r.synthetic ? ' · synthetic' : ''}`);
    }
    out();
  }

  out(`## ${t('CLAIMS')}`);
  for (const cl of c.claims) {
    if (cl.text !== null) quoted.push(cl.text);
    out(`### ${cl.ref} — «${cl.text ?? g(SECTION.WITHHELD[lang])}»`);
    const v = cl.verification;
    if (!v) {
      out(`- ${t('NOT_VERIFIED')}`);
    } else {
      out(`- ${g(STATUS_LABEL[v.status][lang])} · ${g(CLASS_LABEL[v.displayClass][lang])} · ${g(SUFFICIENCY_LABEL[v.sufficiency][lang])}`);
      out(`- ${t('VOICES')}: ${v.independence.independentVoices}`);
      const group = (label: keyof typeof SECTION, xs: readonly { evidenceRef: string; sourceRef: string; authority: string }[]) => {
        if (xs.length) out(`- ${t(label)}: ${xs.map((x) => `${x.evidenceRef} (${x.sourceRef}, ${x.authority})`).join('; ')}`);
      };
      group('EVIDENCE_FOR', v.supporting);
      group('EVIDENCE_PARTIAL', v.partiallySupporting);
      group('EVIDENCE_AGAINST', v.contradicting);
      group('EVIDENCE_CONTEXT', v.contextual);
      if (v.gaps.length) out(`- ${v.gaps.map((x) => g(GAP_LABEL[x as keyof typeof GAP_LABEL]?.[lang] ?? x)).join(' · ')}`);
      out(`- rules: ${v.rulesApplied.join(', ')} · ${v.policyVersion} · ${v.evaluatedAt}`);
    }
    if (cl.reverificationPending) out(`- ${t('REVERIFY')}: ${cl.reverificationReasons.map((r) => g(REVERIFY_REASON_LABEL[r][lang])).join(', ')}`);
    if (cl.disputeRefs.length) out(`- ${t('DISPUTES')}: ${cl.disputeRefs.join(', ')}`);
    for (const e of c.evidence.filter((x) => x.claimRef === cl.ref)) {
      const where = e.locator?.artifact ? `${e.locator.artifact.ref}@${e.locator.artifact.hash.slice(0, 12)} ${JSON.stringify(e.locator.artifact.locator)}` : '';
      const text = e.excerpt !== null ? `«${e.excerpt}»` : e.excerptWithheld ? `[${g(SECTION.WITHHELD[lang])}]` : '';
      if (e.excerpt !== null) quoted.push(e.excerpt);
      out(`  - ${e.ref} · ${e.sourceRef} · ${e.relationship} ${text} ${where} · ${g(LOCATOR_STATE_LABEL[e.locatorState][lang])}`.trimEnd());
    }
  }
  out(t('QUOTE_NOTE'));
  out();

  out(`## ${t('LIMITATIONS')}`);
  const seen = new Set<string>();
  for (const l of c.limitations) {
    const line = g(LIMITATION_LABEL[l.code][lang]);
    const refs = c.limitations.filter((x) => x.code === l.code && x.ref).map((x) => x.ref).join(', ');
    if (seen.has(l.code)) continue;
    seen.add(l.code);
    out(`- ${line}${refs ? ` (${refs})` : ''}`);
  }
  out();

  out(`## ${t('NOT_ESTABLISHED')}`);
  for (const n of c.doesNotEstablish) out(`- ${g(NON_FINDING_LABEL[n][lang])}`);
  out();

  out(`## ${t('SOURCES')}`);
  for (const s of c.sources) {
    out(`- ${s.ref} · ${s.type} · ${s.publisher}${s.host ? ` · ${t('HOST')} ${s.host.provider}` : ''} · ${s.acquisition} · ${s.status} · ${s.retrievedAt}`);
  }
  out();

  if (c.disputes.length) {
    out(`## ${t('DISPUTES')}`);
    for (const d of c.disputes) out(`- ${d.ref} · ${d.claimRef} · ${d.kind} · ${d.openedAt} · ${d.open ? t('OPEN_DISPUTE') : `${d.resolution} ${d.resolvedAt}`}`);
    out();
  }

  out(`## ${t('INTEGRITY')}`);
  out(`- ${doc.schemaVersion} · ${doc.integrity.algorithm} ${doc.integrity.contentHash}`);
  if (doc.envelope.snapshotRef) out(`- ${doc.envelope.snapshotRef} · ${doc.envelope.generatedAt}`);
  out(`- ${t('HASH_NOTE')}`);

  // Every generated line must be free of verdict language (quotes are exempt: attributed source words).
  for (const s of generated) {
    if (findVerdictLanguage(s).length > 0) throw new Error('INTERNAL_ERROR: dossier template produced verdict language');
  }
  void quoted;
  return lines.join('\n');
}
