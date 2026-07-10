import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/advisor_profile.dart';
import '../data/services/advisor_service.dart';

final advisorServiceProvider =
    Provider<AdvisorService>((_) => AdvisorService());

final advisorProfileProvider =
    FutureProvider.autoDispose<AdvisorProfile?>((ref) {
  return ref.read(advisorServiceProvider).fetchProfile();
});

final advisorSetupProvider =
    FutureProvider.autoDispose<bool>((ref) {
  return ref.read(advisorServiceProvider).hasProfile();
});

class AdvisorNotifier extends StateNotifier<AsyncValue<AdvisorProfile?>> {
  AdvisorNotifier(this._svc) : super(const AsyncValue.loading()) {
    load();
  }

  final AdvisorService _svc;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final profile = await _svc.fetchProfile();
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> save({
    required String advisorName,
    required String advisorRole,
    required String advisorStyle,
    String advisorAvatar = '',
  }) async {
    state = const AsyncValue.loading();
    try {
      final profile = await _svc.saveProfile(
        advisorName:  advisorName,
        advisorRole:  advisorRole,
        advisorStyle: advisorStyle,
        advisorAvatar: advisorAvatar,
      );
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final advisorNotifierProvider =
    StateNotifierProvider.autoDispose<AdvisorNotifier, AsyncValue<AdvisorProfile?>>(
  (ref) => AdvisorNotifier(ref.read(advisorServiceProvider)),
);
