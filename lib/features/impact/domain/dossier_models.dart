import 'dart:convert';

import '../data/impact_lab_api.dart';

/// IV-IMPACT-I5 — read-only view of the I4 dossier contract
/// (`impact-dossier/1`).
///
/// Nothing here derives truth: every status, class, sufficiency, limitation
/// and hash is read verbatim from the server document, and every label is
/// the server's audited translation (`data.labels`). Parsing is defensive —
/// a missing optional field becomes null/empty, but a document with an
/// unknown schema version is refused (fail closed) instead of being shown
/// half-understood.

const kDossierSchemaVersion = 'impact-dossier/1';

Map<String, dynamic> _map(Object? v) => v is Map<String, dynamic> ? v : const {};
List<Map<String, dynamic>> _maps(Object? v) =>
    v is List ? v.whereType<Map<String, dynamic>>().toList(growable: false) : const [];
List<String> _strings(Object? v) =>
    v is List ? v.whereType<String>().map(displaySafe).toList(growable: false) : const [];
String? _str(Object? v) => v is String ? displaySafe(v) : null;

/// Codex I5G3-01 — server strings are DATA, rendered inside UI chrome. Strip
/// what could disguise or reorder them (bidi overrides/isolates, zero-width
/// and other invisible format characters, C0/C1 controls), flatten line
/// breaks, and bound the length so a hostile value cannot impersonate UI
/// text or break the layout. Display only: export copies the untouched
/// server document.
const kMaxDisplayChars = 2000;
final _invisible = RegExp('[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F\u00AD\u061C\u180E\u200B-\u200F\u202A-\u202E\u2060-\u2064\u2066-\u206F\uFEFF]');
final _breaks = RegExp('[\r\n\t\u2028\u2029]+');

String displaySafe(String s) {
  final flat = s.replaceAll(_invisible, '').replaceAll(_breaks, ' ');
  return flat.length <= kMaxDisplayChars ? flat : '${flat.substring(0, kMaxDisplayChars)}…';
}
int _int(Object? v) => v is int ? v : 0;
bool _bool(Object? v) => v == true;

Never _contract() => throw const ImpactApiException(ImpactErrorKind.contract);

// Codex I5G1-02/03 — strict, fail-closed structure checks. "Defensive"
// must never mean "permissive": a malformed element, an unknown enum value
// or a list that does not match the server's own counts rejects the WHOLE
// document, so a partial or truncated dossier can never look complete.
const kEnvelopeKinds = {'LIVE', 'SNAPSHOT'};
const kVerifyStates = {'CURRENT', 'STALE', 'NOT_ISSUED'};
const kEnvelopeStates = {'MATCHES_REGISTRATION', 'MISMATCH', 'LIVE_VIEW_NOT_A_SNAPSHOT', 'NOT_PROVIDED'};

List<Map<String, dynamic>> _strictMaps(Object? v, List<String> requiredStrings) {
  if (v is! List) _contract();
  final out = <Map<String, dynamic>>[];
  for (final e in v) {
    if (e is! Map<String, dynamic>) _contract();
    for (final k in requiredStrings) {
      if (e[k] is! String) _contract();
    }
    out.add(e);
  }
  return out;
}

List<String> _strictStrings(Object? v) {
  if (v is! List || v.any((e) => e is! String)) _contract();
  return v.cast<String>().toList(growable: false);
}

int _strictInt(Map<String, dynamic> m, String k) {
  final v = m[k];
  if (v is! int || v < 0) _contract();
  return v;
}

