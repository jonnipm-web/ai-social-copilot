/**
 * Verification Dossier strings (PT/EN) — IV-IMPACT-I4.
 *
 * Keyed by code; the dossier CONTENT never contains these strings (it is
 * language-neutral), only the human-readable rendering does. Every string is
 * checked against the verdict-language guard by the renderer and by tests.
 */
import type { Lang } from './i18n.ts';
import type { DossierStatus, LimitationCode, LocatorState, NonFindingCode, ReverificationReason } from './dossier.ts';
import type { GapCode } from './types.ts';
import type { SubjectIdentityStatus } from './verification.ts';

type L = Readonly<Record<Lang, string>>;

export const SECTION: Readonly<Record<string, L>> = {
  TITLE: { pt: 'Dossiê de verificação', en: 'Verification dossier' },
  SUMMARY: { pt: 'Resumo', en: 'Summary' },
  IDENTITY: { pt: 'Identidade da organização', en: 'Organization identity' },
  REGISTRY: { pt: 'Registros oficiais', en: 'Official registry records' },
  CLAIMS: { pt: 'Afirmações e verificação', en: 'Claims and verification' },
  LIMITATIONS: { pt: 'Limitações', en: 'Limitations' },
  NOT_ESTABLISHED: { pt: 'O que este dossiê NÃO estabelece', en: 'What this dossier does NOT establish' },
  SOURCES: { pt: 'Fontes', en: 'Sources' },
  DISPUTES: { pt: 'Contestações', en: 'Disputes' },
  INTEGRITY: { pt: 'Integridade e proveniência', en: 'Integrity and provenance' },
  AS_OF: { pt: 'Situação em', en: 'As of' },
  LIVE: { pt: 'Visão ao vivo do estado atual (muda quando a evidência muda).', en: 'Live view of the current state (changes when the evidence changes).' },
  SNAPSHOT: { pt: 'Retrato histórico: representa o estado nesta data e não se atualiza sozinho.', en: 'Historical snapshot: represents the state at this date and never updates itself.' },
  HASH_NOTE: { pt: 'O hash prova que este conteúdo não foi alterado; não prova que ele é verdadeiro.', en: 'The hash proves this content was not altered; it does not prove it is true.' },
  QUOTE_NOTE: { pt: 'Trechos entre « » são citações das fontes, não afirmações do InsightValues.', en: 'Excerpts in « » are quotes from the sources, not statements by InsightValues.' },
  EVIDENCE_FOR: { pt: 'Evidência a favor', en: 'Supporting evidence' },
  EVIDENCE_PARTIAL: { pt: 'Evidência parcial', en: 'Partial evidence' },
  EVIDENCE_AGAINST: { pt: 'Evidência divergente', en: 'Diverging evidence' },
  EVIDENCE_CONTEXT: { pt: 'Contexto (não conta como corroboração)', en: 'Context (not counted as corroboration)' },
  VOICES: { pt: 'Vozes independentes', en: 'Independent voices' },
  NOT_VERIFIED: { pt: 'Ainda não verificada pelo motor.', en: 'Not yet verified by the engine.' },
  REVERIFY: { pt: 'Reverificação pendente', en: 'Re-verification pending' },
  OPEN_DISPUTE: { pt: 'Contestação em aberto', en: 'Open dispute' },
  HOST: { pt: 'hospedado em', en: 'hosted on' },
  WITHHELD: { pt: 'trecho omitido por privacidade', en: 'excerpt withheld for privacy' },
  EXPERIMENTAL: { pt: 'EXPERIMENTAL — uso interno do Impact Lab.', en: 'EXPERIMENTAL — Impact Lab internal use.' },
};

export const DOSSIER_STATUS_LABEL: Readonly<Record<DossierStatus, L>> = {
  COMPLETE: { pt: 'Completo — todas as afirmações foram processadas', en: 'Complete — every claim was processed' },
  PARTIAL: { pt: 'Parcial — há limitações registradas abaixo', en: 'Partial — limitations are listed below' },
  REVIEW_REQUIRED: { pt: 'Revisão humana necessária', en: 'Human review required' },
  INCOMPLETE: { pt: 'Incompleto — há afirmações não verificadas ou com reverificação pendente', en: 'Incomplete — some claims are not verified or await re-verification' },
};

export const IDENTITY_LABEL: Readonly<Record<SubjectIdentityStatus, L>> = {
  CONFIRMED: { pt: 'Confirmada por registro oficial', en: 'Confirmed by an official registry' },
  PROBABLE: { pt: 'Provável, ainda não confirmada', en: 'Probable, not yet confirmed' },
  UNCERTAIN: { pt: 'Ambígua — mais de uma organização possível', en: 'Ambiguous — more than one organization possible' },
  UNRESOLVED: { pt: 'Não resolvida — sem registro que a confirme', en: 'Unresolved — no registry record confirms it' },
};

