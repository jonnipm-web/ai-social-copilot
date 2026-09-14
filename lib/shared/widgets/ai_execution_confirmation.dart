import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/diagnostics/diagnostic_models.dart';
import '../../data/models/ive_interaction_request.dart';
import '../../providers/diagnostic_session_provider.dart' show diagnosticLoggerProvider;
import '../../providers/quota_provider.dart';

// IVE-COMMERCIAL-FOUNDATION-11 — the ONE reusable AI-execution
// confirmation + processing-state mechanism for the whole app (mission
// brief Sections 07-08; docs/commercial/IVE_INTERACTION_AND_QUOTA_
// CONTRACT.md §3-4). Before this mission, 8 different screens
// (gap_analysis_screen.dart, opportunity_discovery_screen.dart,
// revenue_planner_screen.dart, niche_discovery_screen.dart,
// content_cluster_screen.dart, competitor_discovery_screen.dart,
// persona_form_screen.dart, action_engine_screen.dart) each fired an AI
// call immediately on button press, guarded only by a private `bool
// _running`, with zero confirmation UX. This does NOT convert all 8 in
// this mission (see IMPLEMENTATION_ROADMAP.md — that is Phase C/D work);
// it establishes the mechanism and wires ONE representative call site
// (gap_analysis_screen.dart) to prove it end-to-end, per mission Section
// 11's "minimal representative integration set" instruction.

/// Minimum states per mission Section 08. [reservingQuota], [generating]
/// and [persisting] are defined for API completeness and for any future
/// backend that can report finer-grained progress, but the Edge
/// Functions this app calls today are a single atomic request/response
/// with no intermediate signal — per Section 08's own instruction ("Do
/// not create fake states if the backend gives no basis for
/// distinguishing them"), [AiExecutionController.run] only ever
/// transitions through [reservingQuota] and [thinking] for the actual
/// network call, never fabricating [generating]/[persisting] progress it
/// cannot observe.
enum AiExecutionState {
  idle,
  awaitingConfirmation,
  reservingQuota,
  thinking,
  generating,
  persisting,
  success,
  error,
  retryableError,
}

/// Reusable AI-execution controller: owns the confirmation dialog, the
/// processing-state model, the synchronous double-submit guard, and the
/// safe observability event sequence (§3.3 of the quota contract). One
/// instance per AI-triggering button/screen — the same lifetime a
/// screen's private `bool _running` field used to have.
class AiExecutionController extends ChangeNotifier {
  AiExecutionState _state = AiExecutionState.idle;
  AiExecutionState get state => _state;

  /// True while a confirmation or execution is in flight — a second
  /// [run] call while this is true is a no-op, not a second request.
  bool get isBusy =>
      _state != AiExecutionState.idle &&
      _state != AiExecutionState.success &&
      _state != AiExecutionState.error &&
      _state != AiExecutionState.retryableError;

  void _setState(AiExecutionState s) {
    _state = s;
    notifyListeners();
  }

