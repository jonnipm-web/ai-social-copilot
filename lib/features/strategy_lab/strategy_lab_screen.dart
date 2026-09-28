// INSIGHTVALUES-ROBOT-BUILDER-MACRO-06 — Strategy Lab hub (admin-only;
// EXPERIMENTAL module).
//
// MVP phase (Macro-05 was read-only-only; this macro's own mission brief
// named that the #1 gap to close): a real "My Strategies" list, a real
// create/edit form (strategy_builder_form_screen.dart), and a real detail
// view with backtest + comparison (strategy_detail_screen.dart). The V10
// reference display block from Macro-05 is preserved as-is below it.
//
// Access: the screen re-checks admin fail-closed (same pattern as
// QuantLabScreen); the server enforces entitlement on every strategy-
// builder request regardless of what this screen shows.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strategy/strategy_lab_reference.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/profile_provider.dart';
import '../../shared/widgets/ive_exclusion_region.dart';
import 'data/strategy_builder_api.dart';
import 'strategy_builder_form_screen.dart';
import 'strategy_detail_screen.dart';

class StrategyLabScreen extends ConsumerStatefulWidget {
  const StrategyLabScreen({super.key});

  @override
  ConsumerState<StrategyLabScreen> createState() => _StrategyLabScreenState();
}

class _StrategyLabScreenState extends ConsumerState<StrategyLabScreen> {
  List<dynamic> _strategies = const [];
  bool _loading = true;
  bool _cloneBusy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final result = await ref.read(strategyBuilderApiProvider).list();
    if (!mounted) return;
    setState(() {
      _strategies = (result.data?['strategies'] as List?) ?? const [];
      _loading = false;
    });
  }

  Future<void> _clone(String reference) async {
    setState(() => _cloneBusy = true);
    await ref.read(strategyBuilderApiProvider).cloneReference(reference);
    if (!mounted) return;
    setState(() => _cloneBusy = false);
    await _refresh();
  }

  Future<void> _openNew() async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const StrategyBuilderFormScreen()));
    if (saved == true) _refresh();
  }

  void _openDetail(String strategyId) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => StrategyDetailScreen(strategyId: strategyId)));
  }

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: 16),

            Text(l.strategyBuilderMyStrategies, style: t.titleMedium),
            const SizedBox(height: 8),
            IveExclusionRegion(
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.icon(
                  key: const Key('strategyLabNewButton'),
                  onPressed: _openNew,
                  icon: const Icon(Icons.add),
                  label: Text(l.strategyBuilderNewButton),
                ),
                OutlinedButton(
                  key: const Key('strategyLabCloneV10'),
                  onPressed: _cloneBusy ? null : () => _clone('V10'),
                  child: Text(l.strategyBuilderCloneV10),
                ),
                OutlinedButton(
                  key: const Key('strategyLabCloneGeneric'),
                  onPressed: _cloneBusy ? null : () => _clone('GENERIC'),
                  child: Text(l.strategyBuilderCloneGeneric),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
            else if (_strategies.isEmpty)
              Padding(padding: const EdgeInsets.all(8), child: Text(l.strategyBuilderEmptyList))
            else
              Card(
                key: const Key('strategyLabList'),
                child: Column(children: [
                  for (final s in _strategies)
                    ListTile(
                      title: Text(s['name'] as String),
                      subtitle: Text('${s['status']} · v${s['currentVersion']}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openDetail(s['id'] as String),
                    ),
                ]),
              ),

            const SizedBox(height: 24),
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
