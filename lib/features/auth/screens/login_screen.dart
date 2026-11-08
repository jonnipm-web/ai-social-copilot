import 'package:flutter/material.dart';
import 'package:ai_social_copilot/shared/ui/iv_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/snackbar_utils.dart'
    show showErrorSnack, extractErrorMessage;
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/loading_button.dart';
import 'package:ai_social_copilot/core/theme/app_tokens.dart';

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
      error: (e, _) => showErrorSnack(
          context,
          extractErrorMessage(e, AppLocalizations.of(context)!,
              AppLocalizations.of(context)!.uxAuthErrorGeneric)),
      data: (_) => context.go(AppConstants.routeHome),
    );
  }

  Future<void> _submitGoogle() async {
    final notifier = ref.read(authNotifierProvider.notifier);
    await notifier.signInWithGoogle();

    if (!mounted) return;

    final authState = ref.read(authNotifierProvider);
    if (authState.hasError) {
      showErrorSnack(
          context,
          extractErrorMessage(authState.error, AppLocalizations.of(context)!,
              AppLocalizations.of(context)!.uxAuthErrorGeneric));
      return;
    }

    // Web: signInWithOAuth navega o navegador inteiro para o Google e
    // volta -- quando este código roda de novo (app recarregado do zero),
    // a SplashScreen já assume a checagem de sessão e o redirecionamento,
    // então normalmente nunca se chega aqui de fato nesse caminho.
    // Android: signInWithIdToken retorna nesta mesma sessão de app: se o
    // usuário cancelou (fechou o seletor de conta), não há sessão nova e
    // não é um erro -- só não navega, fica na tela de login.
    if (Supabase.instance.client.auth.currentSession != null) {
      context.go(AppConstants.routeHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      body: IvBody(child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s6, vertical: AppSpace.s8),
            child: ConstrainedBox(
             constraints: const BoxConstraints(maxWidth: 420),
             child: FadeSlideIn(
             child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.accent, AppColors.info],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.35),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.insights_rounded,
                          size: 30, color: AppColors.onAccent),
                    ),
                  ),
                  const SizedBox(height: AppSpace.s6),
                  Text(
                    _isSignUp ? t.authCreateAccount : t.authWelcomeBack,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: AppSpace.s2),
                  Text(
                    '${AppConstants.appName} · ${t.authTagline}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.inkMuted, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: AppSpace.s8),
                  // GATE-17-FINAL-CLOSURE (Section 11, text-scale physical
                  // regression, 2026-09-22) — OutlinedButton.icon's own Row
                  // (icon + label) has no width guard on the label: at 1.3x
                  // Android text scale, "Continuar com Google"/"Continue
                  // with Google" no longer fits and the button overflows by
                  // a fixed 39px, reproduced consistently on device (and
                  // gone again at 1.0x, confirming text scale as the
                  // trigger). Built with an explicit Row instead of the
                  // `.icon` factory so the label can be wrapped in
                  // Flexible + TextOverflow.ellipsis -- shrinks to fit
                  // instead of overflowing, at any text scale.
                  OutlinedButton(
                    onPressed: isLoading ? null : _submitGoogle,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      minimumSize: const Size.fromHeight(48),
                      side: const BorderSide(color: AppColors.controlBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.g_mobiledata_rounded, size: 26),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            t.authContinueWithGoogle,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(child: Divider(color: AppColors.line)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          t.commonOr,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.inkSubtle),
                        ),
                      ),
                      const Expanded(child: Divider(color: AppColors.line)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  AppTextField(
                    controller: _emailCtrl,
                    label: t.authEmail,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return t.authEmailRequired;
                      }
                      if (!v.contains('@')) return t.authEmailInvalid;
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _passwordCtrl,
                    label: t.authPassword,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? t.authShowPassword
                          : t.authHidePassword,
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: AppColors.inkSubtle,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return t.authPasswordRequired;
                      if (_isSignUp && v.length < 6) {
                        return t.authPasswordMinLength;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpace.s6),
                  LoadingButton(
                    label: _isSignUp ? t.authSignUp : t.authSignIn,
                    isLoading: isLoading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(
                      _isSignUp ? t.authHasAccount : t.authNoAccount,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
             ),
             ),
            ),
          ),
        ),
      ),
    ));
  }
}
