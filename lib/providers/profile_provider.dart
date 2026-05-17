import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/user_profile.dart';
import '../data/services/profile_service.dart';

final profileServiceProvider = Provider<ProfileService>((_) => ProfileService());

class ProfileNotifier extends StateNotifier<AsyncValue<UserProfile?>> {
  ProfileNotifier(this._service) : super(const AsyncValue.loading()) {
    _load();
  }

  final ProfileService _service;

  Future<void> _load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _service.fetchProfile());
  }

  Future<void> saveNiche(String niche) async {
    final saved = await _service.saveNiche(niche);
    state = AsyncValue.data(saved);
  }

  String get currentNiche =>
      state.valueOrNull?.niche ?? 'geral';
}

final profileProvider =
    StateNotifierProvider.autoDispose<ProfileNotifier, AsyncValue<UserProfile?>>(
  (ref) => ProfileNotifier(ref.watch(profileServiceProvider)),
);
