import 'dossier_models.dart';

/// IV-IMPACT-MACRO-08 Phase 13 — formal boundary between IVE (the AI
/// copilot) and Impact evidence.
///
/// INVARIANTS:
///   1. IVE NEVER invents evidence. It can only summarise what the server
///      has already verified and stored in the DossierView.
///   2. Every item passed to IVE is labelled with its [EvidenceKind]:
///      [serverFact] for server-verified data, [iveInference] for
///      intermediate derivations, [userHypothesis] for user-supplied context.
///   3. Billing/plan fields MUST NOT appear in IVE context (mirrors the
///      server-side TRUST_NEUTRALITY_POLICY — a user's plan tier must never
///      bias the AI's reasoning about evidence quality or credibility).
///   4. The assembled context is TEXT ONLY — no binary, no file URL that
///      IVE might fetch independently (egress boundary preserved).

/// The epistemic kind of a fact passed to IVE.
enum EvidenceKind {
  /// Verified and stored by the server. Source of truth.
  serverFact,

  /// Derived from server facts by IVE reasoning — not independently verified.
  iveInference,

  /// Supplied by the user without server verification.
  userHypothesis,
}

/// A single labelled item for IVE's context window.
class LabelledFact {
  const LabelledFact(this.kind, this.label, this.value);

  final EvidenceKind kind;
  final String label;
  final String value;

  // Values are wrapped in XML-style delimiters so downstream IVE runners
  // cannot treat the value content as control instructions.
  String toContextLine() => '[${kind.name.toUpperCase()}] $label: <value>${_sanitize(value)}</value>';
}

// ── IVE boundary rules (printed verbatim in every context) ─────────────────

const _kIveRules = '''
CONTEXTO DO DOSSIÊ INSIGHTVALUES IMPACT
— IVE PODE: resumir evidências server-verificadas, apontar lacunas declaradas, parafrasear afirmações.
— IVE NÃO PODE: inventar evidências, pressupor verificação, criar alegações novas, inferir culpa.
— STATUS DE VERIFICAÇÃO: sempre citar o campo status do servidor; nunca derivar um status próprio.
— ASSINATURA/FATURAMENTO: NUNCA influencia qualidade de evidência ou credibilidade — excluído do contexto.
— AUSÊNCIA DE EVIDÊNCIA: nunca implica negação de irregularidade.''';

/// Assembles a safe, labelled context string from a [DossierView] for use
/// as IVE's dossier context. Returns a multiline string with every item
/// prefixed by its [EvidenceKind].
String assembleDossierContext(DossierView dossier) {
  final facts = <LabelledFact>[];
  final subject = dossier.subject;

  // Subject identity
  facts.add(LabelledFact(EvidenceKind.serverFact, 'Referência', subject.ref));
  if (subject.legalName != null) {
    facts.add(LabelledFact(EvidenceKind.serverFact, 'Nome legal', subject.legalName!));
  }
  if (subject.identityStatus != null) {
    facts.add(LabelledFact(EvidenceKind.serverFact, 'Status de identidade', subject.identityStatus!));
  }
  if (subject.registrations.isNotEmpty) {
    facts.add(LabelledFact(EvidenceKind.serverFact, 'Registros', subject.registrations.join('; ')));
  }

  // Claims summary
  if (dossier.claims.isEmpty) {
    facts.add(LabelledFact(EvidenceKind.serverFact, 'Afirmações verificadas', 'nenhuma'));
  } else {
    for (final c in dossier.claims.take(10)) {
      final status = c.verification?.status ?? 'NOT_VERIFIED';
      facts.add(LabelledFact(
        EvidenceKind.serverFact,
        'Afirmação ${c.ref}',
        '$status — ${_trunc(c.text, 120)}',
      ));
    }
    if (dossier.claims.length > 10) {
      facts.add(LabelledFact(
        EvidenceKind.serverFact,
        'Afirmações restantes',
        '${dossier.claims.length - 10} não exibidas (limite de contexto)',
      ));
    }
  }

  // Does NOT establish
  if (dossier.doesNotEstablish.isNotEmpty) {
    facts.add(LabelledFact(
      EvidenceKind.serverFact,
      'NÃO estabelece',
      dossier.doesNotEstablish.join('; '),
    ));
  }

  // Limitations count
  if (dossier.limitationCount > 0) {
    facts.add(LabelledFact(
      EvidenceKind.serverFact, 'Limitações', '${dossier.limitationCount} registrada(s)',
    ));
  }

  return '$_kIveRules\n\n${facts.map((f) => f.toContextLine()).join('\n')}';
}

String _trunc(String? s, int max) {
  if (s == null || s.isEmpty) return '—';
  return s.length <= max ? s : '${s.substring(0, max)}…';
}

// Removes </value> sequences from user-controlled text so the XML delimiter
// cannot be escaped by injected content. This is defense-in-depth: the IVE
// runner's own system prompt is the primary injection boundary.
String _sanitize(String s) => s.replaceAll('</value>', '<\\/value>');
