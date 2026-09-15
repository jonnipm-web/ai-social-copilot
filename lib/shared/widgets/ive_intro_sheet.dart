import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/diagnostics/diagnostic_models.dart';
import '../../features/ive/visual/ive_avatar.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/diagnostic_session_provider.dart';
import '../../providers/ive_intro_provider.dart';

// IVE-EXPERIENCE-V1-06 (Sections 13-19) — first-use "Meet IVE" experience.
// TEXT-FIRST, VIDEO-READY: this sheet renders correctly with zero video
// asset (there is none in this repo today, see mission report Section 12) —
// a future video slot can be added above the text without restructuring
// this widget, but nothing here depends on one existing.
//
// Reuses IveAvatar (the same frozen-Rive-safe fallback visual FALLBACK-04
// ships) non-interactively, the app's existing l10n infrastructure for
// EN/PT-BR, and the existing DiagnosticCategory.ive event vocabulary for
// analytics — no new chat surface, no new avatar, no new persistence
// subsystem (see ive_intro_provider.dart).
Future<void> showIveIntroSheet(BuildContext context, {required String trigger}) async {
  final ref = ProviderScope.containerOf(context);
  ref.read(diagnosticSessionProvider.notifier).logEvent(
        category:  DiagnosticCategory.ive,
        eventName: 'ive_intro_started',
        operation: trigger,
      );

  var actionTaken = false;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // IVE-EXPERIENCE-V1-06 (Section 14) — "never trap user in onboarding":
    // dismissible via the system back gesture/barrier tap, not just the
    // explicit SKIP button. Treated the same as an explicit skip below
    // (whenComplete), so there is no state where dismissing any other way
    // leaves the intro permanently "undecided" and re-nagging the user.
    isDismissible: true,
    enableDrag: true,
    builder: (sheetContext) => _IveIntroSheetContent(
      onContinue: () {
        actionTaken = true;
        ref.read(iveIntroProvider.notifier).complete();
        ref.read(diagnosticSessionProvider.notifier).logEvent(
              category:  DiagnosticCategory.ive,
              eventName: 'ive_intro_completed',
              operation: trigger,
            );
        Navigator.of(sheetContext).pop();
      },
      onSkip: () {
        actionTaken = true;
        ref.read(iveIntroProvider.notifier).skip();
        ref.read(diagnosticSessionProvider.notifier).logEvent(
              category:  DiagnosticCategory.ive,
              eventName: 'ive_intro_skipped',
              operation: trigger,
            );
        Navigator.of(sheetContext).pop();
      },
    ),
  );

  if (!actionTaken) {
    // Dismissed via back gesture/barrier tap rather than a button — treat as
    // a skip so the sheet does not reappear on every screen/app open.
    ref.read(iveIntroProvider.notifier).skip();
    ref.read(diagnosticSessionProvider.notifier).logEvent(
          category:  DiagnosticCategory.ive,
          eventName: 'ive_intro_skipped',
          operation: trigger,
        );
  }
}

class _IveIntroSheetContent extends StatelessWidget {
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  const _IveIntroSheetContent({required this.onContinue, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Semantics(
      label: l10n.ivIntroSemanticLabel,
      container: true,
      child: DraggableScrollableSheet(
        initialChildSize: 0.62,
        minChildSize:      0.45,
        maxChildSize:       0.92,
        expand: false,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1B2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width:  40,
                  height: 4,
                  decoration: BoxDecoration(
                    color:        Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const IveAvatar(
                        size:           IveAvatarSize.large,
                        showStatusRing: false,
                        interactive:    false,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.ivIntroTitle,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color:      Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      _paragraph(l10n.ivIntroWhoBody),
                      _paragraph(l10n.ivIntroWhatBody),
                      _paragraph(l10n.ivIntroWhereBody),
                      _paragraph(l10n.ivIntroControlBody),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  24, 8, 24, MediaQuery.of(context).viewPadding.bottom + 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: onSkip,
                        child: Text(
                          l10n.ivIntroSkipButton,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: onContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          l10n.ivIntroContinueButton,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paragraph(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
      );
}
