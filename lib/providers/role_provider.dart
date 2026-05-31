import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/user_role.dart';
import '../data/services/role_service.dart';

final roleServiceProvider = Provider<RoleService>((ref) => RoleService());

final userPermissionProvider = FutureProvider<UserPermission>((ref) async {
  return ref.read(roleServiceProvider).getUserPermission();
});
