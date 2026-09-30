import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../models/module_access.dart';

/// MODULE-FOUNDATION-AND-ENTITLEMENT-02 — reads the server's capability set
/// for the signed-in user (Edge Function `module-access`). Read-only and
/// informational: it grants nothing (see [ServerModuleAccess]). Denials
/// come back as the shared entitlement error codes, rethrown like every
/// other service so core/utils/snackbar_utils.dart can translate them.
class EntitlementService {
  final _client = Supabase.instance.client;

  Future<ServerModuleAccess> fetchModuleAccess() async {
    final res = await _client.functions.invoke(AppConstants.edgeFunctionModuleAccess);
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error']);
    }
    if (data is! Map<String, dynamic>) {
      throw const FormatException('module-access: unexpected response');
    }
    return ServerModuleAccess.fromMap(data);
  }
}
