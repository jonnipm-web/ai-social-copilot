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
            data: (quota) => _PlanSection(
              isPro: quota.isPro,
              planLabel: quota.isPro ? t.planPro : t.planFree,
              usageLabel: '${t.accountUsage}: ${quota.used} / ${quota.limit}',
              ctaLabel: t.accountUpgradeManage,
              onTapCta: () => context.push(AppConstants.routeUpgrade),
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

// COMMERCIAL-EXPERIENCE-CLOSURE-16R (mission Section 06) — owner-supplied
// physical evidence (Samsung SM-S938B): the previous single ListTile put
// title ("Pro Founder") + subtitle (usage) in its Expanded middle column
// while `trailing` held a TextButton whose label
// (accountUpgradeManage — "Fazer upgrade / gerenciar assinatura" in PT)
// is long. ListTile's trailing column is intrinsically sized, not
// responsive, so on a real phone width it ate most of the row, collapsing
// title/subtitle's available width down to a handful of pixels -- each
// wrapped to nearly one character per line. No breakpoint patch fixes
// this correctly, because the underlying problem (two independently-sized,
// width-competing text blocks forced into one Row) exists at every width,
// just less visibly on a wide desktop window. Stacking the CTA on its own
// line below removes the competition entirely, unconditionally.
class _PlanSection extends StatelessWidget {
  const _PlanSection({
    required this.isPro,
    required this.planLabel,
    required this.usageLabel,
    required this.ctaLabel,
    required this.onTapCta,
  });

  final bool         isPro;
  final String       planLabel;
  final String       usageLabel;
  final String       ctaLabel;
  final VoidCallback onTapCta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPro ? Icons.workspace_premium_rounded : Icons.card_giftcard_rounded,
                color: isPro ? const Color(0xFFFFD700) : Colors.white70,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(planLabel, style: const TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(
                      usageLabel,
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onTapCta,
              child: Text(ctaLabel),
            ),
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
