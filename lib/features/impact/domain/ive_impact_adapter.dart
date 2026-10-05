import 'dossier_models.dart';

/// IV-IMPACT-MACRO-08 Phase 13 (revised) — IVE-Impact boundary.
///
/// CORE INVARIANTS:
///   1. IVE NEVER invents evidence. Only server-stored facts are passed.
///   2. Every item has an explicit [EvidenceKind] that describes PROVENANCE,
///      not factual truth. "stored-by-server" ≠ "independently verified".
///   3. Billing/plan fields MUST NOT appear (TRUST_NEUTRALITY_POLICY).
///   4. Context is TEXT ONLY — no binary, no URLs IVE might fetch.
///   5. User-submitted text (claim text, subject names from user input) is
///      labelled [USER_CLAIM] even when the server stored it. The server is
///      a storage layer, not an independent verifier of claim content.
///   6. Values are wrapped in <value>...</value> delimiters. Injected
///      </value> sequences are escaped so the delimiter cannot be broken.
///      This is defense-in-depth; the IVE runner's system prompt is primary.
///
/// PROVENANCE HIERARCHY passed to IVE:
///   SOURCE   → a document the server has on record (URI, publisher, date)
///   EVIDENCE → a verifier's assessment of source material
///   CLAIM    → a statement about the subject (user-submitted text)
///   IDENTITY → subject identity fields (stored, not independently verified)
///   DOSSIER  → dossier-level metadata (does-not-establish, limitations)

// ── EvidenceKind ──────────────────────────────────────────────────────────────

/// The epistemic provenance of a fact in IVE's context.
///
/// IMPORTANT: these labels describe WHERE data came from, not WHETHER it is
/// factually true. The server stores data; it does not certify its truth.
enum EvidenceKind {
  /// Stored by server and produced by a server-run verification engine
  /// against an external registry. The strongest provenance available.
  serverVerified,

  /// Stored by server from a declared source document. The server has a
  /// record of the source, but has not independently confirmed the content.
  serverStored,

  /// Text submitted by a user and stored by the server unchanged.
  /// NOT independently verified. Must NEVER be treated as authoritative.
  userClaim,

  /// Derived by IVE from the above. No independent verification.
  inferred,
}

/// A single labelled item for IVE's context window.
class LabelledFact {
  const LabelledFact(this.kind, this.label, this.value);

  final EvidenceKind kind;
  final String label;
  final String value;

  String toContextLine() {
    final tag = switch (kind) {
      EvidenceKind.serverVerified => 'VERIFIED',
      EvidenceKind.serverStored   => 'STORED',
      EvidenceKind.userClaim      => 'USER_CLAIM',
      EvidenceKind.inferred       => 'INFERRED',
    };
    // Values wrapped in <value> delimiters; </value> in the value is escaped
    // so injected text cannot close the delimiter prematurely.
    return '[$tag] $label: <value>${_sanitize(value)}</value>';
  }
}

// ── IVE boundary rules ────────────────────────────────────────────────────────

const _kIveRules = '''
CONTEXTO DO DOSSIÊ INSIGHTVALUES IMPACT
─────────────────────────────────────────
RÓTULOS DE PROVENIÊNCIA (não indicam verdade factual):
  [VERIFIED]   = verificado pelo servidor contra registro externo
  [STORED]     = armazenado pelo servidor, fonte declarada, SEM confirmação independente
  [USER_CLAIM] = submetido por usuário e armazenado; NÃO verificado; NÃO autoridade
  [INFERRED]   = derivado pela IVE; sem verificação externa

IVE PODE: resumir evidências, apontar lacunas declaradas, parafrasear afirmações.
IVE NÃO PODE: inventar evidências, pressupor verificação, criar alegações novas,
              inferir culpa, tratar [USER_CLAIM] como fato estabelecido.

STATUS: sempre citar o campo "status" do servidor; nunca derivar status próprio.
ASSINATURA/FATURAMENTO: nunca influencia qualidade de evidência ou credibilidade.
AUSÊNCIA DE EVIDÊNCIA: nunca implica negação de irregularidade.
─────────────────────────────────────────''';

