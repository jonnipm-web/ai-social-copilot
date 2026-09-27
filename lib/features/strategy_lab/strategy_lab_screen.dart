// INSIGHTVALUES-ROBOT-BUILDER-MACRO-05 — Strategy Lab (admin-only; EXPERIMENTAL module).
//
// Foundation-phase screen: read-only view of Strategy #001 (V10), the
// reference implementation proving the generic Strategy Specification
// (supabase/functions/_shared/strategy/) can represent it. No creation
// form, no backtest execution, no broker connection -- those are left for
// a future macro (see module_registry.dart's 'strategy-builder' notes).
//
// Access: the screen re-checks admin fail-closed (same pattern as
// QuantLabScreen); the server enforces entitlement on every strategy-
// builder request regardless of what this screen shows.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strategy/strategy_lab_reference.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/profile_provider.dart';

class StrategyLabScreen extends ConsumerWidget {
  const StrategyLabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(currentProfileProvider);
    if (!profileAsync.hasValue && !profileAsync.hasError) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final isAdmin = profileAsync.hasValue && !profileAsync.hasError && (profileAsync.value?.isAdmin ?? false);
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text(l.strategyLabTitle)),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l.strategyLabAccessDenied, textAlign: TextAlign.center))),
      );
    }

    final t = Theme.of(context).textTheme;
    Widget section(String title, List<Widget> children) => Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(header: true, child: Text(title, style: t.titleSmall)),
              const SizedBox(height: 8),
              ...children,
            ]),
          ),
        );
    Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text.rich(TextSpan(children: [TextSpan(text: '$k: ', style: const TextStyle(fontWeight: FontWeight.w600)), TextSpan(text: v)])),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l.strategyLabTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          key: const Key('strategyLabScroll'),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _Banner(text: l.strategyLabBanner),
            const SizedBox(height: 12),
            Text(V10ReferenceStrategy.name, style: t.titleMedium),
            const SizedBox(height: 4),
            Text(l.strategyLabDisclaimer, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 12),
            section(l.strategyLabStatusLabel, [
              kv(l.strategyLabStatusLabel, V10ReferenceStrategy.status),
              kv(l.strategyLabPositionSize, '${V10ReferenceStrategy.instrumentSymbol} · ${V10ReferenceStrategy.signalTimeframe} · ${V10ReferenceStrategy.positionSizeQuantity}'),
            ]),
            section(l.strategyLabRulesSection, [
              kv(l.strategyLabEntry, '${V10ReferenceStrategy.entry.summary} (${V10ReferenceStrategy.allowedDirections})'),
              kv(l.strategyLabStop, '${V10ReferenceStrategy.stopDistance} pts'),
              kv(l.strategyLabTarget, '${V10ReferenceStrategy.targetDistance} pts'),
              kv(l.strategyLabBreakEven,
                  '+${V10ReferenceStrategy.breakEvenTriggerDistance} → +${V10ReferenceStrategy.breakEvenInitialProtectedDistance}, step +${V10ReferenceStrategy.breakEvenStepDistance}'),
              kv(l.strategyLabSession, '${V10ReferenceStrategy.sessionStart}–${V10ReferenceStrategy.sessionEnd} (${V10ReferenceStrategy.allowedWeekdays})'),
              kv(l.strategyLabForcedExit, V10ReferenceStrategy.forcedExitTime),
            ]),
            section(l.strategyLabHistoricalReference, [
              kv(l.strategyLabZeroCost,
                  '${V10ReferenceStrategy.zeroCostTradeCount} trades, net R\$${V10ReferenceStrategy.zeroCostNetPnl.toStringAsFixed(2)}, hash ${V10ReferenceStrategy.zeroCostResultHash}'),
              kv(l.strategyLabWithCost,
                  '${V10ReferenceStrategy.withCostTradeCount} trades, net R\$${V10ReferenceStrategy.withCostNetPnl.toStringAsFixed(2)}, hash ${V10ReferenceStrategy.withCostResultHash}'),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: cs.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Icon(Icons.science_outlined, color: cs.onSecondaryContainer),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: cs.onSecondaryContainer))),
      ]),
    );
  }
}
