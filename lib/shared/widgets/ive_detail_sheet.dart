import 'package:flutter/material.dart';

import 'context_copilot_widget.dart';

/// Generic drill-down sheet IVE opens when user taps any data item.
class IveDetailSheet extends StatelessWidget {
  final String title;
  final String emoji;
  final String humanExplanation;
  final List<IveEvidence> evidence;
  final List<IveAction> suggestedActions;
  final Map<String, dynamic>? expandedData;
  final String screenName;

  const IveDetailSheet({
    super.key,
    required this.title,
    required this.emoji,
    required this.humanExplanation,
    this.evidence = const [],
    this.suggestedActions = const [],
    this.expandedData,
    this.screenName = '',
  });

  static void show(
    BuildContext context, {
    required String title,
    required String emoji,
    required String humanExplanation,
    List<IveEvidence> evidence = const [],
    List<IveAction> suggestedActions = const [],
    Map<String, dynamic>? expandedData,
    String screenName = '',
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => IveDetailSheet(
        title: title,
        emoji: emoji,
        humanExplanation: humanExplanation,
        evidence: evidence,
        suggestedActions: suggestedActions,
        expandedData: expandedData,
        screenName: screenName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.60,
      minChildSize: 0.40,
      maxChildSize: 0.92,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1635),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _handle(),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  _header(context),
                  const SizedBox(height: 16),
                  _explanation(),
                  if (evidence.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _evidenceSection(),
                  ],
                  if (expandedData != null && expandedData!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _expandedSection(),
                  ],
                  if (suggestedActions.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _actionsSection(context),
                  ],
                  const SizedBox(height: 16),
                  _askIveButton(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _handle() => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _header(BuildContext context) => Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white38),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );

  Widget _explanation() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2450),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('💬', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              const Text(
                'Explicação IVE',
                style: TextStyle(
                    color: Color(0xFF6C63FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              humanExplanation,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      );

  Widget _evidenceSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Evidências',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...evidence.map((e) => _evidenceCard(e)),
        ],
      );

  Widget _evidenceCard(IveEvidence e) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF12101E),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.label,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(e.value,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _expandedSection() => ExpansionTile(
        title: const Text(
          'Números e fórmulas',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        iconColor: Colors.white38,
        collapsedIconColor: Colors.white24,
        tilePadding: EdgeInsets.zero,
        children: expandedData!.entries
            .map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(e.key,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 12))),
                      Text(e.value.toString(),
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12)),
                    ],
                  ),
                ))
            .toList(),
      );

  Widget _actionsSection(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ações sugeridas',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...suggestedActions.map((a) => _actionTile(context, a)),
        ],
      );

  Widget _actionTile(BuildContext context, IveAction action) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        leading: Text(action.emoji, style: const TextStyle(fontSize: 20)),
        title: Text(action.label,
            style: const TextStyle(color: Colors.white, fontSize: 13)),
        subtitle: action.description != null
            ? Text(action.description!,
                style: const TextStyle(color: Colors.white38, fontSize: 11))
            : null,
        trailing: action.onTap != null
            ? IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: Color(0xFF6C63FF)),
                onPressed: () {
                  Navigator.of(context).pop();
                  action.onTap!();
                },
              )
            : null,
      );

  Widget _askIveButton(BuildContext context) => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF6C63FF),
            side: const BorderSide(color: Color(0xFF6C63FF)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Text('💬', style: TextStyle(fontSize: 16)),
          label: const Text('Perguntar mais ao Copilot'),
          onPressed: () {
            Navigator.of(context).pop();
            openIveChat(
              context,
              screenName: screenName.isNotEmpty ? screenName : title,
            );
          },
        ),
      );
}

// ── Data classes ──────────────────────────────────────────────────────────────

class IveEvidence {
  final String emoji;
  final String label;
  final String value;

  const IveEvidence({
    required this.emoji,
    required this.label,
    required this.value,
  });
}

class IveAction {
  final String emoji;
  final String label;
  final String? description;
  final VoidCallback? onTap;

  const IveAction({
    required this.emoji,
    required this.label,
    this.description,
    this.onTap,
  });
}
