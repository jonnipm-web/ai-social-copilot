// INSIGHTVALUES-FINANCIAL-PRODUCT-MACRO-08 §13 — structured upgrade UX.
//
// The server's PLAN_UPGRADE_REQUIRED denial (strategy-builder/index.ts's
// errorResponse) already carries requiredPlan/currentPlan/op -- this widget
// is the ONE place that turns it into something a user can act on, instead
// of every Strategy Lab screen inventing its own version of a bare 403.
// Mirrors the existing inline-banner idiom (content_generation_screen.dart's
// credits banner) rather than a modal or a snackbar, since the denial is a
// persistent state of the section, not a one-off transient event.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../data/strategy_builder_api.dart';

String planDisplayName(AppLocalizations l, String? plan) => switch (plan) {
      'pro' => l.planNamePro,
      'premium' => l.planNamePremium,
      _ => l.planNameFree,
    };

class PlanUpgradeBanner extends StatelessWidget {
  const PlanUpgradeBanner({super.key, required this.requiredPlan, required this.currentPlan});

  final String? requiredPlan;
  final String? currentPlan;

  factory PlanUpgradeBanner.fromResult(StrategyBuilderResult result) =>
      PlanUpgradeBanner(requiredPlan: result.requiredPlan, currentPlan: result.currentPlan);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final required = planDisplayName(l, requiredPlan);
    final current = planDisplayName(l, currentPlan);
    final color = Colors.amber.shade700;
    return Container(
      key: const Key('planUpgradeBanner'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.planUpgradeBannerTitle(required), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                Text(l.planUpgradeBannerBody(current, required), style: TextStyle(fontSize: 12, color: color)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            key: const Key('planUpgradeBannerCta'),
            onPressed: () => context.push(AppConstants.routeUpgrade),
            style: TextButton.styleFrom(foregroundColor: color, textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            child: Text(l.planUpgradeBannerCta),
          ),
        ],
      ),
    );
  }
}
