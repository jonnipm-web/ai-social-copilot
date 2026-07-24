import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';

enum BiometricStatus {
  success,
  failed,
  lockout,
  lockoutPermanent,
  noHardware,
  hwUnavailable,
  noneEnrolled,
  userCancel,
  sessionExpired,
  notSupported,
}

class BiometricAuthService {
  static const _keyEnabled       = 'biometric_enabled';
  static const _keyUserId        = 'biometric_user_id';
  static const _keyEnrolledCount = 'biometric_enrolled_count';

  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// True if device has biometric hardware AND enrolled biometrics.
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      if (!await _auth.isDeviceSupported()) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// True if user has opted in to biometric login for [userId].
  Future<bool> isEnabled({required String userId}) async {
    if (kIsWeb) return false;
    try {
      final enabled = await _storage.read(key: _keyEnabled);
      if (enabled != 'true') return false;
      final storedUid = await _storage.read(key: _keyUserId);
      return storedUid == userId;
    } catch (_) {
      return false;
    }
  }

  /// Show biometric prompt. Returns the outcome.
  /// Disables biometric automatically if enrolled biometrics have changed.
  Future<BiometricStatus> authenticate({
    required String localizedReason,
    required String userId,
  }) async {
    if (kIsWeb) return BiometricStatus.notSupported;

    // Invalidate if biometry enrollment changed since we stored the count.
    if (await _hasBiometryChanged()) {
      await disable(userId: userId);
      return BiometricStatus.noneEnrolled;
    }

    try {
      final ok = await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      return ok ? BiometricStatus.success : BiometricStatus.userCancel;
    } on PlatformException catch (e) {
      return _map(e);
    }
  }

  /// Enable biometric login: runs a biometric challenge first to confirm.
  /// Stores enrollment state on success.
  Future<BiometricStatus> enable({
    required String localizedReason,
    required String userId,
  }) async {
    if (kIsWeb) return BiometricStatus.notSupported;
    try {
      final ok = await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!ok) return BiometricStatus.userCancel;

      final enrolled = await _auth.getAvailableBiometrics();
      await _storage.write(key: _keyEnabled, value: 'true');
      await _storage.write(key: _keyUserId, value: userId);
      await _storage.write(key: _keyEnrolledCount, value: '${enrolled.length}');
      return BiometricStatus.success;
    } on PlatformException catch (e) {
      return _map(e);
    }
  }

  /// Disable biometric login — called on logout or user toggle.
  Future<void> disable({String? userId}) async {
    try {
      await _storage.delete(key: _keyEnabled);
      await _storage.delete(key: _keyUserId);
      await _storage.delete(key: _keyEnrolledCount);
    } catch (_) {}
  }

  // Returns true if the number of enrolled biometrics has changed since
  // biometric login was enabled (e.g. new fingerprint or face was added).
  Future<bool> _hasBiometryChanged() async {
    try {
      final storedStr = await _storage.read(key: _keyEnrolledCount);
      if (storedStr == null) return false;
      final stored = int.tryParse(storedStr) ?? 0;
      final current = await _auth.getAvailableBiometrics();
      return current.length != stored;
    } catch (_) {
      return false;
    }
  }

  BiometricStatus _map(PlatformException e) {
    switch (e.code) {
      case auth_error.lockedOut:
        return BiometricStatus.lockout;
      case auth_error.permanentlyLockedOut:
        return BiometricStatus.lockoutPermanent;
      case auth_error.notAvailable:
        return BiometricStatus.hwUnavailable;
      case auth_error.notEnrolled:
      case auth_error.passcodeNotSet:
        return BiometricStatus.noneEnrolled;
      default:
        return BiometricStatus.failed;
    }
  }
}
