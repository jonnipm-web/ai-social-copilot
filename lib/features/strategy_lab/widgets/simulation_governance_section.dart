// INSIGHTVALUES-FINANCIAL-PRODUCT-MACRO-08 continuation §5-8, §22-26 —
// Governed Simulation UX.
//
// The simulation itself already ran safely, deterministically and
// in-process inside strategy-builder's run_simulation op, which also
// auto-records a SIMULATION-category strategy_experiments row (see
// index.ts's run_simulation handler) -- this section is ONLY the
// optional, formal Human Gate ceremony on top of that already-safe
// result, exactly mirroring strategy_simulation_tools.ts's own doc
// comment ("a human formally approves/acknowledges a simulation result
// through the SAME AEF pipeline... never a direct IVE-to-simulation
// bypass").
//
// Runtime-capability aware by construction, never a dead button:
// strategy-simulation-runtime is LAB-only (kAefRuntimeLabEnabled is a
// compile-time flag, off in any normal build), so this widget shows an
// honest "unavailable in this environment" message instead of a button
// that would always fail. When the flag IS on, the real AefActionCard
// (already used by the IVE chat card and Action Engine) drives the
// actual propose -> approve/reject -> execute -> receipt flow -- no new
// governance code, full reuse.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/aef_runtime.dart';
import '../../../data/services/aef_runtime_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/aef_action_card.dart';

class SimulationGovernanceSection extends ConsumerStatefulWidget {
  const SimulationGovernanceSection({super.key, required this.experimentId, required this.strategyId});

  /// A real strategy_experiments.id, already persisted server-side by
  /// run_simulation -- never client-invented.
  final String experimentId;
  final String strategyId;

  @override
  ConsumerState<SimulationGovernanceSection> createState() => _SimulationGovernanceSectionState();
}

class _SimulationGovernanceSectionState extends ConsumerState<SimulationGovernanceSection> {
  AefRuntimeResult? _lastResult;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (!kAefRuntimeLabEnabled) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(l.strategyDetailSimulationRuntimeUnavailable, key: const Key('strategyDetailSimulationRuntimeUnavailable')),
      );
    }
    final code = _lastResult?.denialCode;
    final friendly = switch (code) {
      null => null,
      'MODULE_NOT_AVAILABLE' || 'PLAN_REQUIRED' || 'AUTH_REQUIRED' => l.strategyDetailSimulationRuntimePlanRequired,
      'RUNTIME_DISABLED' => l.strategyDetailSimulationRuntimeUnavailable,
      _ => l.strategyDetailSimulationRuntimePolicyBlocked(code),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.strategyDetailSimulationGovernanceTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
          AefActionCard(
            key: const Key('strategyDetailSimulationGate'),
            intent: IveActionIntentData(
              capabilityId: 'ive-strategy-simulation',
              requestedAction: 'approve_simulation_result',
              projectId: null,
              riskClass: 'CONSEQUENTIAL',
              contextRef: widget.strategyId,
            ),
            api: ref.read(strategySimulationRuntimeApiProvider),
            initialValues: {'experiment_id': widget.experimentId},
            title: l.aefLabTitleStrategySimulation,
            onResult: (r) => setState(() => _lastResult = r),
          ),
          if (friendly != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(friendly, key: const Key('strategyDetailSimulationGovernanceDenialText'), style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
