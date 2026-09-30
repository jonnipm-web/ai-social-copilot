// IV-QUANT-DATA-PLANE-AND-API-02 / REAL-DATA-READINESS-03 — Quant Lab transport.
//
// Calls the server-side `quant-analyze` and `quant-watchlists` Edge Functions
// (JWT attached from the current session). The server is the only authority
// for access (entitlements), ownership and every computed number.
//
// Physical-device validation (READINESS-03): a DEBUG build may point the Lab
// at a local Quant dev server with `--dart-define=QUANT_API_BASE_URL=...`
// (reached over `adb reverse`). The override is ignored in profile/release
// builds, so a shipped app can never be redirected by a build flag.
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'quant_lab_models.dart';

/// Same cap the server applies to the CSV itself (5 MiB).
const kQuantLabMaxCsvBytes = 5 * 1024 * 1024;

const _kDevBaseUrlDefine = String.fromEnvironment('QUANT_API_BASE_URL');

/// The dev base URL, honored ONLY in debug builds and only for loopback
/// hosts (the device reaches the PC through `adb reverse`). Exposed for tests.
String? quantDevBaseUrl({String define = _kDevBaseUrlDefine, bool debug = kDebugMode}) {
  if (!debug || define.isEmpty) return null;
  final uri = Uri.tryParse(define);
  if (uri == null || uri.scheme != 'http' || !(uri.host == '127.0.0.1' || uri.host == 'localhost')) return null;
  return define.endsWith('/') ? define.substring(0, define.length - 1) : define;
}

/// Raw transport result: HTTP status + decoded body (Map / String / null).
class QuantHttpResult {
  const QuantHttpResult(this.status, this.data);
  final int status;
  final dynamic data;
}

abstract class QuantLabApi {
  Future<QuantAnalyzeOutcome> analyze(QuantAnalyzeInput input);

  /// quant.analyze.watchlist.v1 over the server-side synthetic provider.
  Future<QuantMultiOutcome> analyzeWatchlist(String watchlistId, List<String> itemIds);

  Future<QuantWatchlistsOutcome> listWatchlists();
  Future<QuantActionOutcome> watchlistAction(Map<String, dynamic> action);

  /// Picks a local file and returns its text, or null if cancelled.
  /// Throws [QuantLabFileException] for oversize/unsupported/unreadable files.
  Future<String?> pickCsv();
}

class QuantLabFileException implements Exception {
  const QuantLabFileException(this.code);

  /// FILE_TOO_LARGE | FILE_UNREADABLE | FILE_TYPE_NOT_SUPPORTED | FILE_TYPE_NOT_IMPLEMENTED
  final String code;
}

/// File-type policy (docs/quant/QUANT_REAL_DATA_READINESS.md §6):
///   SUPPORTED         .csv, .txt holding CSV text (UTF-8)
///   NOT_IMPLEMENTED   .json, .xls, .xlsx, .ods (spreadsheet/JSON import is a future mission)
///   REJECTED          .pdf, images, anything binary or unknown
/// Decided on BOTH the name and the leading bytes, so a renamed binary is
/// still refused. Returns the decoded text. Exposed for tests.
String decodeQuantFile(String? name, Uint8List bytes) {
  if (bytes.length > kQuantLabMaxCsvBytes) throw const QuantLabFileException('FILE_TOO_LARGE');
  final lower = (name ?? '').toLowerCase();
  final ext = lower.contains('.') ? lower.substring(lower.lastIndexOf('.') + 1) : '';
  bool startsWith(List<int> sig) => bytes.length >= sig.length && Iterable<int>.generate(sig.length).every((i) => bytes[i] == sig[i]);
  final isZip = startsWith(const [0x50, 0x4B, 0x03, 0x04]); // xlsx / ods / docx / zip
  final isOle = startsWith(const [0xD0, 0xCF, 0x11, 0xE0]); // legacy .xls / .doc
  // A name we can place (csv/txt/none or a spreadsheet/JSON name) lets the
  // container bytes suggest "spreadsheet"; any OTHER explicit extension
  // (.docx, .pptx, .zip…) is simply unsupported — a ZIP is not a spreadsheet
  // (physical finding S25: .docx was reported as a spreadsheet).
  const spreadsheetOrJson = ['xls', 'xlsx', 'ods', 'json'];
  final nameAllowsContainer = spreadsheetOrJson.contains(ext) || ext == 'csv' || ext == 'txt' || ext.isEmpty;
  if (spreadsheetOrJson.contains(ext) || (nameAllowsContainer && (isZip || isOle))) {
    throw const QuantLabFileException('FILE_TYPE_NOT_IMPLEMENTED');
  }
  final isPdf = startsWith(const [0x25, 0x50, 0x44, 0x46]);
  final isPng = startsWith(const [0x89, 0x50, 0x4E, 0x47]);
  final isJpeg = startsWith(const [0xFF, 0xD8, 0xFF]);
  final isGif = startsWith(const [0x47, 0x49, 0x46, 0x38]);
  final isWebp = bytes.length >= 12 && startsWith(const [0x52, 0x49, 0x46, 0x46]) && bytes[8] == 0x57 && bytes[9] == 0x45;
  if (isPdf || isPng || isJpeg || isGif || isWebp || !(ext == 'csv' || ext == 'txt' || ext.isEmpty)) {
    throw const QuantLabFileException('FILE_TYPE_NOT_SUPPORTED');
  }
  if (bytes.contains(0)) throw const QuantLabFileException('FILE_TYPE_NOT_SUPPORTED');
  final String text;
  try {
    text = utf8.decode(bytes);
  } on FormatException {
    throw const QuantLabFileException('FILE_UNREADABLE');
  }
  final trimmed = text.trimLeft().replaceFirst('\uFEFF', '');
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) throw const QuantLabFileException('FILE_TYPE_NOT_IMPLEMENTED');
  return text;
}

