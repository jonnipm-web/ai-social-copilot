import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/quota_provider.dart';

/// IVE-COMMERCIAL-RELEASE-CONTROL-PLANE-01 — "Conta e Configurações":
/// perfil, idioma, plano/uso, upgrade, ajuda, sobre, privacidade, termos,
/// sair. Status de login com Google só é mostrado se a sessão atual foi
/// de fato estabelecida via provider Google (nunca reivindica um método de
/// autenticação que não está disponível).
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(currentProfileProvider);
    final quotaAsync = ref.watch(currentQuotaProvider);
    final language = ref.watch(languageProvider);

    // supabase_flutter expõe o provedor da identidade atual via
    // currentUser.appMetadata['provider'] -- 'google' quando a sessão foi
    // criada por signInWithOAuth/signInWithIdToken, 'email' caso contrário.
    final authProvider = ref.watch(authServiceProvider).currentUser?.appMetadata['provider'] as String?;
    final isGoogleLinked = authProvider == 'google';

    return Scaffold(
      appBar: AppBar(title: Text(t.accountTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionLabel(t.accountProfile),
          profileAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (profile) => ListTile(
              leading: const Icon(Icons.person_outline_rounded, color: Colors.white70),
              title: Text(profile?.email ?? '', style: const TextStyle(color: Colors.white)),
              subtitle: isGoogleLinked
                  ? Text(t.accountGoogleLinked, style: const TextStyle(color: Colors.white38, fontSize: 12))
                  : null,
            ),
          ),
          const Divider(color: Colors.white12, height: 32),

          _SectionLabel(t.accountLanguage),
          RadioListTile<String>(
            value: 'pt',
            groupValue: language.languageCode,
            title: Text(t.accountLanguagePortuguese),
            onChanged: (v) => v != null ? ref.read(languageProvider.notifier).setLanguage(v) : null,
          ),
          RadioListTile<String>(
            value: 'en',
            groupValue: language.languageCode,
            title: Text(t.accountLanguageEnglish),
            onChanged: (v) => v != null ? ref.read(languageProvider.notifier).setLanguage(v) : null,
          ),
          const Divider(color: Colors.white12, height: 32),

          _SectionLabel(t.accountCurrentPlan),
          quotaAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (quota) => ListTile(
              leading: Icon(
                quota.isPro ? Icons.workspace_premium_rounded : Icons.card_giftcard_rounded,
                color: quota.isPro ? const Color(0xFFFFD700) : Colors.white70,
              ),
              title: Text(quota.isPro ? t.planPro : t.planFree),
              subtitle: Text(
                '${t.accountUsage}: ${quota.used} / ${quota.limit}',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              trailing: TextButton(
                onPressed: () => context.push(AppConstants.routeUpgrade),
                child: Text(t.accountUpgradeManage),
              ),
            ),
          ),
          const Divider(color: Colors.white12, height: 32),

          ListTile(
            leading: const Icon(Icons.help_outline_rounded, color: Colors.white70),
            title: Text(t.accountHelpSupport),
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
            onTap: () => context.push(AppConstants.routeSupport),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded, color: Colors.white70),
            title: Text(t.accountAbout),
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
            onTap: () => context.push(AppConstants.routeAbout),
          ),
          const Divider(color: Colors.white12, height: 32),

          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: Text(t.accountSignOut, style: const TextStyle(color: Colors.redAccent)),
            onTap: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) context.go(AppConstants.routeLogin);
            },
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