export const LIMITATION_LABEL: Readonly<Record<LimitationCode, L>> = {
  IDENTITY_NOT_CONFIRMED: { pt: 'A identidade da organização não foi confirmada por registro oficial.', en: 'The organization identity was not confirmed by an official registry.' },
  IDENTITY_AMBIGUOUS: { pt: 'A identidade é ambígua: os registros apontam para mais de uma possibilidade.', en: 'The identity is ambiguous: registry records point to more than one possibility.' },
  NO_REGISTRY_RECORD: { pt: 'Nenhum registro oficial foi consultado ou anexado. Isso não significa que a organização não seja registrada.', en: 'No official registry record was consulted or attached. This does not mean the organization is unregistered.' },
  REGISTRY_RECORD_NOT_FRESH: { pt: 'Um registro oficial pode estar desatualizado e precisar de nova consulta.', en: 'An official registry record may be out of date and need refreshing.' },
  REGISTRY_CONFLICT: { pt: 'Registros oficiais divergem entre si em algum dado.', en: 'Official registry records disagree on some data.' },
  SOURCE_NOT_ACTIVE: { pt: 'Uma fonte foi atualizada, retirada ou ficou indisponível.', en: 'A source was updated, retracted or became unavailable.' },
  EXTRACTION_OCR_REQUIRED: { pt: 'Um documento é só imagem e exigiria OCR; seu conteúdo não foi lido.', en: 'A document is image-only and would require OCR; its content was not read.' },
  EXTRACTION_PARTIAL: { pt: 'Um documento foi lido apenas em parte.', en: 'A document was read only in part.' },
  EXTRACTION_FAILED: { pt: 'Um documento não pôde ser lido.', en: 'A document could not be read.' },
  ARTIFACT_SUPERSEDED: { pt: 'Existe uma versão mais recente de um documento anexado.', en: 'A newer version of an attached document exists.' },
  EVIDENCE_REVIEW_PENDING: { pt: 'Há trechos de documentos aguardando revisão humana.', en: 'Document excerpts await human review.' },
  CLAIM_NOT_VERIFIED: { pt: 'Uma afirmação ainda não foi verificada.', en: 'A claim has not been verified yet.' },
  REVERIFICATION_PENDING: { pt: 'A evidência ou uma contestação mudou depois da última verificação.', en: 'Evidence or a dispute changed after the last verification.' },
  INSUFFICIENT_EVIDENCE: { pt: 'Não encontramos evidência suficiente nas fontes analisadas para confirmar uma afirmação. Isso não indica que ela seja falsa.', en: 'We did not find enough evidence in the sources analyzed to confirm a claim. This does not indicate it is false.' },
  CONFLICTING_EVIDENCE: { pt: 'Há evidências divergentes; todas são mostradas lado a lado, sem escolher uma.', en: 'Evidence diverges; all positions are shown side by side, none is chosen.' },
  DISPUTE_OPEN: { pt: 'Uma afirmação está em contestação e aguarda revisão.', en: 'A claim is under dispute and awaits review.' },
  EVIDENCE_OUTDATED: { pt: 'Parte da evidência é antiga e pode não refletir a situação atual.', en: 'Some evidence is old and may not reflect the current situation.' },
  LINEAGE_UNCERTAIN: { pt: 'Não foi possível confirmar se algumas fontes são independentes entre si.', en: 'It could not be confirmed whether some sources are independent of each other.' },
  HUMAN_REVIEW_REQUIRED: { pt: 'Uma verificação exige revisão humana antes de qualquer uso.', en: 'A verification requires human review before any use.' },
  LOCATOR_UNVERIFIABLE: { pt: 'A localização de um trecho não pode ser confirmada na versão atual do documento.', en: 'The location of an excerpt cannot be confirmed in the current document version.' },
  EXCERPT_WITHHELD: { pt: 'Um trecho foi omitido por conter dados pessoais.', en: 'An excerpt was withheld because it contains personal data.' },
};