/// Validates the parts of `content` the UI renders. Returns normally only
/// when every rendered structure is well-formed and matches the server's
/// own summary counts.
void _validateContent(Map<String, dynamic> c) {
  final claims = _strictMaps(c['claims'], const ['ref']);
  for (final cl in claims) {
    final v = cl['verification'];
    if (v == null) continue;
    if (v is! Map<String, dynamic>) _contract();
    for (final k in const ['status', 'displayClass', 'sufficiency']) {
      if (v[k] is! String) _contract();
    }
    for (final k in const ['supporting', 'partiallySupporting', 'contradicting', 'contextual', 'excluded']) {
      if (v[k] != null) _strictMaps(v[k], const []);
    }
    if (v['conflicts'] != null) {
      for (final k in _strictMaps(v['conflicts'], const ['kind', 'basis'])) {
        _strictMaps(k['positions'], const ['evidenceId', 'sourceId']);
      }
    }
  }
  final evidence = _strictMaps(c['evidence'], const ['ref']);
  final sources = _strictMaps(c['sources'], const ['ref']);
  final disputes = _strictMaps(c['disputes'], const ['ref']);
  final limitations = _strictMaps(c['limitations'], const ['code']);
  _strictMaps(c['registryFacts'], const ['sourceRef']);
  _strictMaps(c['registryConflicts'], const ['kind']);
  if (_strictStrings(c['doesNotEstablish']).isEmpty) _contract();
  final subject = c['subject'];
  if (subject is! Map<String, dynamic> || subject['identityStatus'] is! String) _contract();
  final summary = c['summary'];
  if (summary is! Map<String, dynamic>) _contract();
  final byStatus = summary['byStatus'];
  if (byStatus is! Map<String, dynamic> || byStatus.values.any((x) => x is! int)) _contract();
  if (_strictInt(summary, 'claims') != claims.length ||
      _strictInt(summary, 'evidence') != evidence.length ||
      _strictInt(summary, 'sources') != sources.length ||
      _strictInt(summary, 'limitations') != limitations.length ||
      _strictInt(summary, 'openDisputes') != disputes.where((d) => d['open'] == true).length) {
    _contract(); // truncated or inconsistent: never shown as complete
  }
  _strictInt(summary, 'notVerified');
  _strictInt(summary, 'reverificationPending');
}

class InvestigationSummary {
  const InvestigationSummary({required this.id, required this.subjectOrgRef, required this.status, this.createdAt});

  final String id;
  final String subjectOrgRef;
  final String status;
  final String? createdAt;
}

List<InvestigationSummary> parseInvestigations(Map<String, dynamic> data) => [
      for (final m in _maps(data['investigations']))
        if (_str(m['id']) != null)
          InvestigationSummary(
            id: m['id'] as String,
            subjectOrgRef: _str(m['subjectOrgRef']) ?? '—',
            status: _str(m['status']) ?? '—',
            createdAt: _str(m['createdAt']),
          ),
    ];

/// Server-translated vocabulary. An unknown code is shown as the raw code —
/// never replaced with an invented, friendlier (and possibly wrong) word.
class DossierLabels {
  DossierLabels(Map<String, dynamic> raw)
      : _groups = {
          for (final e in raw.entries)
            if (e.value is Map)
              e.key: {
                for (final l in (e.value as Map).entries)
                  if (l.key is String && l.value is String) l.key as String: l.value as String,
              },
        };

  final Map<String, Map<String, String>> _groups;

  String of(String group, String? code) {
    if (code == null) return '—';
    return _groups[group]?[code] ?? code;
  }

  String status(String? c) => of('status', c);
  String displayClass(String? c) => of('displayClass', c);
  String sufficiency(String? c) => of('sufficiency', c);
  String dossierStatus(String? c) => of('dossierStatus', c);
  String identity(String? c) => of('identity', c);
  String limitation(String? c) => of('limitation', c);
  String nonFinding(String? c) => of('nonFinding', c);
  String locatorState(String? c) => of('locatorState', c);
  String reverifyReason(String? c) => of('reverifyReason', c);
  String gap(String? c) => of('gap', c);
  String conflictKind(String? c) => of('conflictKind', c);
  String conflictBasis(String? c) => of('conflictBasis', c);
  String section(String c) => of('section', c);
  String misc(String c) => of('misc', c);
}

