import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/action_queue_item.dart';
import '../../../data/models/aef_runtime.dart';
import '../../../data/services/aef_runtime_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/action_queue_provider.dart';
import '../../../shared/widgets/aef_action_card.dart';

/// INSIGHTVALUES-PRODUCTIZATION-MACRO-03 — Action Engine's governed
/// "execute" flow. Reuses the SAME Human Gate card the IVE chat surface
/// already ships (AefActionCard) rather than building a parallel UI, per
/// this macro's own instruction to integrate the existing experience
/// coherently rather than duplicate it.
///
/// Opened as a modal sheet from action_detail_screen.dart /
/// action_engine_screen.dart in place of the old, ungoverned
/// `notifier.execute()`/`notifier.complete()` direct status writes. Once
/// the card reaches a terminal, receipted result, this persists it via
/// ActionQueueNotifier.applyGovernedResult — never a client-invented
/// status.
class ActionEngineExecuteSheet extends ConsumerWidget {
  const ActionEngineExecuteSheet({super.key, required this.item});

  final ActionQueueItem item;

  static Future<void> show(BuildContext context, ActionQueueItem item) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ActionEngineExecuteSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final api = ref.read(actionEngineRuntimeApiProvider);
    final notifier = ref.read(actionQueueNotifierProvider.notifier);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                l.actionEngineExecuteSheetIntro,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              AefActionCard(
                intent: IveActionIntentData(
                  capabilityId: 'action-engine',
                  requestedAction: 'complete_action',
                  projectId: item.projectId,
                  riskClass: 'CONSEQUENTIAL',
                  contextRef: item.id,
                ),
                api: api,
                title: l.aefLabTitleActionEngine,
                initialValues: {
                  'action_id': item.id,
                  'summary': item.title,
                },
                onResult: (result) {
                  // Only a receipted outcome (SUCCESS/FAILURE/PARTIAL/
                  // NOT_EXECUTED/UNKNOWN_OUTCOME) carries real information
                  // to persist. A REJECTED/EXPIRED/CANCELLED/INVALIDATED/
                  // DENIED result means nothing ran and nothing changed —
                  // action_queue is deliberately left exactly as it was.
                  if (result.receiptOutcome != null) {
                    // Fire-and-forget from the sheet's perspective: the
                    // notifier reloads the list; a failure here surfaces
                    // through the same IveEventBus every other mutation uses.
                    notifier.applyGovernedResult(item.id, result, title: item.title);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
