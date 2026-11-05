// IV-QUANT-MACRO-05 FASE 11 — Research/Advice boundary UI enforcement.
//
// Every screen that displays Quant output MUST include this widget.
// See docs/quant/QUANT_RESEARCH_ADVICE_BOUNDARY.md §5.
import 'package:flutter/material.dart';

/// Inline disclaimer shown below every Quant analysis output.
/// Tapping the ⓘ opens [QuantDisclaimerSheet].
class QuantDisclaimerBanner extends StatelessWidget {
  const QuantDisclaimerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 14, color: theme.colorScheme.outline),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Informational only. Not financial advice. '
              'Past performance ≠ future results.',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
          GestureDetector(
            onTap: () => showModalBottomSheet<void>(
              context: context,
              builder: (_) => const QuantDisclaimerSheet(),
            ),
            child: Icon(Icons.help_outline,
                size: 14, color: theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

/// Full disclaimer shown in a bottom sheet.
class QuantDisclaimerSheet extends StatelessWidget {
  const QuantDisclaimerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('About This Analysis',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(
              'InsightValues Quant calculates mathematical properties of '
              'historical market data. The results do not constitute financial '
              'advice, investment recommendations, or a solicitation to buy, '
              'sell, or hold any security.\n\n'
              'Always consult a qualified financial professional before making '
              'investment decisions. Past performance is not indicative of '
              'future results.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
