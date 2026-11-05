import 'package:flutter/material.dart';
import 'package:ai_social_copilot/core/theme/app_tokens.dart';

class ScoreChip extends StatelessWidget {
  final String label;
  final double score;

  const ScoreChip({super.key, required this.label, required this.score});

  Color _color() {
    if (score >= 8) return AppColors.positive;
    if (score >= 5) return AppColors.warning;
    return AppColors.negative;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _color().withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _color().withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text(
            score.toStringAsFixed(1),
            style: TextStyle(
              color: _color(),
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppColors.inkMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
