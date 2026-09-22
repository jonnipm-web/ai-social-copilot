import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/module_access.dart';
import '../data/services/entitlement_service.dart';

final entitlementServiceProvider = Provider<EntitlementService>((_) => EntitlementService());

/// MODULE-FOUNDATION-AND-ENTITLEMENT-02 — server-authorized capability set,
/// the contract IVE uses to discover what it may offer ("what modules are
/// available to me?") instead of inferring entitlement from the UI. A
/// failure (offline, not deployed, ENTITLEMENT_UNAVAILABLE) surfaces as an
/// AsyncError: callers must treat that as "nothing extra is available",
/// never as "everything is".
final serverModuleAccessProvider = FutureProvider.autoDispose<ServerModuleAccess>((ref) {
  return ref.watch(entitlementServiceProvider).fetchModuleAccess();
});