class DossierSubject {
  DossierSubject(Map<String, dynamic> m)
      : ref = _str(m['ref']) ?? '—',
        type = _str(m['type']),
        // '—' is the server's withheld marker (I6 privacy): show the subject ref instead.
        legalName = _str(_map(m['declaredIdentity'])['legalName']) == '—' ? null : _str(_map(m['declaredIdentity'])['legalName']),
        registrations = [
          for (final r in _maps(_map(m['declaredIdentity'])['registrations']))
            [
              _str(r['scheme']),
              _str(r['value']),
              _str(_map(r['jurisdiction'])['country']),
            ].whereType<String>().join(' · '),
        ],
        domains = _strings(_map(m['declaredIdentity'])['domains']),
        identityStatus = _str(m['identityStatus']),
        identityConfirmed = _bool(m['identityConfirmed']);

  final String ref;
  final String? type;
  final String? legalName;
  final List<String> registrations;
  final List<String> domains;
  final String? identityStatus;
  final bool identityConfirmed;
}

class RegistryFact {
  RegistryFact(Map<String, dynamic> m)
      : sourceRef = _str(m['sourceRef']) ?? '—',
        providerId = _str(m['providerId']),
        legalName = _str(m['legalName']),
        registryStatus = _str(m['registryStatus']),
        statusAsOf = _str(m['statusAsOf']),
        freshAtAsOf = _bool(m['freshAtAsOf']),
        synthetic = _bool(m['synthetic']),
        official = _bool(_map(m['authority'])['official']);

  final String sourceRef;
  final String? providerId;
  final String? legalName;
  final String? registryStatus;
  final String? statusAsOf;
  final bool freshAtAsOf;
  final bool synthetic;
  final bool official;
}

class RegistryConflict {
  RegistryConflict(Map<String, dynamic> m)
      : kind = _str(m['kind']) ?? '—',
        sourceRef = _str(m['sourceRef']) ?? '—',
        otherSourceRef = _str(m['otherSourceRef']) ?? '—';

  final String kind;
  final String sourceRef;
  final String otherSourceRef;
}

/// One evidence item as the verification engine CLASSIFIED it.
class AssessedEvidence {
  AssessedEvidence(Map<String, dynamic> m)
      : evidenceRef = _str(m['evidenceRef']) ?? '—',
        sourceRef = _str(m['sourceRef']) ?? '—',
        authority = _str(m['authority']),
        relationship = _str(m['effectiveRelationship']);

  final String evidenceRef;
  final String sourceRef;
  final String? authority;
  final String? relationship;
}

class ConflictPosition {
  ConflictPosition(Map<String, dynamic> m)
      : evidenceId = _str(m['evidenceId']) ?? '—',
        sourceId = _str(m['sourceId']) ?? '—',
        publisher = _str(m['publisher']) ?? '—',
        relationship = _str(m['relationship']),
        reportedValue = m['reportedValue'] is num ? m['reportedValue'] as num : null;

  final String evidenceId;
  final String sourceId;
  final String publisher;
  final String? relationship;
  final num? reportedValue;
}

class ConflictView {
  ConflictView(Map<String, dynamic> m)
      : kind = _str(m['kind']),
        basis = _str(m['basis']),
        positions = [for (final p in _maps(m['positions'])) ConflictPosition(p)];

  final String? kind;
  final String? basis;
  final List<ConflictPosition> positions;
}

class VerificationView {
  VerificationView(Map<String, dynamic> m)
      : status = _str(m['status']),
        displayClass = _str(m['displayClass']),
        sufficiency = _str(m['sufficiency']),
        gaps = _strings(m['gaps']),
        rulesApplied = _strings(m['rulesApplied']),
        policyVersion = _str(m['policyVersion']),
        evaluatedAt = _str(m['evaluatedAt']),
        supporting = [for (final x in _maps(m['supporting'])) AssessedEvidence(x)],
        partiallySupporting = [for (final x in _maps(m['partiallySupporting'])) AssessedEvidence(x)],
        contradicting = [for (final x in _maps(m['contradicting'])) AssessedEvidence(x)],
        contextual = [for (final x in _maps(m['contextual'])) AssessedEvidence(x)],
        excluded = [for (final x in _maps(m['excluded'])) AssessedEvidence(x)],
        conflicts = [for (final x in _maps(m['conflicts'])) ConflictView(x)],
        independentVoices = _int(_map(m['independence'])['independentVoices']),
        documents = _maps(_map(m['independence'])['sources']).length;

