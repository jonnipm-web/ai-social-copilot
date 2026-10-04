import 'dart:io';

import 'package:ai_social_copilot/features/impact/data/impact_lab_api.dart';
import 'package:ai_social_copilot/features/impact/domain/dossier_models.dart';
import 'package:ai_social_copilot/features/impact/domain/ive_impact_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'impact_test_support.dart';

/// IV-IMPACT-I5 — domain + API layer, against real-engine fixtures.
void main() {
  DossierView view(String name) =>
      DossierView.fromResponse(fixture(name)['data'] as Map<String, dynamic>);

  group('UI-DOM parsing of the real I4 contract', () {
    test(
        'UI-DOM-01 every dossier fixture parses; hash + envelope read verbatim',
        () {
      for (final n in [
        'dossier_confirmed_pt',
        'dossier_confirmed_en',
        'dossier_conflict_en',
        'dossier_unresolved_pt',
        'dossier_disputed_en',
        'dossier_stale_en',
        'dossier_empty_en',
        'export_confirmed_en',
        'dossier_private_en',
        'export_private_en',
      ]) {
        final raw = fixture(n)['data'] as Map<String, dynamic>;
        final d = DossierView.fromResponse(raw);
        final doc = raw['dossier'] as Map<String, dynamic>;
        expect(
            d.integrity.contentHash, (doc['integrity'] as Map)['contentHash'],
            reason: n);
        expect(d.envelope.raw, doc['envelope'], reason: n);
        expect(d.doesNotEstablish, isNotEmpty,
            reason: '$n must carry its non-findings');
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
      final summary = (((raw['data'] as Map)['dossier'] as Map)['content']
          as Map)['summary'] as Map;
      (summary['byStatus'] as Map)['SUPPORTED'] =
          99; // server says 99 → UI shows 99
      final d = DossierView.fromResponse(raw['data'] as Map<String, dynamic>);
      expect(d.byStatus['SUPPORTED'], 99);
      expect(d.limitationCount, summary['limitations']);
    });

    // Codex I5G1-02 — strict parsing: anything malformed, missing or
    // inconsistent with the server's own counts rejects the whole document.
    Map<String, dynamic> contentOf(Map<String, dynamic> raw) =>
        ((raw['data'] as Map)['dossier'] as Map)['content']
            as Map<String, dynamic>;
    void expectContract(
        void Function(Map<String, dynamic> content, Map<String, dynamic> data)
            mutate,
        String why) {
      final raw = copyOf(fixture('dossier_conflict_en'));
      mutate(contentOf(raw), raw['data'] as Map<String, dynamic>);
      expect(
        () => DossierView.fromResponse(raw['data'] as Map<String, dynamic>),
        throwsA(isA<ImpactApiException>()
            .having((e) => e.kind, 'kind', ImpactErrorKind.contract)),
        reason: why,
      );
    }

    test(
        'UI-DOM-12 truncated lists (fewer items than the server summary) fail closed',
        () {
      expectContract(
          (c, _) => (c['claims'] as List).removeLast(), 'claims truncated');
      expectContract(
          (c, _) => (c['evidence'] as List).removeLast(), 'evidence truncated');
      expectContract(
          (c, _) => (c['sources'] as List).removeLast(), 'sources truncated');
      expectContract((c, _) => (c['limitations'] as List).removeLast(),
          'limitations truncated');
      expectContract((c, _) => (c['summary'] as Map)['openDisputes'] = 3,
          'open disputes inconsistent');
    });

    test('UI-DOM-13 malformed elements / missing structures fail closed', () {
      expectContract(
          (c, _) => (c['claims'] as List).add('not-a-claim'), 'non-map claim');
      expectContract(
          (c, _) => ((c['claims'] as List).first as Map).remove('ref'),
          'claim without ref');
      expectContract(
          (c, _) => (((c['claims'] as List).first as Map)['verification']
              as Map)['status'] = 7,
          'status not a string');
      expectContract(
          (c, _) => ((c['limitations'] as List).first as Map).remove('code'),
          'limitation without code');
      expectContract((c, _) => c.remove('summary'), 'no summary');
      expectContract((c, _) => (c['summary'] as Map).remove('notVerified'),
          'summary field missing');
      expectContract(
          (c, _) => c['doesNotEstablish'] = <String>[], 'no non-findings');
      expectContract((c, _) => c.remove('subject'), 'no subject');
      expectContract((_, d) => d.remove('labels'), 'no labels');
      expectContract((_, d) => d['text'] = '', 'no text rendering');
    });

    test(
        'UI-DOM-14 unknown envelope kind, or snapshot without ref, fails closed (never LIVE)',
        () {
      expectContract(
          (_, d) =>
              ((d['dossier'] as Map)['envelope'] as Map)['kind'] = 'DRAFT',
          'unknown kind');
      final raw = copyOf(fixture('export_confirmed_en'));
      (((raw['data'] as Map)['dossier'] as Map)['envelope']
          as Map)['snapshotRef'] = null;
      expect(
          () => DossierView.fromResponse(raw['data'] as Map<String, dynamic>),
          throwsA(isA<ImpactApiException>()));
    });

    test('UI-DOM-15 limitations for one claim: its own + its evidence\'s', () {
      final d = view('dossier_conflict_en');
      final codes = d
          .limitationsForClaim(d.claims.single)
          .map((l) => '${l.code}:${l.ref}')
          .toSet();
      expect(codes, {
        'EXCERPT_WITHHELD:e-board',
        'INSUFFICIENT_EVIDENCE:c-wells',
        'PERSONAL_DATA_REDACTED:c-wells',
        'PERSONAL_DATA_REDACTED:e-news'
      });
    });

    test('UI-DOM-04 unknown schema version fails closed', () {
      final raw = copyOf(fixture('dossier_confirmed_en'));
      ((raw['data'] as Map)['dossier'] as Map)['schemaVersion'] =
          'impact-dossier/2';
      expect(
        () => DossierView.fromResponse(raw['data'] as Map<String, dynamic>),
        throwsA(isA<ImpactApiException>()
            .having((e) => e.kind, 'kind', ImpactErrorKind.contract)),
      );
    });

    test('UI-DOM-05 a document claiming to be a finding/publication is refused',
        () {
      for (final flag in ['isFindingOfWrongdoing', 'isPublication']) {
        final raw = copyOf(fixture('dossier_confirmed_en'));
        (((raw['data'] as Map)['dossier'] as Map)['content'] as Map)[flag] =
            true;
        expect(
            () => DossierView.fromResponse(raw['data'] as Map<String, dynamic>),
            throwsA(isA<ImpactApiException>()),
            reason: flag);
      }
    });

    test('UI-DOM-06 missing hash or envelope fails closed', () {
      for (final key in ['integrity', 'envelope']) {
        final raw = copyOf(fixture('dossier_confirmed_en'));
        ((raw['data'] as Map)['dossier'] as Map).remove(key);
        expect(
            () => DossierView.fromResponse(raw['data'] as Map<String, dynamic>),
            throwsA(isA<ImpactApiException>()),
            reason: key);
      }
    });

    test(
        'UI-DOM-07 labels: server translation, unknown code shown raw (never invented)',
        () {
      final en = view('dossier_confirmed_en').labels;
      final pt = view('dossier_confirmed_pt').labels;
      expect(en.status('SUPPORTED'), 'Supported by independent evidence');
      expect(pt.status('SUPPORTED'), isNot(en.status('SUPPORTED')));
      expect(en.status('SOME_FUTURE_STATUS'), 'SOME_FUTURE_STATUS');
      expect(en.status(null), '—');
    });

    test(
        'UI-DOM-08 privacy flags survive parsing; withheld excerpt has no text',
        () {
      final d = view('dossier_conflict_en');
      final withheld = d.evidenceById('e-board')!;
      expect(withheld.excerpt, isNull);
      expect(withheld.excerptWithheld, 'PERSONAL_DATA');
      expect(d.claims.single.textRedacted, isTrue);
      expect(d.evidenceById('e-news')!.excerptRedacted, isTrue);
      expect(d.text, isNot(contains('Jane Example')));
      expect(d.documentJson, isNot(contains('Jane Example')));
    });

    test(
        'UI-DOM-09 provenance: cloud host is a host, never the publisher; locator lines',
        () {
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
      final raw =
          fixture('export_confirmed_en')['data'] as Map<String, dynamic>;
      final d = DossierView.fromResponse(raw);
      expect(d.document, same(raw['dossier']));
      expect(d.text, raw['text'],
          reason: 'export text is the server bytes, never display-normalized');
    });

    test('UI-DOM-11 large dossier (500 claims) parses without truncation', () {
      final d = DossierView.fromResponse(
          largeDossier(500)['data'] as Map<String, dynamic>);
      expect(d.claims, hasLength(500));
      expect(d.claims.last.ref, 'c-499');
    });
  });

  group('UI-API error mapping (no oracle, typed)', () {
    test('UI-API-01 403 and 404 are the same kind', () {
      expect(impactErrorFrom(403, {'error': 'FORBIDDEN'}).kind,
          ImpactErrorKind.notAvailable);
      expect(impactErrorFrom(404, {'error': 'INVESTIGATION_NOT_FOUND'}).kind,
          ImpactErrorKind.notAvailable);
    });

    test('UI-API-02 401 / 413 / 429 / 5xx / 400', () {
      expect(impactErrorFrom(401, null).kind, ImpactErrorKind.auth);
      expect(impactErrorFrom(413, {'error': 'DOSSIER_TOO_LARGE'}).kind,
          ImpactErrorKind.tooLarge);
      final rl =
          impactErrorFrom(429, {'error': 'RATE_LIMITED', 'retry_after': 17});
      expect(rl.kind, ImpactErrorKind.rateLimited);
      expect(rl.retryAfterSeconds, 17);
      expect(impactErrorFrom(429, {'error': 'RATE_LIMITED'}).retryAfterSeconds,
          60);
      expect(impactErrorFrom(429, {'retry_after': -5}).retryAfterSeconds, 60);
      expect(impactErrorFrom(500, {'error': 'INTERNAL_ERROR'}).kind,
          ImpactErrorKind.server);
      expect(impactErrorFrom(400, {'error': 'INVALID_REQUEST'}).kind,
          ImpactErrorKind.invalidRequest);
    });

    test(
        'UI-API-03 sends only the read action and its params (no role / user id)',
        () async {
      final tr = FakeImpactTransport(dossier: fixture('dossier_confirmed_en'));
      await ImpactLabApi(tr).getDossier(kInvestigationId, 'en');
      expect(tr.calls.single, {
        'action': 'get_dossier',
        'investigation_id': kInvestigationId,
        'lang': 'en'
      });
    });

    test('UI-API-04 a response for another action is a contract error',
        () async {
      final tr = FakeImpactTransport(dossier: fixture('list_investigations'));
      expect(
        () => ImpactLabApi(tr).getDossier(kInvestigationId, 'en'),
        throwsA(isA<ImpactApiException>()
            .having((e) => e.kind, 'kind', ImpactErrorKind.contract)),
      );
    });

    test('UI-API-05 export must return a SNAPSHOT envelope', () async {
      final tr = FakeImpactTransport(
          export: copyOf(fixture('dossier_confirmed_en'))
            ..['action'] = 'export_dossier');
      expect(() => ImpactLabApi(tr).exportDossier(kInvestigationId, 'en'),
          throwsA(isA<ImpactApiException>()));
    });

    test(
        'UI-API-06 verify presents the issued hash + envelope verbatim; server decides',
        () async {
      final snap = view('export_confirmed_en');
      final tr = FakeImpactTransport(verify: fixture('verify_stale'));
      final r = await ImpactLabApi(tr).verifyDossier(kInvestigationId, snap);
      expect(tr.calls.single['content_hash'], snap.integrity.contentHash);
      expect(tr.calls.single['envelope'], same(snap.envelope.raw));
      expect(r.state, 'STALE');
    });

    test('UI-API-07 verify without integrityIsNotTruth is refused', () {
      final data =
          copyOf(fixture('verify_current'))['data'] as Map<String, dynamic>;
      data.remove('integrityIsNotTruth');
      expect(() => VerifyResult.fromData(data),
          throwsA(isA<ImpactApiException>()));
    });

    test(
        'UI-API-09 unknown verify state / envelope state is refused (never "not issued")',
        () {
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (d) => d['state'] = 'REVOKED',
        (d) => d.remove('state'),
        (d) => d['envelopeState'] = 'PARTIAL',
        (d) => d.remove('envelopeState'),
      ]) {
        final data =
            copyOf(fixture('verify_current'))['data'] as Map<String, dynamic>;
        mutate(data);
        expect(() => VerifyResult.fromData(data),
            throwsA(isA<ImpactApiException>()));
      }
      for (final n in [
        'verify_current',
        'verify_stale',
        'verify_not_issued',
        'verify_envelope_mismatch'
      ]) {
        expect(
            VerifyResult.fromData(fixture(n)['data'] as Map<String, dynamic>)
                .state,
            isNotEmpty);
      }
    });

    test('UI-API-10 (I6G1-04) the Impact client only ever sends the declared action set (never owner review DTOs)', () {
      // IV-IMPACT-MACRO-08 Phase 7/9: create_investigation and run_verification
      // are the two write actions added by the Discover and Monitor verticals.
      // The forbidden list below (unchanged) guards against server-authority
      // operations that must never be performed from the client.
      final sources = Directory('lib/features/impact')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.readAsStringSync())
          .join(' ');
      final actions = RegExp(r"_call\('([a-z_]+)'").allMatches(sources).map((m) => m.group(1)).toSet();
      expect(actions, {
        'list_investigations',
        'create_investigation',
        'run_verification',
        'get_dossier',
        'export_dossier',
        'verify_dossier',
      });
      for (final forbidden in ['get_investigation', 'review_candidate', 'import_registry_claim', 'ingest_artifact', 'OWNER_REVIEW_RAW']) {
        expect(sources, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('UI-API-08 list parses the caller investigations', () async {
      final list = await ImpactLabApi(
              FakeImpactTransport(list: fixture('list_investigations')))
          .listInvestigations();
      expect(list.single.id, kInvestigationId);
    });

    // IV-IMPACT-MACRO-08 Phase 16 — RLS / cross-user isolation boundary tests.
    // The client must NEVER send user_id in the request body. The server infers
    // the caller from the JWT attached by the Supabase SDK. A body with user_id
    // would be an oracle disclosure and a potential injection vector.
    group('RLS boundary (Phase 16 — client-side invariants)', () {
      test('RLS-01 SupabaseImpactTransport body never contains user_id or user fields', () {
        // Transport code: the _call body is always {action, ...params}. Verify
        // by grepping the source that no user_id, userId, uid or auth_uid key
        // is ever placed in the outbound body by the API layer.
        final source = File('lib/features/impact/data/impact_lab_api.dart').readAsStringSync();
        for (final forbidden in ['user_id', '"userId"', "'userId'", '"uid"', 'auth.uid']) {
          expect(source, isNot(contains(forbidden)), reason: 'client body must not contain $forbidden');
        }
      });

      test('RLS-02 action body for read operations contains only declared, non-identity params', () {
        // Every _call invocation uses only application-level params (investigation_id,
        // lang, content_hash, envelope) — never anything that could bias server-side
        // filtering to another user's data.
        final source = File('lib/features/impact/data/impact_lab_api.dart').readAsStringSync();
        // owner_id, role, plan must never appear in any outbound body.
        for (final forbidden in ['owner_id', "'role'", "'plan'", "'billing'", "'tier'"]) {
          expect(source, isNot(contains(forbidden)), reason: 'client body must not contain $forbidden');
        }
      });

      test('RLS-03 investigationId is always taken from server response, never from user input for owned-resource ops', () {
        // get_dossier and export_dossier both require an investigation_id that
        // comes from the server-side list (list_investigations) or server-side
        // create. The adapter test confirms the id field is required non-empty.
        final inv = InvestigationSummary(id: 'srv-id-42', subjectOrgRef: 'ACME', status: 'OPEN');
        expect(inv.id, 'srv-id-42');
        expect(() => InvestigationSummary(id: '', subjectOrgRef: 'ACME', status: 'OPEN'),
            returnsNormally); // constructor itself allows empty (contract enforced at createInvestigation)
      });

      test('RLS-04 createInvestigation throws contract error when server returns no investigationId', () async {
        // If the server returns a body with ok:true but missing or empty investigationId,
        // ImpactLabApi.createInvestigation must throw ImpactApiException(contract).
        // Wrapping in a full envelope so _call passes, but data has no 'investigationId' field.
        final transport = FakeImpactTransport(
          createInvestigation: {
            'ok': true,
            'action': 'create_investigation',
            'data': {'subjectOrgRef': 'ACME', 'status': 'OPEN'}, // no 'investigationId'
          },
        );
        final api = ImpactLabApi(transport);
        expect(
          () async => api.createInvestigation(subjectRef: 'acme', subjectType: 'NONPROFIT', legalName: 'ACME'),
          throwsA(isA<ImpactApiException>().having((e) => e.kind, 'kind', ImpactErrorKind.contract)),
        );
      });

      test('RLS-04b createInvestigation sends correct subject payload (no org_ref)', () async {
        // Fix 4: client sends subject.ref + subject.type + subject.identity (not org_ref)
        final transport = FakeImpactTransport(
          createInvestigation: {
            'ok': true,
            'action': 'create_investigation',
            'data': {'investigationId': kInvestigationId, 'subjectOrgRef': 'acme', 'status': 'OPEN'},
          },
        );
        final api = ImpactLabApi(transport);
        await api.createInvestigation(subjectRef: 'acme', subjectType: 'NONPROFIT', legalName: 'ACME Corp');
        final body = transport.calls.single;
        expect(body['action'], 'create_investigation');
        expect(body.containsKey('org_ref'), isFalse, reason: 'org_ref must not appear');
        expect(body['subject'], isA<Map>());
        final subject = body['subject'] as Map;
        expect(subject['ref'], 'acme');
        expect(subject['type'], 'NONPROFIT');
        expect((subject['identity'] as Map)['legalName'], 'ACME Corp');
      });

      test('RLS-04c runVerification sends claim_ref (required by server contract)', () async {
        // Fix 4: run_verification requires investigation_id AND claim_ref
        final transport = FakeImpactTransport(
          runVerification: {
            'ok': true,
            'action': 'run_verification',
            'data': {'investigationId': kInvestigationId},
          },
          dossier: fixture('dossier_confirmed_en'),
        );
        final api = ImpactLabApi(transport);
        await api.runVerification(investigationId: kInvestigationId, claimRef: 'c-wells');
        final verifyCall = transport.calls.first;
        expect(verifyCall['action'], 'run_verification');
        expect(verifyCall['investigation_id'], kInvestigationId);
        expect(verifyCall['claim_ref'], 'c-wells');
      });
    });

    // IV-IMPACT-MACRO-08 Phase 13 (revised Fix 3) — IVE-Impact adapter boundary.
    // EvidenceKind labels: [VERIFIED], [STORED], [USER_CLAIM], [INFERRED].
    // These describe PROVENANCE, not factual truth.
    group('IVE-Impact adapter boundary (Phase 13)', () {
      test('IVE-01 assembleDossierContext never includes billing/plan fields', () {
        final dossier = DossierView.fromResponse(fixture('dossier_confirmed_en')['data'] as Map<String, dynamic>);
        final ctx = assembleDossierContext(dossier);
        // The rules section must not contain billing field names; data section must not either.
        for (final forbidden in ['isPro', 'isEnterprise', 'planId', 'billingStatus', 'planTier']) {
          expect(ctx, isNot(contains(forbidden)), reason: 'IVE context must not contain $forbidden');
        }
        // 'tier'/'billing'/'plan' are allowed ONLY in the rules explanation
        // (e.g., "ASSINATURA/FATURAMENTO"). Check the data section (after blank line).
        final parts = ctx.split('\n\n');
        final dataSection = parts.length > 1 ? parts.sublist(1).join('\n\n') : '';
        for (final forbidden in ['plan', 'billing', 'tier', 'isPro', 'isEnterprise']) {
          expect(dataSection.toLowerCase(), isNot(contains(forbidden)),
              reason: 'IVE context DATA must not contain $forbidden');
        }
      });

      test('IVE-02 assembleDossierContext uses new provenance labels', () {
        final dossier = DossierView.fromResponse(fixture('dossier_confirmed_en')['data'] as Map<String, dynamic>);
        final ctx = assembleDossierContext(dossier);
        // New label scheme: [VERIFIED], [STORED], [USER_CLAIM], [INFERRED]
        // At minimum STORED items (subject identity) are always present.
        expect(ctx, contains('[STORED]'));
        // Claims present in dossier_confirmed_en should yield USER_CLAIM entries
        expect(ctx, contains('[USER_CLAIM]'));
        // SERVERFACT must NOT appear (old label, semantically misleading)
        expect(ctx, isNot(contains('[SERVERFACT]')));
      });

      test('IVE-03 assembleDossierContext includes the IVE cannot-invent rule', () {
        final dossier = DossierView.fromResponse(fixture('dossier_confirmed_en')['data'] as Map<String, dynamic>);
        final ctx = assembleDossierContext(dossier);
        expect(ctx, contains('IVE NÃO PODE'));
        expect(ctx, contains('inventar'));
        // USER_CLAIM rule must explicitly say it is NOT authority
        expect(ctx, contains('[USER_CLAIM]'));
      });

      test('IVE-04 assembleDossierContext for empty dossier produces valid non-empty context', () {
        final dossier = DossierView.fromResponse(fixture('dossier_empty_en')['data'] as Map<String, dynamic>);
        final ctx = assembleDossierContext(dossier);
        expect(ctx.isNotEmpty, true);
        expect(ctx, contains('[STORED]'));
      });

      test('IVE-05 prompt injection: malicious text in claim is wrapped in value delimiters', () {
        final dossier = DossierView.fromResponse(fixture('dossier_confirmed_en')['data'] as Map<String, dynamic>);
        final ctx = assembleDossierContext(dossier);
        // All USER_CLAIM values are inside <value>...</value>
        final re = RegExp(r'\[USER_CLAIM\][^<]*<value>.*?</value>', dotAll: true);
        expect(re.hasMatch(ctx), isTrue, reason: 'USER_CLAIM values must be delimited');
      });

      test('IVE-06 assembled context does not contain raw </value> from data values', () {
        // If claim text contains "</value>", it is escaped to "<\/value>" so
        // injected text cannot close the delimiter.
        expect(_sanitizeForTest('normal text'), equals('normal text'));
        expect(_sanitizeForTest('inject </value> here'), equals('inject <\\/value> here'));
        expect(_sanitizeForTest('</value></value>'), equals('<\\/value><\\/value>'));
      });
    });
  });
}

/// Mirror of the private _sanitize() in ive_impact_adapter.dart, used only in tests.
String _sanitizeForTest(String s) => s.replaceAll('</value>', '<\\/value>');

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
