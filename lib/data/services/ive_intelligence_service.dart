import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../models/ive_intelligence.dart';

/// IVE-INTELLIGENCE-CORE-01 — the single client entry point to the server
/// IVE Intelligence Core, shared by Android and Web. It sends only the
/// allowed request fields and maps every failure to a stable [IveFailure]
/// (the UI translates it; no raw error text reaches the user).
class IveIntelligenceService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<IveIntelligenceResult> ask(IveIntelligenceRequest request) async {
    dynamic data;
    try {
      final res = await _client.functions.invoke(AppConstants.edgeFunctionIveIntelligence, body: request.toJson());
      data = res.data;
    } on FunctionException catch (e) {
      final details = e.details;
      throw IveIntelligenceException(IveFailure.fromCode(details is Map ? details['error'] : null));
    } catch (_) {
      throw const IveIntelligenceException(IveFailure.unknown);
    }
    if (data is Map && data['error'] != null) {
      throw IveIntelligenceException(IveFailure.fromCode(data['error']));
    }
    if (data is! Map<String, dynamic>) throw const IveIntelligenceException(IveFailure.unknown);
    try {
      return IveIntelligenceResult.fromMap(data);
    } on FormatException {
      throw const IveIntelligenceException(IveFailure.unknown);
    }
  }
}
