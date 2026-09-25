import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/profile_provider.dart';
import '../data/impact_lab_api.dart';

/// IV-IMPACT-I5 — shared building blocks of the Impact dossier UI.
///
/// Visual rule: status is ALWAYS text + icon, in neutral tones. No red/green
/// "good/bad" coding, no gauge, no score-like number: the dossier organizes
/// evidence, it never grades an organization.

/// Server language for the dossier labels, following the app locale.
String impactLang(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'pt';

IconData impactStatusIcon(String? status) => switch (status) {
      'SUPPORTED' => Icons.fact_check_outlined,
      'PARTIALLY_SUPPORTED' => Icons.rule_outlined,
      'CONTRADICTED' => Icons.compare_arrows,
      'INCONCLUSIVE' => Icons.more_horiz,
      'OUTDATED' => Icons.history,
      'DISPUTED' => Icons.forum_outlined,
      _ => Icons.help_outline,
    };

class ImpactChip extends StatelessWidget {
  const ImpactChip({super.key, required this.label, required this.icon, this.attention = false});

  final String label;
  final IconData icon;

  /// Draws the eye (open dispute, pending re-verification, limitation) —
  /// still neutral, never a verdict colour.
  final bool attention;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = attention ? scheme.secondaryContainer : scheme.surfaceContainerHighest;
    final fg = attention ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Flexible(child: Text(label, style: TextStyle(color: fg, fontSize: 13))),
          ],
        ),
      ),
    );
  }
}

class ImpactSection extends StatelessWidget {
  const ImpactSection({super.key, required this.title, required this.icon, required this.children, this.emphasis = false});

  final String title;
  final IconData icon;
  final List<Widget> children;

  /// Limitations / "does not establish" are shown with emphasis, never
  /// hidden behind a fold.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: emphasis ? theme.colorScheme.secondary : theme.colorScheme.outlineVariant,
          width: emphasis ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // container: true — otherwise the Card merges the whole section
            // into this one header node and a screen reader announces the
            // entire section as a heading.
            Semantics(
              header: true,
              container: true,
              child: Row(
                children: [
                  Icon(icon, size: 20, color: theme.colorScheme.secondary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// A line of body text with an optional leading icon.
class ImpactLine extends StatelessWidget {
  const ImpactLine(this.text, {super.key, this.icon, this.muted = false});

  final String text;
  final IconData? icon;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = muted
        ? theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)
        : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}

/// Text QUOTED from a source or an upload — visibly not a platform
/// statement. Withheld excerpts show only the fact they were withheld.
class ImpactQuote extends StatelessWidget {
  const ImpactQuote({
    super.key,
    required this.text,
    required this.attribution,
    this.redacted = false,
    this.withheld = false,
  });

  final String? text;
  final String? attribution;
  final bool redacted;
  final bool withheld;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final fromUpload = attribution == 'QUOTED_FROM_USER_UPLOAD';
    final caption = fromUpload ? t.impactQuotedFromUpload : t.impactQuotedFromSource;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: theme.colorScheme.outline, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (withheld || text == null)
            ImpactLine(t.impactWithheld, icon: Icons.visibility_off_outlined)
          else
            Text('«$text»', style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
          const SizedBox(height: 4),
          Text(caption, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          if (redacted)
            Text(t.impactRedactedNote, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

String impactErrorText(AppLocalizations t, Object error) {
  if (error is! ImpactApiException) return t.impactErrorServer;
  return switch (error.kind) {
    ImpactErrorKind.auth => t.impactErrorAuth,
    ImpactErrorKind.notAvailable => t.impactErrorNotAvailable,
    ImpactErrorKind.tooLarge => t.impactErrorTooLarge,
    ImpactErrorKind.rateLimited => t.impactErrorRateLimited(error.retryAfterSeconds ?? 60),
    ImpactErrorKind.network => t.impactErrorNetwork,
    ImpactErrorKind.contract => t.impactErrorContract,
    ImpactErrorKind.server || ImpactErrorKind.invalidRequest => t.impactErrorServer,
  };
}

class ImpactErrorView extends StatelessWidget {
  const ImpactErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final retryable = error is! ImpactApiException ||
        const {ImpactErrorKind.network, ImpactErrorKind.server, ImpactErrorKind.rateLimited}
            .contains((error as ImpactApiException).kind);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 32),
              const SizedBox(height: 12),
              Text(impactErrorText(t, error), textAlign: TextAlign.center),
              if (retryable && onRetry != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(onPressed: onRetry, child: Text(t.impactRetry)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen-level admin gate. Fail-closed: renders [child] only after the
/// profile positively resolved as admin. UX only — the real authority is
/// the admin entitlement inside impact-lab (and RLS below it).
class ImpactAdminGate extends ConsumerWidget {
  const ImpactAdminGate({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(currentProfileProvider);
    if (profileAsync.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final isAdmin = profileAsync.hasValue && !profileAsync.hasError && (profileAsync.value?.isAdmin ?? false);
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Padding(padding: const EdgeInsets.all(24), child: Text(t.impactAdminOnly, textAlign: TextAlign.center)),
        ),
      );
    }
    return child;
  }
}

/// Centered content with a readable max width on large screens.
class ImpactPage extends StatelessWidget {
  const ImpactPage({super.key, required this.child, this.maxWidth = 1280});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      );
}
