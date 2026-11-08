import 'package:flutter/material.dart';
import 'package:ai_social_copilot/shared/ui/iv_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/snackbar_utils.dart'
    show extractErrorMessage, showErrorSnack;
import '../../../data/models/quota_info.dart';
import '../../../data/services/billing_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/quota_provider.dart';
import 'package:ai_social_copilot/core/theme/app_tokens.dart';

class UpgradeScreen extends ConsumerWidget {
  const UpgradeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final quotaAsync = ref.watch(currentQuotaProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.upgradePlansTitle),
        leading: const BackButton(),
      ),
      body: IvBody(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: quotaAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 56),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  t.upgradeLoadError,
                  style: const TextStyle(color: AppColors.inkMuted),
                ),
              ),
              data: (quota) => _UpgradeContent(quota: quota),
            ),
          ),
        ),
      )),
    );
  }
}

class _UpgradeContent extends ConsumerStatefulWidget {
  const _UpgradeContent({required this.quota});
  final QuotaInfo quota;

  static const _freeLimit = 15;
  static const _proLimit = 300;

  @override
  ConsumerState<_UpgradeContent> createState() => _UpgradeContentState();
}

class _UpgradeContentState extends ConsumerState<_UpgradeContent> {
  final _billingService = BillingService();
  bool _isRedirecting = false;

  QuotaInfo get quota => widget.quota;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    // Sempre usar o limite comercial canônico (300), nunca substituir pelo
    // quota.limit do usuário: admins têm limit=99999, o que exibiria um valor
    // enganoso no catálogo de planos. O limite real de cota do usuário já está
    // visível no _UsageBanner; aqui o contexto é marketing/comparação de planos.
    final displayedProLimit = _UpgradeContent._proLimit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _UsageBanner(quota: quota),
        const SizedBox(height: 28),
        IvCardGrid(
          minTileWidth: 360,
          maxColumns: 2,
          children: [
            _PlanCard(
              title: t.planFree,
              subtitle: quota.isAdmin ? '' : t.upgradeFreeSubtitle,
              price: t.planFreePrice,
              period: '',
              isHighlighted: false,
              isCurrentPlan: !quota.isCommercialPro && !quota.isAdmin,
              badge: null,
              features: [
                _Feature(t.planFreeAnalyses(_UpgradeContent._freeLimit), true),
                _Feature(t.upgradeFeatureWebsiteAnalysis, true),
                _Feature(t.upgradeFeatureStrategyActions, true),
                _Feature(t.upgradeFeatureUnlimited, false),
                _Feature(t.upgradeFeaturePriority, false),
                _Feature(t.upgradeFeatureSupport, false),
              ],
              buttonLabel:
                  quota.isCommercialPro ? t.upgradePreviousPlan : t.planCurrentPlan,
              onPressed: null,
            ),
            _PlanCard(
              title: t.planPro,
              subtitle: t.upgradeProSubtitle,
              price: t.planProPriceAmount,
              period: t.planProPricePeriod,
              isHighlighted: !quota.isCommercialPro,
              isCurrentPlan: quota.isCommercialPro,
              badge: quota.isCommercialPro
                  ? t.upgradeCurrentPlanBadge
                  : t.upgradeMostPopular,
              features: [
                _Feature(t.planProAnalyses(displayedProLimit), true),
                _Feature(t.upgradeFeatureWebsiteAnalysis, true),
                _Feature(t.upgradeFeatureStrategyActions, true),
                _Feature(t.upgradeFeaturePriority, true),
                _Feature(t.upgradeFeatureSupportEmail, true),
                _Feature(t.upgradeFeatureEarlyAccess, true),
              ],
              buttonLabel: quota.isCommercialPro
                  ? t.planCurrentPlan
                  : (_isRedirecting ? t.checkoutOpening : t.upgradeSubscribeCta),
              onPressed: quota.isCommercialPro || quota.isAdmin || _isRedirecting
                  ? null
                  : _onUpgradeTap,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          t.planFounderNote,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.inkSubtle, fontSize: 11),
        ),
        const SizedBox(height: 32),
        _FaqSection(
            freeLimit: _UpgradeContent._freeLimit,
            proLimit: _UpgradeContent._proLimit),
      ],
    );
  }

  Future<void> _onUpgradeTap() async {
    final t = AppLocalizations.of(context)!;
    setState(() => _isRedirecting = true);
    try {
      final url = await _billingService.createCheckoutSession();
      final launched =
          await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
      if (!launched && mounted) {
        showErrorSnack(context, t.checkoutOpeningError);
      }
    } catch (e) {
      if (mounted)
        showErrorSnack(
            context, extractErrorMessage(e, t, t.checkoutOpeningError));
    } finally {
      if (mounted) setState(() => _isRedirecting = false);
    }
  }
}

