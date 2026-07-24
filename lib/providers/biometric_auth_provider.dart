import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/services/biometric_auth_service.dart';

final biometricAuthServiceProvider = Provider<BiometricAuthService>(
  (_) => BiometricAuthService(),
);

/// Whether the device has biometric hardware and enrolled biometrics.
final biometricAvailableProvider = FutureProvider<bool>((ref) {
  return ref.read(biometricAuthServiceProvider).isAvailable();
});

/// Whether biometric login is currently enabled for the authenticated user.
/// Returns false if no session exists.
final biometricEnabledProvider = FutureProvider<bool>((ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return false;
  return ref.read(biometricAuthServiceProvider).isEnabled(userId: uid);
});