  /// Runs [action] behind the standard confirm → reserve → execute flow.
  /// Returns the action's result, or `null` if the user cancelled or a
  /// request was already in flight. Does NOT swallow [action]'s
  /// exceptions — they propagate to the caller's own try/catch, exactly
  /// like the `bool _running` pattern this replaces, so existing
  /// per-screen error-display code keeps working unchanged.
  Future<T?> run<T>({
    required BuildContext context,
    required WidgetRef ref,
    required String analysisLabel,
    required IveInteractionRequest request,
    required Future<T> Function() action,
  }) async {
    // Codex adversarial review (Architecture-10 mission, round 1, P1,
    // ACCEPTED): the guard must be synchronous and set BEFORE any
    // `await`, or two taps arriving in the same event-loop turn can both
    // read `isBusy == false` before either sets it. This check-and-set
    // is exactly that — no await happens between the check and the
    // state transition below.
    if (isBusy) return null;
    _setState(AiExecutionState.awaitingConfirmation);

    QuotaInfoSnapshot? quota;
    try {
      final info = await ref.read(currentQuotaProvider.future);
      quota = QuotaInfoSnapshot(remaining: info.remaining, limit: info.limit);
    } catch (_) {
      // Quota read failure: proceed to confirmation with an unknown
      // remaining count rather than blocking the user — the server
      // reservation call below remains the real authority and will fail
      // safely on its own if quota is actually exhausted.
      quota = null;
    }
    if (!context.mounted) {
      _setState(AiExecutionState.idle);
      return null;
    }

    final confirmed = await _showConfirmationDialog(
      context: context,
      analysisLabel: analysisLabel,
      quota: quota,
    );

    ref.read(diagnosticLoggerProvider).logEvent(
      category: DiagnosticCategory.ai,
      eventName: confirmed
          ? 'ai_execution_confirmation_accepted'
          : 'ai_execution_confirmation_rejected',
      correlationId: request.correlationId,
      module: request.sourceModule,
      metadata: {
        if (request.projectId != null) 'project_id': request.projectId,
        if (request.sourceEntityType != null) 'source_entity_type': request.sourceEntityType,
        if (request.sourceEntityId != null) 'source_entity_id': request.sourceEntityId,
        'operation_type': request.operationType.name,
      },
    );

    if (!confirmed) {
      _setState(AiExecutionState.idle);
      return null;
    }

    // RESERVING_QUOTA / THINKING collapse into one observable phase — see
    // class doc: the actual Edge Function call is a single await with no
    // intermediate signal this client can observe.
    _setState(AiExecutionState.reservingQuota);
    ref.read(diagnosticLoggerProvider).logEvent(
      category: DiagnosticCategory.ai,
      eventName: 'ai_analysis_requested',
      correlationId: request.correlationId,
      module: request.sourceModule,
      metadata: {
        if (request.projectId != null) 'project_id': request.projectId,
        if (request.sourceEntityType != null) 'source_entity_type': request.sourceEntityType,
        if (request.sourceEntityId != null) 'source_entity_id': request.sourceEntityId,
      },
    );
    _setState(AiExecutionState.thinking);

    try {
      final result = await action();
      _setState(AiExecutionState.success);
      ref.read(diagnosticLoggerProvider).logEvent(
        category: DiagnosticCategory.ai,
        eventName: 'ai_analysis_succeeded',
        correlationId: request.correlationId,
        module: request.sourceModule,
        status: 'success',
      );
      return result;
    } catch (e) {
      _setState(AiExecutionState.error);
      // IVE-COMMERCIAL-FOUNDATION-11 (mission Section 10) — deliberately
      // does NOT log a `quota_refunded` event here: the client has no
      // way to know whether the server's own refund path actually ran
      // (that is server-authoritative, per docs/commercial/
      // IVE_INTERACTION_AND_QUOTA_CONTRACT.md §3.1). Inventing that event
      // client-side would violate Section 10's explicit rule against
      // "claiming backend outcomes the client cannot know."
      ref.read(diagnosticLoggerProvider).logEvent(
        category: DiagnosticCategory.ai,
        eventName: 'ai_analysis_failed',
        severity: DiagnosticSeverity.warn,
        correlationId: request.correlationId,
        module: request.sourceModule,
        status: 'failure',
        error: e,
      );
      rethrow;
    }
  }

  Future<bool> _showConfirmationDialog({
    required BuildContext context,
    required String analysisLabel,
    required QuotaInfoSnapshot? quota,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        title: const Text('Confirmar análise', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"$analysisLabel" vai consumir 1 das suas análises mensais.',
              style: const TextStyle(color: Colors.white70),
            ),
            if (quota != null) ...[
              const SizedBox(height: 8),
              Text(
                'Restam ${quota.remaining} de ${quota.limit} análises este mês.',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('CONFIRMAR'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class QuotaInfoSnapshot {
  const QuotaInfoSnapshot({required this.remaining, required this.limit});
  final int remaining;
  final int limit;
}

/// Subtle, consistent "thinking" indicator (mission Section 07) —
/// replaces each screen's ad hoc spinner/text combination with one
/// shared widget. A simple animated three-dot pulse, not a full custom
/// animation system: this is UI polish, not a new architecture surface.
class AiThinkingIndicator extends StatefulWidget {
  const AiThinkingIndicator({super.key, this.color = const Color(0xFFFFD93D), this.size = 6});
  final Color color;
  final double size;

  @override
  State<AiThinkingIndicator> createState() => _AiThinkingIndicatorState();
}

class _AiThinkingIndicatorState extends State<AiThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = (_ctrl.value - (i * 0.2)) % 1.0;
          final opacity = (0.3 + 0.7 * (1 - (t - 0.5).abs() * 2)).clamp(0.3, 1.0);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
              ),
            ),
          );
        }),
      ),
    );
  }
}
