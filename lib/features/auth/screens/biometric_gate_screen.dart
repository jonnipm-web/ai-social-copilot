import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/biometric_auth_service.dart';
import '../../../providers/biometric_auth_provider.dart';

/// Shown on cold start when the user has biometric login enabled.
/// Blocks navigation to the app until biometric challenge passes.
class BiometricGateScreen extends ConsumerStatefulWidget {
  const BiometricGateScreen({super.key});

  @override
  ConsumerState<BiometricGateScreen> createState() => _BiometricGateScreenState();
}

class _BiometricGateScreenState extends ConsumerState<BiometricGateScreen> {
  bool _isAuthenticating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    final service = ref.read(biometricAuthServiceProvider);
    final uid = Supabase.instance.client.auth.currentUser?.id;

    if (uid == null) {
      _fallbackToLogin();
      return;
    }

    final status = await service.authenticate(
      localizedReason: 'Confirme sua identidade para acessar o AI Social Copilot',
      userId: uid,
    );

    if (!mounted) return;

    switch (status) {
      case BiometricStatus.success:
        // Validate session is still active after biometric approval.
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          await service.disable(userId: uid);
          _fallbackToLogin(reason: 'Sua sessão expirou. Faça login novamente.');
        } else {
          context.go(AppConstants.routeExecutiveDashboard);
        }
      case BiometricStatus.lockout:
        setState(() {
          _isAuthenticating = false;
          _errorMessage = 'Muitas tentativas. Aguarde e tente novamente.';
        });
      case BiometricStatus.lockoutPermanent:
        setState(() {
          _isAuthenticating = false;
          _errorMessage =
              'Biometria bloqueada permanentemente. Use PIN/senha no dispositivo para desbloquear.';
        });
      case BiometricStatus.noneEnrolled:
        await service.disable(userId: uid);
        _fallbackToLogin(reason: 'Dados biométricos alterados. Faça login novamente.');
      case BiometricStatus.noHardware:
      case BiometricStatus.hwUnavailable:
        await service.disable(userId: uid);
        _fallbackToLogin(reason: 'Biometria indisponível no dispositivo.');
      case BiometricStatus.userCancel:
      case BiometricStatus.failed:
        setState(() {
          _isAuthenticating = false;
          _errorMessage = null;
        });
      case BiometricStatus.sessionExpired:
      case BiometricStatus.notSupported:
        _fallbackToLogin();
    }
  }

  void _fallbackToLogin({String? reason}) {
    if (!mounted) return;
    if (reason != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reason), backgroundColor: Colors.red.shade700),
      );
    }
    context.go(AppConstants.routeLogin);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.fingerprint_rounded, size: 80, color: primary),
                const SizedBox(height: 24),
                Text(
                  'Autenticação biométrica',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use sua digital ou reconhecimento facial para entrar.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.white54),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                if (_isAuthenticating)
                  const CircularProgressIndicator()
                else ...[
                  FilledButton.icon(
                    onPressed: _authenticate,
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: const Text('Tentar novamente'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go(AppConstants.routeLogin),
                    child: Text(
                      'Entrar com e-mail e senha',
                      style: TextStyle(color: primary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
