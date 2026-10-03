import 'package:flutter/material.dart';

import '../../../data/models/opportunity_lab_item.dart';
import '../../../l10n/app_localizations.dart';

class InsightCard extends StatelessWidget {
  const InsightCard({
    super.key,
    required this.item,
    this.onAddToActions,
    this.onDelete,
    this.elevated = false,
  });

  final OpportunityLabItem item;
  final VoidCallback? onAddToActions;
  final VoidCallback? onDelete;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: elevated ? const Color(0xFF1E1E35) : const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
        ),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.psychology_rounded,
                    color: Color(0xFF6C63FF), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                _ConfidenceBadge(confidence: item.confidence),
              ],
            ),
          ),
          if (item.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Text(
                item.description,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          if (item.sources.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: _SourcesRow(label: t.insightSources, sources: item.sources),
            ),
          if (item.actionSteps.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.insightRecommendedAction,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                  const SizedBox(height: 4),
                  ...item.actionSteps.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ',
                                style: TextStyle(
                                    color: Color(0xFF6BCB77), fontSize: 12)),
                            Expanded(
                              child: Text(s,
                                  style: const TextStyle(
                                      color: Colors.white60, fontSize: 12)),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Row(
              children: [
                Text(
                  _fmtDate(item.createdAt),
                  style: const TextStyle(color: Colors.white24, fontSize: 11),
                ),
                const Spacer(),
                if (onAddToActions != null)
                  _SmallBtn(
                    icon: Icons.add_task_rounded,
                    label: t.insightAddToActions,
                    color: const Color(0xFF6BCB77),
                    onTap: onAddToActions!,
                  ),
                if (onDelete != null)
                  _SmallBtn(
                    icon: Icons.delete_outline_rounded,
                    label: '',
                    color: const Color(0xFFFF6B6B),
                    onTap: onDelete!,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.confidence});
  final int confidence;

  Color get _color {
    if (confidence >= 80) return const Color(0xFF6BCB77);
    if (confidence >= 50) return const Color(0xFFFFD93D);
    return const Color(0xFFFF6B6B);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$confidence%',
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SourcesRow extends StatelessWidget {
  const _SourcesRow({required this.label, required this.sources});
  final String label;
  final List<String> sources;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: sources
              .take(4)
              .map(
                (s) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(s,
                      style: const TextStyle(
                          color: Color(0xFFAB83FF), fontSize: 10)),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _SmallBtn extends StatelessWidget {
  const _SmallBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 14),
      label: label.isNotEmpty
          ? Text(label, style: const TextStyle(fontSize: 11))
          : const SizedBox.shrink(),
    );
  }
}