/// Reads at most [cap] bytes: rejects on declared length first, then stops
/// the stream as soon as the running total exceeds [cap]. Exposed for tests.
Future<Uint8List> readBoundedBytes(Future<int?> Function() length, Stream<Uint8List> Function() open, int cap) async {
  int? declared;
  try {
    declared = await length();
  } catch (_) {
    declared = null; // unknown size: the bounded stream below still enforces the cap
  }
  if (declared != null && declared > cap) throw const QuantLabFileException('FILE_TOO_LARGE');
  final out = BytesBuilder(copy: false);
  try {
    await for (final chunk in open()) {
      out.add(chunk);
      if (out.length > cap) throw const QuantLabFileException('FILE_TOO_LARGE');
    }
  } on QuantLabFileException {
    rethrow;
  } catch (_) {
    throw const QuantLabFileException('FILE_UNREADABLE');
  }
  return out.takeBytes();
}

class SupabaseQuantLabApi implements QuantLabApi {
  SupabaseQuantLabApi(this._client, {String? devBaseUrl, http.Client? httpClient})
      : _devBaseUrl = devBaseUrl,
        _http = httpClient;
  final SupabaseClient _client;
  final String? _devBaseUrl;
  final http.Client? _http;

  Future<QuantHttpResult> _post(String fn, Map<String, dynamic> body) async {
    final dev = _devBaseUrl;
    if (dev != null) {
      final token = _client.auth.currentSession?.accessToken;
      final headers = {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
      final client = _http ?? http.Client();
      try {
        final res = await client.post(Uri.parse('$dev/$fn'), headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 30));
        dynamic data;
        try {
          data = jsonDecode(utf8.decode(res.bodyBytes));
        } on FormatException {
          data = null;
        }
        return QuantHttpResult(res.statusCode, data);
      } finally {
        if (_http == null) client.close();
      }
    }
    try {
      final res = await _client.functions.invoke(fn, body: body);
      return QuantHttpResult(res.status, res.data);
    } on FunctionException catch (e) {
      return QuantHttpResult(e.status, e.details);
    }
  }

  @override
  Future<QuantAnalyzeOutcome> analyze(QuantAnalyzeInput input) async {
    try {
      final r = await _post('quant-analyze', input.toRequestBody());
      return outcomeFromResponse(r.status, r.data);
    } catch (_) {
      return const QuantAnalyzeOutcome.failure('NETWORK_ERROR');
    }
  }

  @override
  Future<QuantMultiOutcome> analyzeWatchlist(String watchlistId, List<String> itemIds) async {
    try {
      final r = await _post('quant-analyze', watchlistAnalysisBody(watchlistId, itemIds));
      return multiOutcomeFromResponse(r.status, r.data);
    } catch (_) {
      return const QuantMultiOutcome.failure('NETWORK_ERROR');
    }
  }