  final String? status;
  final String? displayClass;
  final String? sufficiency;
  final List<String> gaps;
  final List<String> rulesApplied;
  final String? policyVersion;
  final String? evaluatedAt;
  final List<AssessedEvidence> supporting;
  final List<AssessedEvidence> partiallySupporting;
  final List<AssessedEvidence> contradicting;
  final List<AssessedEvidence> contextual;
  final List<AssessedEvidence> excluded;
  final List<ConflictView> conflicts;
  final int independentVoices;

  /// Length of the server's own `independence.sources` list.
  final int documents;
}

class ClaimView {
  ClaimView(Map<String, dynamic> m)
      : ref = _str(m['ref']) ?? '—',
        kind = _str(m['kind']),
        text = _str(m['text']),
        textWithheld = _str(m['textWithheld']),
        textRedacted = _bool(m['textRedacted']),
        textAttribution = _str(m['textAttribution']),
        sourceRef = _str(m['sourceRef']),
        quantity = m['quantity'] is Map<String, dynamic> ? m['quantity'] as Map<String, dynamic> : null,
        verification = m['verification'] is Map<String, dynamic>
            ? VerificationView(m['verification'] as Map<String, dynamic>)
            : null,
        reverificationPending = _bool(m['reverificationPending']),
        reverificationReasons = _strings(m['reverificationReasons']),
        disputeRefs = _strings(m['disputeRefs']),
        evidenceRefs = _strings(m['evidenceRefs']);

  final String ref;
  final String? kind;
  final String? text;
  final String? textWithheld;
  final bool textRedacted;
  final String? textAttribution;
  final String? sourceRef;
  final Map<String, dynamic>? quantity;
  final VerificationView? verification;
  final bool reverificationPending;
  final List<String> reverificationReasons;
  final List<String> disputeRefs;
  final List<String> evidenceRefs;
}

class EvidenceView {
  EvidenceView(Map<String, dynamic> m)
      : ref = _str(m['ref']) ?? '—',
        claimRef = _str(m['claimRef']),
        sourceRef = _str(m['sourceRef']),
        relationship = _str(m['relationship']),
        basis = _str(m['basis']),
        excerpt = _str(m['excerpt']),
        excerptWithheld = _str(m['excerptWithheld']),
        excerptRedacted = _bool(m['excerptRedacted']),
        excerptAttribution = _str(m['excerptAttribution']),
        locatorState = _str(m['locatorState']),
        locatorArtifactRef = _str(_map(_map(m['locator'])['artifact'])['ref']),
        locatorLines = _lines(_map(_map(_map(m['locator'])['artifact'])['locator']));

  static String? _lines(Map<String, dynamic> l) {
    final a = l['lineStart'], b = l['lineEnd'];
    if (a is! int) return null;
    return b is int && b != a ? '$a–$b' : '$a';
  }

  final String ref;
  final String? claimRef;
  final String? sourceRef;
  final String? relationship;
  final String? basis;
  final String? excerpt;
  final String? excerptWithheld;
  final bool excerptRedacted;
  final String? excerptAttribution;
  final String? locatorState;
  final String? locatorArtifactRef;
  final String? locatorLines;
}

class SourceView {
  SourceView(Map<String, dynamic> m)
      : ref = _str(m['ref']) ?? '—',
        type = _str(m['type']),
        publisher = _str(m['publisher']),
        uri = _str(m['uri']),
        status = _str(m['status']),
        acquisition = _str(m['acquisition']),
        userSubmitted = _bool(m['userSubmitted']),
        hostProvider = _str(_map(m['host'])['provider']),
        artifactRef = _str(m['artifactRef']),
        retrievedAt = _str(m['retrievedAt']);

  final String ref;
  final String? type;
  final String? publisher;
  final String? uri;
  final String? status;
  final String? acquisition;
  final bool userSubmitted;

  /// Cloud host of an uploaded document. It HOSTS the file; it never
  /// becomes the publisher (I3 provenance rule).
  final String? hostProvider;
  final String? artifactRef;
  final String? retrievedAt;
}

