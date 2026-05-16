import 'package:flutter/material.dart';

class ScoreChip extends StatelessWidget {
  final String label;
  final double score;

  const ScoreChip({super.key, required this.label, required this.score});

  Color _color() {
    if (score >= 8) return const Color(0xFF4CAF50);
    if (score >= 5) return const Color(0xFFFFC107);
    return const Color(0xFFEF5350);
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
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
