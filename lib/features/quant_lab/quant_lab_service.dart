// IV-QUANT-DATA-PLANE-AND-API-02 — Quant Lab transport.
//
// Calls the server-side `quant-analyze` Edge Function (JWT attached by the
// Supabase SDK). The server is the only authority for access (quant-analytics
// entitlement), ownership and every computed number.
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'quant_lab_models.dart';

/// Same cap the server applies to the CSV itself (5 MiB).
const kQuantLabMaxCsvBytes = 5 * 1024 * 1024;

abstract class QuantLabApi {
  Future<QuantAnalyzeOutcome> analyze(QuantAnalyzeInput input);

  /// Picks a local .csv and returns its text, or null if cancelled.
  /// Throws [QuantLabFileException] for oversize/unreadable files.
  Future<String?> pickCsv();
}

class QuantLabFileException implements Exception {
  const QuantLabFileException(this.code);
  final String code; // FILE_TOO_LARGE | FILE_UNREADABLE
}

class SupabaseQuantLabApi implements QuantLabApi {
  SupabaseQuantLabApi(this._client);
  final SupabaseClient _client;

  @override
  Future<QuantAnalyzeOutcome> analyze(QuantAnalyzeInput input) async {
    try {
      final res = await _client.functions.invoke('quant-analyze', body: input.toRequestBody());
      return outcomeFromResponse(res.status, res.data);
    } on FunctionException catch (e) {
      return outcomeFromResponse(e.status, e.details);
    } catch (_) {
      return const QuantAnalyzeOutcome.failure('NETWORK_ERROR');
    }
  }

  @override
  Future<String?> pickCsv() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['csv']);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length > kQuantLabMaxCsvBytes) throw const QuantLabFileException('FILE_TOO_LARGE');
    try {
      return utf8.decode(bytes);
    } on FormatException {
      throw const QuantLabFileException('FILE_UNREADABLE');
    }
  }
}

/// Maps an HTTP status + body to an outcome. Exposed for tests.
QuantAnalyzeOutcome outcomeFromResponse(int status, dynamic data) {
  Map<String, dynamic>? body;
  if (data is Map) body = Map<String, dynamic>.from(data);
  if (data is String) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) body = Map<String, dynamic>.from(decoded);
    } on FormatException {
      body = null;
    }
  }
  if (status == 200 && body != null && body['analysis'] is Map) {
    try {
      return QuantAnalyzeOutcome.success(QuantAnalysisView.fromJson(Map<String, dynamic>.from(body['analysis'] as Map)));
    } on FormatException {
      return const QuantAnalyzeOutcome.failure('MALFORMED_RESPONSE');
    }
  }
  final code = body?['error'];
  final details = body?['details'];
  return QuantAnalyzeOutcome.failure(
    code is String ? code : 'HTTP_$status',
    errorField: details is Map ? details['field'] as String? : null,
  );
}

final quantLabApiProvider = Provider<QuantLabApi>((ref) => SupabaseQuantLabApi(Supabase.instance.client));
