import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/profile.dart';
import '../data/services/profile_service.dart';

final profileServiceProvider = Provider<ProfileService>((_) => ProfileService());

// Perfil do usuário logado
final currentProfileProvider = FutureProvider.autoDispose<Profile?>((ref) {
  return ref.watch(profileServiceProvider).fetchCurrentProfile();
});

// Todos os perfis (admin only)
final allProfilesProvider = FutureProvider.autoDispose<List<Profile>>((ref) {
  return ref.watch(profileServiceProvider).fetchAllProfiles();
});

// Notifier para operações de admin sobre usuários
class ProfileAdminNotifier extends StateNotifier<AsyncValue<void>> {
  ProfileAdminNotifier(this._service) : super(const AsyncValue.data(null));

  final ProfileService _service;

  Future<void> updateRole(String userId, String role) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _service.updateRole(userId, role));
  }

  Future<void> setActive(String userId, bool isActive) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _service.setActive(userId, isActive));
  }
}

final profileAdminNotifierProvider =
    StateNotifierProvider.autoDispose<ProfileAdminNotifier, AsyncValue<void>>(
        (ref) => ProfileAdminNotifier(ref.watch(profileServiceProvider)));
