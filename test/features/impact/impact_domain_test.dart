import 'package:ai_social_copilot/features/impact/data/impact_lab_api.dart';
import 'package:ai_social_copilot/features/impact/domain/dossier_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'impact_test_support.dart';

/// IV-IMPACT-I5 — domain + API layer, against real-engine fixtures.
void main() {
  DossierView view(String name) => DossierView.fromResponse(fixture(name)['data'] as Map<String, dynamic>);

  group('UI-DOM parsing of the real I4 contract', () {
    test('UI-DOM-01 every dossier fixture parses; hash + envelope read verbatim', () {
      for (final n in [
        'dossier_confirmed_pt',
        'dossier_confirmed_en',
        'dossier_conflict_en',
        'dossier_unresolved_pt',
        'dossier_disputed_en',
        'dossier_stale_en',
        'dossier_empty_en',
        'export_confirmed_en',
      ]) {
        final raw = fixture(n)['data'] as Map<String, dynamic>;
        final d = DossierView.fromResponse(raw);
        final doc = raw['dossier'] as Map<String, dynamic>;
        expect(d.integrity.contentHash, (doc['integrity'] as Map)['contentHash'], reason: n);
        expect(d.envelope.raw, doc['envelope'], reason: n);
        expect(d.doesNotEstablish, isNotEmpty, reason: '$n must carry its non-findings');
        expect(d.text, isNotEmpty, reason: n);
      }
    });

    test('UI-DOM-02 live view vs issued snapshot come from the envelope', () {
      expect(view('dossier_confirmed_en').envelope.isSnapshot, isFalse);
      final snap = view('export_confirmed_en');
      expect(snap.envelope.isSnapshot, isTrue);
      expect(snap.envelope.snapshotRef, startsWith('dossier-'));
    });

    test('UI-DOM-03 summary counts are the SERVER counts (not recomputed)', () {
      final raw = copyOf(fixture('dossier_confirmed_en'));
      final summary = (((raw['data'] as Map)['dossier'] as Map)['content'] as Map)['summary'] as Map;
      (summary['byStatus'] as Map)['SUPPORTED'] = 99; // server says 99 → UI shows 99
      summary['openDisputes'] = 7;
      final d = DossierView.fromResponse(raw['data'] as Map<String, dynamic>);
      expect(d.byStatus['SUPPORTED'], 99);
      expect(d.openDisputes, 7);
    });

    test('UI-DOM-04 unknown schema version fails closed', () {
      final raw = copyOf(fixture('dossier_confirmed_en'));
      ((raw['data'] as Map)['dossier'] as Map)['schemaVersion'] = 'impact-dossier/2';
      expect(
        () => DossierView.fromResponse(raw['data'] as Map<String, dynamic>),
        throwsA(isA<ImpactApiException>().having((e) => e.kind, 'kind', ImpactErrorKind.contract)),
      );
    });

    test('UI-DOM-05 a document claiming to be a finding/publication is refused', () {
      for (final flag in ['isFindingOfWrongdoing', 'isPublication']) {
        final raw = copyOf(fixture('dossier_confirmed_en'));
        (((raw['data'] as Map)['dossier'] as Map)['content'] as Map)[flag] = true;
        expect(() => DossierView.fromResponse(raw['data'] as Map<String, dynamic>), throwsA(isA<ImpactApiException>()), reason: flag);
      }
    });

    test('UI-DOM-06 missing hash or envelope fails closed', () {
      for (final key in ['integrity', 'envelope']) {
        final raw = copyOf(fixture('dossier_confirmed_en'));
        ((raw['data'] as Map)['dossier'] as Map).remove(key);
        expect(() => DossierView.fromResponse(raw['data'] as Map<String, dynamic>), throwsA(isA<ImpactApiException>()), reason: key);
      }
    });

    test('UI-DOM-07 labels: server translation, unknown code shown raw (never invented)', () {
      final en = view('dossier_confirmed_en').labels;
      final pt = view('dossier_confirmed_pt').labels;
      expect(en.status('SUPPORTED'), 'Supported by independent evidence');
      expect(pt.status('SUPPORTED'), isNot(en.status('SUPPORTED')));
      expect(en.status('SOME_FUTURE_STATUS'), 'SOME_FUTURE_STATUS');
      expect(en.status(null), '—');
    });

    test('UI-DOM-08 privacy flags survive parsing; withheld excerpt has no text', () {
      final d = view('dossier_conflict_en');
      final withheld = d.evidenceById('e-board')!;
      expect(withheld.excerpt, isNull);
      expect(withheld.excerptWithheld, 'PERSONAL_DATA');
      expect(d.claims.single.textRedacted, isTrue);
      expect(d.evidenceById('e-news')!.excerptRedacted, isTrue);
      expect(d.text, isNot(contains('Jane Example')));
      expect(d.documentJson, isNot(contains('Jane Example')));
    });

    test('UI-DOM-09 provenance: cloud host is a host, never the publisher; locator lines', () {
      final d = view('dossier_confirmed_en');
      final up = d.source('art-report')!;
      expect(up.hostProvider, 'GOOGLE_DRIVE');
      expect(up.publisher, isNot(contains('Google')));
      expect(up.userSubmitted, isTrue);
      final ev = d.evidenceFor('c-wells').single;
      expect(ev.locatorArtifactRef, 'art-report');
      expect(ev.locatorLines, '2');
      expect(ev.locatorState, 'VALID');
    });

    test('UI-DOM-10 export JSON is the server document, not a rebuild', () {
      final raw = fixture('export_confirmed_en')['data'] as Map<String, dynamic>;
      final d = DossierView.fromResponse(raw);
      expect(d.document, same(raw['dossier']));
    });

    test('UI-DOM-11 large dossier (500 claims) parses without truncation', () {
      final d = DossierView.fromResponse(largeDossier(500)['data'] as Map<String, dynamic>);
      expect(d.claims, hasLength(500));
      expect(d.claims.last.ref, 'c-499');
    });
  });

  group('UI-API error mapping (no oracle, typed)', () {
    test('UI-API-01 403 and 404 are the same kind', () {
      expect(impactErrorFrom(403, {'error': 'FORBIDDEN'}).kind, ImpactErrorKind.notAvailable);
      expect(impactErrorFrom(404, {'error': 'INVESTIGATION_NOT_FOUND'}).kind, ImpactErrorKind.notAvailable);
    });

    test('UI-API-02 401 / 413 / 429 / 5xx / 400', () {
      expect(impactErrorFrom(401, null).kind, ImpactErrorKind.auth);
      expect(impactErrorFrom(413, {'error': 'DOSSIER_TOO_LARGE'}).kind, ImpactErrorKind.tooLarge);
      final rl = impactErrorFrom(429, {'error': 'RATE_LIMITED', 'retry_after': 17});
      expect(rl.kind, ImpactErrorKind.rateLimited);
      expect(rl.retryAfterSeconds, 17);
      expect(impactErrorFrom(429, {'error': 'RATE_LIMITED'}).retryAfterSeconds, 60);
      expect(impactErrorFrom(429, {'retry_after': -5}).retryAfterSeconds, 60);
      expect(impactErrorFrom(500, {'error': 'INTERNAL_ERROR'}).kind, ImpactErrorKind.server);
      expect(impactErrorFrom(400, {'error': 'INVALID_REQUEST'}).kind, ImpactErrorKind.invalidRequest);
    });

    test('UI-API-03 sends only the read action and its params (no role / user id)', () async {
      final tr = FakeImpactTransport(dossier: fixture('dossier_confirmed_en'));
      await ImpactLabApi(tr).getDossier(kInvestigationId, 'en');
      expect(tr.calls.single, {'action': 'get_dossier', 'investigation_id': kInvestigationId, 'lang': 'en'});
    });

    test('UI-API-04 a response for another action is a contract error', () async {
      final tr = FakeImpactTransport(dossier: fixture('list_investigations'));
      expect(
        () => ImpactLabApi(tr).getDossier(kInvestigationId, 'en'),
        throwsA(isA<ImpactApiException>().having((e) => e.kind, 'kind', ImpactErrorKind.contract)),
      );
    });

    test('UI-API-05 export must return a SNAPSHOT envelope', () async {
      final tr = FakeImpactTransport(export: copyOf(fixture('dossier_confirmed_en'))..['action'] = 'export_dossier');
      expect(() => ImpactLabApi(tr).exportDossier(kInvestigationId, 'en'), throwsA(isA<ImpactApiException>()));
    });

    test('UI-API-06 verify presents the issued hash + envelope verbatim; server decides', () async {
      final snap = view('export_confirmed_en');
      final tr = FakeImpactTransport(verify: fixture('verify_stale'));
      final r = await ImpactLabApi(tr).verifyDossier(kInvestigationId, snap);
      expect(tr.calls.single['content_hash'], snap.integrity.contentHash);
      expect(tr.calls.single['envelope'], same(snap.envelope.raw));
      expect(r.state, 'STALE');
    });

    test('UI-API-07 verify without integrityIsNotTruth is refused', () {
      final data = copyOf(fixture('verify_current'))['data'] as Map<String, dynamic>;
      data.remove('integrityIsNotTruth');
      expect(() => VerifyResult.fromData(data), throwsA(isA<ImpactApiException>()));
    });

    test('UI-API-08 list parses the caller investigations', () async {
      final list = await ImpactLabApi(FakeImpactTransport(list: fixture('list_investigations'))).listInvestigations();
      expect(list.single.id, kInvestigationId);
    });
  });
}

/// A large dossier derived from a real fixture: 500 copies of its claim.
Map<String, dynamic> largeDossier(int n) {
  final raw = copyOf(fixture('dossier_confirmed_en'));
  final content = ((raw['data'] as Map)['dossier'] as Map)['content'] as Map;
  final base = (content['claims'] as List).first as Map<String, dynamic>;
  content['claims'] = [
    for (var i = 0; i < n; i++) copyOf(base)..['ref'] = 'c-$i',
  ];
  (content['summary'] as Map)['claims'] = n;
  return raw;
}