class _UsageBanner extends StatelessWidget {
  const _UsageBanner({required this.quota});
  final QuotaInfo quota;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final remaining = quota.remaining;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface, gradient: kIvSurfaceGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded,
                  size: 18, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(
                t.upgradeUsageThisMonth,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: AppColors.inkMuted),
              ),
              const Spacer(),
              Text(
                quota.isAdmin
                    ? '${quota.used} / 99.999'
                    : '${quota.used} / ${quota.limit}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: LinearProgressIndicator(
              value: quota.fractionUsed,
              minHeight: 8,
              backgroundColor: AppColors.line,
              valueColor: AlwaysStoppedAnimation<Color>(
                quota.isExhausted ? AppColors.negative : AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            quota.isAdmin
                ? t.upgradeAnalysesRemaining(remaining, 'Admin')
                : (remaining > 0
                    ? t.upgradeAnalysesRemaining(remaining,
                        quota.isCommercialPro ? t.planPro : t.planFree)
                    : t.upgradeUsedAllAnalyses),
            style: TextStyle(
              fontSize: 12,
              color: remaining > 0 || quota.isAdmin
                  ? AppColors.inkMuted
                  : AppColors.negative,
            ),
          ),
        ],
      ),
    );
  }
}

class _Feature {
  const _Feature(this.label, this.included);
  final String label;
  final bool included;
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.period,
    required this.isHighlighted,
    required this.isCurrentPlan,
    required this.badge,
    required this.features,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String price;
  final String period;
  final bool isHighlighted;
  final bool isCurrentPlan;
  final String? badge;
  final List<_Feature> features;
  final String buttonLabel;
  final VoidCallback? onPressed;

  static const _primary = AppColors.accent;
  static const _gold = AppColors.gold;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface, gradient: kIvSurfaceGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isHighlighted ? _primary : AppColors.line,
          width: isHighlighted ? 2 : 1,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: _primary.withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: isCurrentPlan ? AppColors.accent : _primary,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Text(
                badge!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isHighlighted) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.star_rounded, color: _gold, size: 18),
                    ],
                  ],
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (period.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4, left: 2),
                        child: Text(
                          period,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.line),
                const SizedBox(height: 12),
                ...features.map((f) => _FeatureRow(feature: f)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: onPressed,
                  style: onPressed == null
                      ? ElevatedButton.styleFrom(
                          backgroundColor: AppColors.line,
                          foregroundColor: AppColors.inkSubtle,
                        )
                      : null,
                  child: Text(buttonLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.feature});
  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            feature.included
                ? Icons.check_circle_rounded
                : Icons.cancel_rounded,
            size: 18,
            color: feature.included ? AppColors.accent : AppColors.inkSubtle,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              feature.label,
              style: TextStyle(
                fontSize: 14,
                color: feature.included ? AppColors.ink : AppColors.inkSubtle,
                decoration:
                    feature.included ? null : TextDecoration.lineThrough,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqSection extends StatelessWidget {
  const _FaqSection({required this.freeLimit, required this.proLimit});
  final int freeLimit;
  final int proLimit;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final items = [
      _FaqItem(q: t.upgradeFaqFreeLimitQ, a: t.upgradeFaqFreeLimitA(freeLimit)),
      _FaqItem(q: t.upgradeFaqCancelQ, a: t.upgradeFaqCancelA),
      _FaqItem(q: t.upgradeFaqDataQ, a: t.upgradeFaqDataA),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.upgradeFaqTitle,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ...items.map((item) => _FaqTile(item: item)),
      ],
    );
  }
}

class _FaqItem {
  const _FaqItem({required this.q, required this.a});
  final String q;
  final String a;
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.item});
  final _FaqItem item;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      title: Text(
        item.q,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      children: [
        Text(
          item.a,
          style: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
        ),
      ],
    );
  }
}
