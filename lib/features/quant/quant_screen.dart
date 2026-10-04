// IV-QUANT-MACRO-05 FASE 13 — Quant product shell (/quant).
//
// Placeholder for the public-facing Quant Analytics surface.
// Route: AppConstants.routeQuant = '/quant'
// Module: 'quant-analytics' (INTERNAL, entitlement-gated via route_policy).
//
// This shell is intentionally minimal for the pilot. It will evolve as
// entitlement tiers (FREE/PRO/BUSINESS/ENTERPRISE) and the full product
// surface are authorised by Agente Martins + Paulo.
//
// MUST NOT contain:
//   - Buy/sell/broker actions (DENY_BY_V0)
//   - Price forecasts or recommendations
//   - Any numeric output not sourced from the quant engine
// See: docs/quant/QUANT_RESEARCH_ADVICE_BOUNDARY.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/profile_provider.dart';
import '../../shared/widgets/ive_exclusion_region.dart';
import '../../shared/widgets/quant_disclaimer_banner.dart';

class QuantScreen extends ConsumerWidget {
  const QuantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(currentProfileProvider);

    return IveExclusionRegion(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quant Analytics'),
          centerTitle: false,
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.show_chart_rounded,
                            size: 64,
                            color: theme.colorScheme.primary.withOpacity(0.4)),
                        const SizedBox(height: 24),
                        Text(
                          'Quant Analytics',
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Historical market-data analytics powered by the '
                          'InsightValues engine.\n\nThis surface is in internal '
                          'pilot. Full product access coming soon.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.6)),
                          textAlign: TextAlign.center,
                        ),
                        profileAsync.whenOrNull(
                          data: (p) => p != null
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Chip(
                                    label: Text(
                                        'Role: ${p.role.toUpperCase()}'),
                                    avatar: const Icon(Icons.verified_user,
                                        size: 16),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ) ??
                            const SizedBox.shrink(),
                      ],
                    ),
                  ),
                ),
              ),
              // Mandatory disclaimer — see QUANT_RESEARCH_ADVICE_BOUNDARY.md §5
              const QuantDisclaimerBanner(),
            ],
          ),
        ),
      ),
    );
  }
}
