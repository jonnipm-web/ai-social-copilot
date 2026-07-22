import 'package:flutter/material.dart';

import '../../features/ive/domain/ive_copilot_contract.dart';

class IveResponseContextPanel extends StatelessWidget {
  final List<IveEvidence> evidence;
  final List<String> limitations;

  const IveResponseContextPanel({
    super.key,
    required this.evidence,
    required this.limitations,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 2),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (evidence.isNotEmpty) ...[
              const Text(
                'Evidências verificadas',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              ...evidence.map(_evidenceItem),
            ],
            if (limitations.isNotEmpty) ...[
              const SizedBox(height: 5),
              const Text(
                'Limitações desta resposta',
                style: TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              ...limitations.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '• $item',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ],
      ),
    );
  }

  Widget _evidenceItem(IveEvidence item) {
    final details = item.excerpt ??
        item.structuredValue?.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .join(' · ');
    final date = item.timestamp;
    final dateLabel = date == null
        ? null
        : '${date.day.toString().padLeft(2, '0')}/'
            '${date.month.toString().padLeft(2, '0')}/${date.year}';
    final relevance = '${(item.relevance * 100).round()}% relevante';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            [item.sourceTypeLabel, if (dateLabel != null) dateLabel, relevance]
                .join(' · '),
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
          if (details != null && details.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                details,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }
}
