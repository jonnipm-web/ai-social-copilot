import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/dossier_models.dart';

/// IV-IMPACT-I5 — client for the admin-only `impact-lab` Edge Function.
///
/// The UI is a CONSUMER of the I4 dossier contract: it sends only the
/// read actions it needs (list / get / export / verify) and never computes
/// a status, a hash or a verdict itself. Authority stays on the server
/// (admin entitlement, ownership, RLS, rate limit).

/// What went wrong, reduced to what the UI may show. 403 and 404 are the
/// same kind on purpose: the server already makes "not yours" and "does not
/// exist" indistinguishable, and the UI must not re-introduce the oracle.
enum ImpactErrorKind {
  auth,
  notAvailable,
  tooLarge,
  rateLimited,
  network,
  server,
  invalidRequest,
  contract,
}

class ImpactApiException implements Exception {
  const ImpactApiException(this.kind, {this.code, this.retryAfterSeconds});

  final ImpactErrorKind kind;

  /// Stable server error code when there is one (never a message body).
  final String? code;

  /// Only for [ImpactErrorKind.rateLimited]: the server's `retry_after`.
  final int? retryAfterSeconds;

  @override
  String toString() => 'ImpactApiException($kind, $code)';
}

/// Maps an HTTP status + the impact-lab error body to an [ImpactApiException].
/// Pure, so it is unit-tested without any network.
ImpactApiException impactErrorFrom(int status, Object? body) {
  final map = body is Map ? body : const {};
  final code = map['error'] is String ? map['error'] as String : null;
  final retry = map['retry_after'];
  if (status == 401) return ImpactApiException(ImpactErrorKind.auth, code: code);
  if (status == 403 || status == 404) return ImpactApiException(ImpactErrorKind.notAvailable, code: code);
  if (status == 413 || code == 'DOSSIER_TOO_LARGE') return ImpactApiException(ImpactErrorKind.tooLarge, code: code);
  if (status == 429) {
    return ImpactApiException(
      ImpactErrorKind.rateLimited,
      code: code,
      retryAfterSeconds: retry is int && retry > 0 ? retry : 60,
    );
  }
  if (status >= 500) return ImpactApiException(ImpactErrorKind.server, code: code);
  return ImpactApiException(ImpactErrorKind.invalidRequest, code: code);
}

/// One request/response to impact-lab. Implementations throw
/// [ImpactApiException] for every non-success outcome.
abstract class ImpactTransport {
  Future<Map<String, dynamic>> send(Map<String, dynamic> body);
}

class SupabaseImpactTransport implements ImpactTransport {
  SupabaseImpactTransport(this._client);

  final SupabaseClient _client;
  static const _function = 'impact-lab';

  @override
  Future<Map<String, dynamic>> send(Map<String, dynamic> body) async {
    final FunctionResponse response;
    try {
      // The caller's session token is attached by the SDK; no key, role or
      // user id is ever sent in the body.
      response = await _client.functions.invoke(_function, body: body);
    } on FunctionException catch (e) {
      throw impactErrorFrom(e.status, e.details);
    } catch (_) {
      throw const ImpactApiException(ImpactErrorKind.network);
    }
    final data = response.data;
    if (data is! Map<String, dynamic>) throw const ImpactApiException(ImpactErrorKind.contract);
    return data;
  }
}

class ImpactLabApi {
  ImpactLabApi(this._transport);

  final ImpactTransport _transport;

  Future<Map<String, dynamic>> _call(String action, Map<String, dynamic> params) async {
    final res = await _transport.send({'action': action, ...params});
    if (res['ok'] != true) throw impactErrorFrom(400, res);
    if (res['action'] != action || res['data'] is! Map<String, dynamic>) {
      throw const ImpactApiException(ImpactErrorKind.contract);
    }
    return res['data'] as Map<String, dynamic>;
  }

  Future<List<InvestigationSummary>> listInvestigations() async {
    final data = await _call('list_investigations', const {});
    return parseInvestigations(data);
  }

  Future<DossierView> getDossier(String investigationId, String lang) async {
    final data = await _call('get_dossier', {'investigation_id': investigationId, 'lang': lang});
    return DossierView.fromResponse(data);
  }

  Future<DossierView> exportDossier(String investigationId, String lang) async {
    final data = await _call('export_dossier', {'investigation_id': investigationId, 'lang': lang});
    final view = DossierView.fromResponse(data);
    if (!view.envelope.isSnapshot) throw const ImpactApiException(ImpactErrorKind.contract);
    return view;
  }

  /// Presents an issued snapshot back to the server. The server — not the
  /// UI — decides CURRENT / STALE / NOT_ISSUED and the envelope match.
  Future<VerifyResult> verifyDossier(String investigationId, DossierView snapshot) async {
    final data = await _call('verify_dossier', {
      'investigation_id': investigationId,
      'content_hash': snapshot.integrity.contentHash,
      'envelope': snapshot.envelope.raw,
    });
    return VerifyResult.fromData(data);
  }
}