class DisputeView {
  DisputeView(Map<String, dynamic> m)
      : ref = _str(m['ref']) ?? '—',
        claimRef = _str(m['claimRef']),
        kind = _str(m['kind']),
        open = _bool(m['open']),
        resolution = _str(m['resolution']),
        openedAt = _str(m['openedAt']);

  final String ref;
  final String? claimRef;
  final String? kind;
  final bool open;
  final String? resolution;
  final String? openedAt;
}

class LimitationView {
  LimitationView(Map<String, dynamic> m)
      : code = _str(m['code']) ?? '—',
        scope = _str(m['scope']),
        ref = _str(m['ref']);

  final String code;
  final String? scope;
  final String? ref;
}

class DossierIntegrity {
  DossierIntegrity(Map<String, dynamic> m)
      : algorithm = _str(m['algorithm']) ?? '—',
        canonicalization = _str(m['canonicalization']) ?? '—',
        contentHash = _str(m['contentHash']) ?? _contract();

  final String algorithm;
  final String canonicalization;
  final String contentHash;
}

class DossierEnvelope {
  DossierEnvelope(this.raw)
      : kind = kEnvelopeKinds.contains(raw['kind']) ? raw['kind'] as String : _contract(),
        generatedAt = _str(raw['generatedAt']),
        snapshotRef = _str(raw['snapshotRef']),
        auditSeq = _int(raw['auditSeq']) {
    // A snapshot without its reference is not a snapshot (I5G1-03).
    if (kind == 'SNAPSHOT' && snapshotRef == null) _contract();
  }

  /// Exactly what the server sent — presented back verbatim on verify.
  final Map<String, dynamic> raw;
  final String kind;
  final String? generatedAt;
  final String? snapshotRef;
  final int auditSeq;

  bool get isSnapshot => kind == 'SNAPSHOT';
}

class DossierView {
  DossierView._({
    required this.document,
    required this.text,
    required this.labels,
    required this.integrity,
    required this.envelope,
    required this.investigationStatus,
    required this.asOf,
    required this.dossierStatus,
    required this.subject,
    required this.registryFacts,
    required this.registryConflicts,
    required this.claims,
    required this.evidence,
    required this.sources,
    required this.disputes,
    required this.limitations,
    required this.doesNotEstablish,
    required this.summary,
    required this.byStatus,
  });

  /// Parses a get_dossier / export_dossier `data` object. Throws a
  /// contract error on an unknown schema or a missing hash/envelope.
  factory DossierView.fromResponse(Map<String, dynamic> data) {
    final doc = data['dossier'];
    if (doc is! Map<String, dynamic> || doc['schemaVersion'] != kDossierSchemaVersion) _contract();
    final c = doc['content'];
    if (c is! Map<String, dynamic> || c['schemaVersion'] != kDossierSchemaVersion) _contract();
    // The contract's own non-finding flags must be present and unchanged.
    if (c['isFindingOfWrongdoing'] != false || c['isPublication'] != false) _contract();
    _validateContent(c);
    if (data['text'] is! String || (data['text'] as String).isEmpty || data['labels'] is! Map<String, dynamic>) _contract();
    return DossierView._(
      document: doc,
      // Raw on purpose: the export must be the server's bytes (display-safe
      // normalization applies only to values rendered inside UI chrome).
      text: data['text'] as String,
      labels: DossierLabels(_map(data['labels'])),
      integrity: DossierIntegrity(_map(doc['integrity'])),
      envelope: DossierEnvelope(_map(doc['envelope'])),
      investigationStatus: _str(_map(c['investigation'])['status']),
      asOf: _str(c['asOf']),
      dossierStatus: _str(c['dossierStatus']),
      subject: DossierSubject(_map(c['subject'])),
      registryFacts: [for (final x in _maps(c['registryFacts'])) RegistryFact(x)],
      registryConflicts: [for (final x in _maps(c['registryConflicts'])) RegistryConflict(x)],
      claims: [for (final x in _maps(c['claims'])) ClaimView(x)],
      evidence: [for (final x in _maps(c['evidence'])) EvidenceView(x)],
      sources: [for (final x in _maps(c['sources'])) SourceView(x)],
      disputes: [for (final x in _maps(c['disputes'])) DisputeView(x)],
      limitations: [for (final x in _maps(c['limitations'])) LimitationView(x)],
      doesNotEstablish: _strings(c['doesNotEstablish']),
      summary: {
        for (final e in _map(c['summary']).entries)
          if (e.value is int) e.key: e.value as int,
      },
      byStatus: {
        for (final e in _map(_map(c['summary'])['byStatus']).entries)
          if (e.value is int) e.key: e.value as int,
      },
    );
  }

