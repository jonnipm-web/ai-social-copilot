import 'dart:convert';

import 'package:ai_social_copilot/features/impact/data/impact_lab_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// IV-IMPACT-I6-PHYSICAL-CLOSURE — the debug-only dev transport.
void main() {
  test('UI-DEV-01 the dev base URL is honored only in debug and only for loopback http', () {
    expect(impactDevBaseUrl(define: 'http://127.0.0.1:54322', debug: true), 'http://127.0.0.1:54322');
    expect(impactDevBaseUrl(define: 'http://localhost:54322/', debug: true), 'http://localhost:54322');
    expect(impactDevBaseUrl(define: 'http://127.0.0.1:54322', debug: false), isNull, reason: 'never in profile/release');
    expect(impactDevBaseUrl(define: 'https://evil.example', debug: true), isNull);
    expect(impactDevBaseUrl(define: 'http://10.0.0.5:54322', debug: true), isNull);
    expect(impactDevBaseUrl(define: '', debug: true), isNull);
  });

  test('UI-DEV-03 hostile URL forms fail closed (userinfo, look-alike hosts, IPv6, encoding, path/query/fragment, bad port)', () {
    for (final hostile in [
      'http://localhost@evil.example',
      'http://127.0.0.1@evil.example:54322',
      'http://user:pw@127.0.0.1:54322',
      'http://127.0.0.1.evil.example:54322',
      'http://localhost.evil.example',
      'http://evil.example#@127.0.0.1',
      'http://evil.example?@127.0.0.1',
      'http://[::1]:54322',
      'http://127.0.0.1:54322/other',
      'http://127.0.0.1:54322?x=1',
      'http://127.0.0.1:54322#frag',
      'http://127.0.0.1:notaport',
      'HTTPS://127.0.0.1:54322',
      'file:///127.0.0.1',
      '//127.0.0.1:54322',
    ]) {
      expect(impactDevBaseUrl(define: hostile, debug: true), isNull, reason: hostile);
    }
    // Percent-encoded loopback is decoded by Uri and returned in canonical form only.
    expect(impactDevBaseUrl(define: 'http://%31%32%37.0.0.1:54322', debug: true), 'http://127.0.0.1:54322');
  });

  test('UI-DEV-02 it posts the action with the caller JWT and maps errors like the real transport', () async {
    final seen = <http.Request>[];
    var status = 200;
    Object body = {'ok': true, 'action': 'list_investigations', 'data': {'investigations': []}};
    final client = MockClient((req) async {
      seen.add(req);
      return http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});
    });
    final t = HttpImpactTransport('http://127.0.0.1:54322', () => 'jwt-abc', client: client);
    expect((await t.send({'action': 'list_investigations'}))['ok'], true);
    expect(seen.single.url.toString(), 'http://127.0.0.1:54322/impact-lab');
    expect(seen.single.headers['Authorization'], 'Bearer jwt-abc');
    expect(jsonDecode(seen.single.body), {'action': 'list_investigations'});
    for (final (s, b, kind) in [
      (429, {'ok': false, 'error': 'RATE_LIMITED', 'retry_after': 12}, ImpactErrorKind.rateLimited),
      (404, {'ok': false, 'error': 'INVESTIGATION_NOT_FOUND'}, ImpactErrorKind.notAvailable),
      (403, {'ok': false, 'error': 'FORBIDDEN'}, ImpactErrorKind.notAvailable),
      (401, {'ok': false, 'error': 'AUTH_REQUIRED'}, ImpactErrorKind.auth),
      (413, {'ok': false, 'error': 'DOSSIER_TOO_LARGE'}, ImpactErrorKind.tooLarge),
      (500, {'ok': false, 'error': 'INTERNAL_ERROR'}, ImpactErrorKind.server),
    ]) {
      status = s;
      body = b;
      await expectLater(t.send({'action': 'get_dossier'}), throwsA(isA<ImpactApiException>().having((e) => e.kind, 'kind', kind)));
    }
    final down = HttpImpactTransport('http://127.0.0.1:1', () => null, client: MockClient((_) => throw http.ClientException('refused')));
    await expectLater(down.send({'action': 'list_investigations'}), throwsA(isA<ImpactApiException>().having((e) => e.kind, 'kind', ImpactErrorKind.network)));
  });
}