// ── assembleDossierContext ────────────────────────────────────────────────────

/// Assembles a safe, labelled context string from a [DossierView] for use
/// as IVE's dossier context. Every item is prefixed by its [EvidenceKind].
///
/// Billing/plan fields are structurally absent — [DossierView] does not
/// carry them. Subject identity fields are [EvidenceKind.serverStored]
/// (the server stored what the investigation creator provided; this does
/// not imply the server independently verified the identity).
///
/// Claim text is [EvidenceKind.userClaim] — it originates from a user
/// submission. Verification status is [EvidenceKind.serverVerified] — it
/// was produced by a server-run verification engine.
String assembleDossierContext(DossierView dossier) {
  final facts = <LabelledFact>[];
  final subject = dossier.subject;

  // Subject identity — server-stored (user-provided at investigation creation)
  facts.add(LabelledFact(EvidenceKind.serverStored, 'Referência', subject.ref));
  if (subject.legalName != null) {
    facts.add(LabelledFact(EvidenceKind.serverStored, 'Nome legal', subject.legalName!));
  }
  if (subject.identityStatus != null) {
    facts.add(LabelledFact(EvidenceKind.serverStored, 'Status de identidade', subject.identityStatus!));
  }
  if (subject.registrations.isNotEmpty) {
    facts.add(LabelledFact(EvidenceKind.serverStored, 'Registros', subject.registrations.join('; ')));
  }

  // Claims — text is user-submitted (USER_CLAIM); verification status is server-verified
  if (dossier.claims.isEmpty) {
    facts.add(LabelledFact(EvidenceKind.serverStored, 'Afirmações', 'nenhuma registrada'));
  } else {
    for (final c in dossier.claims.take(10)) {
      final v = c.verification;
      if (v != null) {
        // Verification result: produced by server engine → VERIFIED provenance
        facts.add(LabelledFact(
          EvidenceKind.serverVerified,
          'Verificação ${c.ref}',
          '${v.status} — avaliado em ${v.evaluatedAt ?? "—"}',
        ));
      }
      // Claim text: submitted by user → USER_CLAIM
      facts.add(LabelledFact(
        EvidenceKind.userClaim,
        'Texto da afirmação ${c.ref}',
        _trunc(c.text, 120),
      ));
    }
    if (dossier.claims.length > 10) {
      facts.add(LabelledFact(
        EvidenceKind.serverStored,
        'Afirmações restantes',
        '${dossier.claims.length - 10} não exibidas (limite de contexto)',
      ));
    }
  }

  // Does NOT establish — dossier-level disclaimer (server-stored)
  if (dossier.doesNotEstablish.isNotEmpty) {
    facts.add(LabelledFact(
      EvidenceKind.serverStored,
      'NÃO estabelece',
      dossier.doesNotEstablish.join('; '),
    ));
  }

  // Limitations count (server-stored)
  if (dossier.limitationCount > 0) {
    facts.add(LabelledFact(
      EvidenceKind.serverStored,
      'Limitações',
      '${dossier.limitationCount} registrada(s)',
    ));
  }

  return '$_kIveRules\n\n${facts.map((f) => f.toContextLine()).join('\n')}';
}

String _trunc(String? s, int max) {
  if (s == null || s.isEmpty) return '—';
  return s.length <= max ? s : '${s.substring(0, max)}…';
}

// Escape </value> sequences in user-controlled text so the delimiter cannot
// be broken by injected content. Case variants are also escaped (defense-in-depth;
// the IVE system prompt is the primary injection boundary, not this escaping).
String _sanitize(String s) => s
    .replaceAll('</value>', '<\\/value>')
    .replaceAll('</VALUE>', '<\\/VALUE>')
    .replaceAll('</Value>', '<\\/Value>');