  /// The server document, untouched. Export copies THIS, never a rebuild.
  final Map<String, dynamic> document;

  /// The server's human-readable rendering (same content, same labels).
  final String text;
  final DossierLabels labels;
  final DossierIntegrity integrity;
  final DossierEnvelope envelope;
  final String? investigationStatus;
  final String? asOf;
  final String? dossierStatus;
  final DossierSubject subject;
  final List<RegistryFact> registryFacts;
  final List<RegistryConflict> registryConflicts;
  final List<ClaimView> claims;
  final List<EvidenceView> evidence;
  final List<SourceView> sources;
  final List<DisputeView> disputes;
  final List<LimitationView> limitations;
  final List<String> doesNotEstablish;
  /// Server counts (`content.summary`) — the UI never recounts truth.
  final Map<String, int> summary;
  final Map<String, int> byStatus;

  String get documentJson => const JsonEncoder.withIndent('  ').convert(document);

  List<EvidenceView> evidenceFor(String claimRef) =>
      evidence.where((e) => e.claimRef == claimRef).toList(growable: false);

  SourceView? source(String? ref) {
    for (final s in sources) {
      if (s.ref == ref) return s;
    }
    return null;
  }

  EvidenceView? evidenceById(String ref) {
    for (final e in evidence) {
      if (e.ref == ref) return e;
    }
    return null;
  }

  /// Limitation codes in server order, de-duplicated, with their refs.
  List<MapEntry<String, List<String>>> get groupedLimitations {
    final out = <String, List<String>>{};
    for (final l in limitations) {
      final refs = out.putIfAbsent(l.code, () => []);
      if (l.ref != null && !refs.contains(l.ref)) refs.add(l.ref!);
    }
    return out.entries.toList(growable: false);
  }

  int get openDisputes => summary['openDisputes'] ?? 0;

  /// Server count of limitation entries (I5G1-05), not the grouped lines.
  int get limitationCount => summary['limitations'] ?? 0;

  /// Limitations that apply to one claim or to its evidence.
  List<LimitationView> limitationsForClaim(ClaimView claim) {
    final evRefs = evidenceFor(claim.ref).map((e) => e.ref).toSet();
    return limitations
        .where((l) => (l.scope == 'CLAIM' && l.ref == claim.ref) || (l.scope == 'EVIDENCE' && evRefs.contains(l.ref)))
        .toList(growable: false);
  }
}

class VerifyResult {
  VerifyResult._({
    required this.state,
    required this.envelopeState,
    required this.snapshotRef,
    required this.exportedAt,
  });

  factory VerifyResult.fromData(Map<String, dynamic> d) {
    final state = d['state'];
    final envelopeState = d['envelopeState'];
    // Only the enumerated server answers are accepted; an unknown state is
    // never mapped to "not issued" or anything else (I5G1-03).
    if (!kVerifyStates.contains(state) || !kEnvelopeStates.contains(envelopeState) || d['integrityIsNotTruth'] != true) {
      _contract();
    }
    return VerifyResult._(
      state: state as String,
      envelopeState: envelopeState as String,
      snapshotRef: _str(_map(d['snapshot'])['ref']),
      exportedAt: _str(_map(d['snapshot'])['exportedAt']),
    );
  }

  /// CURRENT | STALE | NOT_ISSUED — decided by the server.
  final String state;

  /// MATCHES_REGISTRATION | MISMATCH | LIVE_VIEW_NOT_A_SNAPSHOT | NOT_PROVIDED.
  final String envelopeState;
  final String? snapshotRef;
  final String? exportedAt;
}