export const NON_FINDING_LABEL: Readonly<Record<NonFindingCode, L>> = {
  NOT_A_FINDING_OF_WRONGDOING: { pt: 'Não é uma conclusão de irregularidade sobre a organização.', en: 'It is not a finding of wrongdoing about the organization.' },
  NO_INTENT_OR_INNOCENCE: { pt: 'Não estabelece intenção, culpa ou inocência de ninguém.', en: 'It does not establish anyone’s intent, guilt or innocence.' },
  NO_DONATION_ADVICE: { pt: 'Não recomenda doar nem deixar de doar.', en: 'It does not recommend donating or not donating.' },
  NOT_PROFESSIONAL_DUE_DILIGENCE: { pt: 'Não substitui uma diligência profissional.', en: 'It does not replace professional due diligence.' },
  ABSENCE_IS_NOT_EVIDENCE: { pt: 'Ausência de evidência não é evidência de irregularidade.', en: 'Absence of evidence is not evidence of wrongdoing.' },
  UNVERIFIED_IS_NOT_FALSE: { pt: 'Uma afirmação não verificada ou com evidência insuficiente não é uma afirmação falsa.', en: 'An unverified claim, or one with insufficient evidence, is not a false claim.' },
  CONFLICT_IS_NOT_WRONGDOING: { pt: 'Evidências divergentes não indicam culpa; indicam onde olhar com mais atenção.', en: 'Diverging evidence does not indicate guilt; it shows where to look more closely.' },
  REGISTRY_STATUS_IS_NOT_WRONGDOING: { pt: 'Um status cadastral (inativo, encerrado, removido) não é, por si, sinal de irregularidade.', en: 'A registry status (inactive, dissolved, removed) is not, by itself, a sign of wrongdoing.' },
  DOCUMENTS_ARE_NOT_INDEPENDENT_SOURCES: { pt: 'Vários documentos não significam várias fontes independentes.', en: 'Several documents do not mean several independent sources.' },
  USER_UPLOADS_ARE_NOT_AUTHORITY: { pt: 'Documentos enviados por usuários são contexto, nunca autoridade.', en: 'User-uploaded documents are context, never authority.' },
  QUOTED_TEXT_IS_NOT_A_PLATFORM_STATEMENT: { pt: 'Trechos citados das fontes não são afirmações do InsightValues.', en: 'Excerpts quoted from sources are not statements by InsightValues.' },
};

export const LOCATOR_STATE_LABEL: Readonly<Record<LocatorState, L>> = {
  VALID: { pt: 'localização confirmada', en: 'location confirmed' },
  NOT_ARTIFACT_BOUND: { pt: 'sem documento anexado', en: 'no attached document' },
  ARTIFACT_SUPERSEDED: { pt: 'documento substituído por versão mais nova', en: 'document superseded by a newer version' },
  ARTIFACT_MISSING: { pt: 'documento não disponível', en: 'document unavailable' },
  HASH_MISMATCH: { pt: 'versão do documento não confere', en: 'document version does not match' },
  OUT_OF_RANGE: { pt: 'localização fora do documento', en: 'location outside the document' },
};

export const REVERIFY_REASON_LABEL: Readonly<Record<ReverificationReason, L>> = {
  EVIDENCE_CHANGED: { pt: 'a evidência mudou', en: 'the evidence changed' },
  DISPUTE_OPENED: { pt: 'uma contestação foi aberta', en: 'a dispute was opened' },
  DISPUTE_RESOLVED: { pt: 'uma contestação foi resolvida', en: 'a dispute was resolved' },
};

export const GAP_LABEL: Readonly<Record<GapCode, L>> = {
  NO_EVIDENCE: { pt: 'nenhuma evidência utilizável', en: 'no usable evidence' },
  NO_INDEPENDENT_SOURCE: { pt: 'nenhuma fonte independente', en: 'no independent source' },
  ONLY_SELF_REPORTED: { pt: 'apenas autodeclaração', en: 'self-reported only' },
  EVIDENCE_OUTDATED: { pt: 'evidência antiga', en: 'evidence outdated' },
  PERIOD_NOT_COVERED: { pt: 'período não coberto', en: 'period not covered' },
  IDENTITY_UNCONFIRMED: { pt: 'identidade não confirmada', en: 'identity unconfirmed' },
  OUT_OF_AUTHORITY_SCOPE: { pt: 'fora do escopo da fonte', en: 'outside the source’s scope' },
  UNCONFIRMED_LLM_LINKS: { pt: 'ligações automáticas não confirmadas', en: 'unconfirmed automatic links' },
  LEVEL_MISMATCH: { pt: 'nível de impacto diferente', en: 'different impact level' },
  UNITS_NOT_COMPARABLE: { pt: 'unidades não comparáveis', en: 'units not comparable' },
  SOURCE_RETRACTED: { pt: 'fonte retirada', en: 'source retracted' },
  SOURCE_CHANGED: { pt: 'fonte alterada', en: 'source changed' },
  SOURCE_UNAVAILABLE: { pt: 'fonte indisponível', en: 'source unavailable' },
  ALLEGATION_UNRESOLVED: { pt: 'alegação sem desfecho', en: 'allegation unresolved' },
  UNTRUSTED_INSTRUCTIONS_DETECTED: { pt: 'instruções não confiáveis no material (tratadas como dados)', en: 'untrusted instructions in the material (treated as data)' },
  INDEPENDENCE_NOT_ESTABLISHED: { pt: 'independência não estabelecida', en: 'independence not established' },
  POSSIBLE_LINEAGE: { pt: 'possível origem comum entre fontes', en: 'possible common origin between sources' },
};
