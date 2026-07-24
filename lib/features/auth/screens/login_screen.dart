import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/biometric_auth_service.dart';
import '../../../core/utils/snackbar_utils.dart' show showErrorSnack, extractErrorMessage;
import '../../../providers/auth_provider.dart';
import '../../../providers/biometric_auth_provider.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/loading_button.dart';
import '../widgets/biometric_enrollment_sheet.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isSignUp = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(authNotifierProvider.notifier);

    if (_isSignUp) {
      await notifier.signUp(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
      );
    } else {
      await notifier.signIn(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
      );
    }

    if (!mounted) return;

    final authState = ref.read(authNotifierProvider);
    authState.whenOrNull(
      error: (e, _) => showErrorSnack(context, extractErrorMessage(e)),
      data: (_) async {
        // Offer biometric enrollment after first successful sign-in (not sign-up).
        if (!_isSignUp) {
          await _offerBiometricEnrollment();
        }
        if (mounted) context.go(AppConstants.routeHome);
      },
    );
  }

  Future<void> _offerBiometricEnrollment() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    final biometric = BiometricAuthService();
    final available = await biometric.isAvailable();
    if (!available) return;

    final alreadyEnabled = await biometric.isEnabled(userId: uid);
    if (alreadyEnabled) return;

    if (!mounted) return;
    await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF0F0F1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => BiometricEnrollmentSheet(userId: uid),
    );
    if (mounted) ref.invalidate(biometricEnabledProvider);
  }

  Future<void> _signInWithBiometrics() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    // Biometric sign-in is only valid when a session already exists (persisted
    // by Supabase Flutter). This button is shown in that case.
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null || uid == null) return;

    final biometric = BiometricAuthService();
    final status = await biometric.authenticate(
      localizedReason: 'Confirme sua identidade para entrar',
      userId: uid,
    );

    if (!mounted) return;

    switch (status) {
      case BiometricStatus.success:
        context.go(AppConstants.routeExecutiveDashboard);
      case BiometricStatus.lockout:
        showErrorSnack(context, 'Muitas tentativas. Aguarde e tente novamente.');
      case BiometricStatus.lockoutPermanent:
        showErrorSnack(context, 'Biometria bloqueada. Use PIN/senha no dispositivo.');
      case BiometricStatus.noneEnrolled:
        await biometric.disable(userId: uid);
        ref.invalidate(biometricEnabledProvider);
        showErrorSnack(context, 'Dados biométricos alterados. Reative o login biométrico.');
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    // Show biometric button on sign-in form only when biometric is enabled.
    final biometricEnabled = !_isSignUp
        ? ref.watch(biometricEnabledProvider).valueOrNull ?? false
        : false;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  Icon(
                    Icons.auto_awesome,
                    size: 52,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppConstants.appName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSignUp ? 'Crie sua conta' : 'Bem-vindo de volta',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white54),
                  ),
                  const SizedBox(height: 40),
                  AppTextField(
                    controller: _emailCtrl,
                    label: 'E-mail',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Informe seu e-mail';
                      }
                      if (!v.contains('@')) return 'E-mail inválido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _passwordCtrl,
                    label: 'Senha',
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.white38,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Informe sua senha';
                      if (_isSignUp && v.length < 6) {
                        return 'Mínimo de 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  LoadingButton(
                    label: _isSignUp ? 'Criar conta' : 'Entrar',
                    isLoading: isLoading,
                    onPressed: _submit,
                  ),
                  if (biometricEnabled) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: isLoading ? null : _signInWithBiometrics,
                      icon: const Icon(Icons.fingerprint_rounded),
                      label: const Text('Entrar com biometria'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(
                      _isSignUp
                          ? 'Já tem conta? Faça login'
                          : 'Não tem conta? Cadastre-se',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
