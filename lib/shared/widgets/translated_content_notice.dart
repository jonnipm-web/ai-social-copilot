import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/language_utils.dart';
import '../../data/services/content_localization_service.dart';
import '../../l10n/app_localizations.dart';

/// R16 §9 — makes cross-language content EXPLICIT instead of an accidental
/// language leak:
///   * translated presentation -> "Automatically translated from Portuguese ·
///     View original";
///   * original mode (user choice) -> "Showing original content · View
///     translation".
/// Renders nothing when the content is already in the presentation language.
class TranslatedContentNotice extends ConsumerWidget {
  const TranslatedContentNotice({super.key, required this.localizedFrom, this.padding});

  /// Detected source language of the displayed row (null = not translated).
  final String? localizedFrom;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showOriginal = ref.watch(showOriginalContentProvider);
    if (!showOriginal && localizedFrom == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final message = showOriginal
        ? l10n.r16ShowingOriginalContent
        : l10n.r16TranslatedFrom(languageDisplayName(localizedFrom, l10n));
    final action = showOriginal ? l10n.r16ViewTranslation : l10n.r16ViewOriginal;

    return Padding(
      padding: padding ?? const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            const Icon(Icons.translate, size: 16, color: Colors.white54),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ),
            TextButton(
              key: const Key('r16_toggle_original'),
              onPressed: () =>
                  ref.read(showOriginalContentProvider.notifier).state = !showOriginal,
              child: Text(action, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