  @override
  Future<QuantWatchlistsOutcome> listWatchlists() async {
    try {
      final r = await _post('quant-watchlists', {'contract_version': kWatchlistsContract, 'action': 'list'});
      return watchlistsOutcomeFromResponse(r.status, r.data);
    } catch (_) {
      return const QuantWatchlistsOutcome.failure('NETWORK_ERROR');
    }
  }

  @override
  Future<QuantActionOutcome> watchlistAction(Map<String, dynamic> action) async {
    try {
      final r = await _post('quant-watchlists', {'contract_version': kWatchlistsContract, ...action});
      return actionOutcomeFromResponse(r.status, r.data);
    } catch (_) {
      return const QuantActionOutcome('NETWORK_ERROR');
    }
  }

  @override
  Future<String?> pickCsv() async {
    // FileType.any: Android SAF providers (Downloads, Drive, OneDrive…) report
    // inconsistent MIME types for CSV, which makes an extension filter hide
    // valid files. The type decision is made on name + content instead.
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file == null) return null;
    // Codex Gate 3 (P1): never allocate a whole huge file — size is checked
    // from metadata first and the stream is cut as soon as the cap is passed.
    final bytes = await readBoundedBytes(file.length, file.readAsByteStream, kQuantLabMaxCsvBytes);
    return decodeQuantFile(file.name, bytes);
  }
}

Map<String, dynamic>? _bodyMap(dynamic data) {
  if (data is Map) return Map<String, dynamic>.from(data);
  if (data is String) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      return null;
    }
  }
  return null;
}

({String code, String? field}) _errorOf(int status, Map<String, dynamic>? body) {
  final code = body?['error'];
  final details = body?['details'];
  return (
    code: code is String ? code : 'HTTP_$status',
    field: details is Map ? (details['field'] as String? ?? details['reason'] as String?) : null,
  );
}

/// Maps an HTTP status + body to an outcome. Exposed for tests.
QuantAnalyzeOutcome outcomeFromResponse(int status, dynamic data) {
  final body = _bodyMap(data);
  if (status == 200 && body != null && body['analysis'] is Map) {
    try {
      return QuantAnalyzeOutcome.success(QuantAnalysisView.fromJson(Map<String, dynamic>.from(body['analysis'] as Map)));
    } on FormatException {
      return const QuantAnalyzeOutcome.failure('MALFORMED_RESPONSE');
    }
  }
  final e = _errorOf(status, body);
  return QuantAnalyzeOutcome.failure(e.code, errorField: e.field);
}

QuantMultiOutcome multiOutcomeFromResponse(int status, dynamic data) {
  final body = _bodyMap(data);
  if (status == 200 && body != null && body['multi_analysis'] is Map) {
    try {
      return QuantMultiOutcome.success(QuantMultiView.fromJson(Map<String, dynamic>.from(body['multi_analysis'] as Map)));
    } on FormatException {
      return const QuantMultiOutcome.failure('MALFORMED_RESPONSE');
    }
  }
  final e = _errorOf(status, body);
  return QuantMultiOutcome.failure(e.code, errorField: e.field);
}

QuantWatchlistsOutcome watchlistsOutcomeFromResponse(int status, dynamic data) {
  final body = _bodyMap(data);
  if (status == 200 && body != null && body['watchlists'] is List) {
    try {
      return QuantWatchlistsOutcome.success([
        for (final w in body['watchlists'] as List) QuantWatchlistView.fromJson(Map<String, dynamic>.from(w as Map)),
      ]);
    } catch (_) {
      return const QuantWatchlistsOutcome.failure('MALFORMED_RESPONSE');
    }
  }
  return QuantWatchlistsOutcome.failure(_errorOf(status, body).code);
}

QuantActionOutcome actionOutcomeFromResponse(int status, dynamic data) {
  if (status == 200) return const QuantActionOutcome(null);
  final e = _errorOf(status, _bodyMap(data));
  return QuantActionOutcome(e.code, reason: e.field);
}

final quantLabApiProvider = Provider<QuantLabApi>((ref) => SupabaseQuantLabApi(Supabase.instance.client, devBaseUrl: quantDevBaseUrl()));
