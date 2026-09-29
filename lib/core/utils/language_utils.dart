import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/language_provider.dart';

/// R16 — GLOBAL END-TO-END LANGUAGE CONSISTENCY.
///
/// Three languages must never be confused (R16 §7):
///   * SOURCE language      — the language a user's own data/document is in
///                            (e.g. `knowledge_items.language`). Describes the
///                            data; it NEVER decides the language of output.
///   * PRESENTATION language — the language the user picked in the app
///                            (`languageProvider`, the single source of truth).
///   * AI OUTPUT language   — what the backend is asked to answer in. It is
///                            ALWAYS derived from the presentation language.
///
/// Every AI call site must use one of the helpers below — never an item's
/// `language` field and never a hard-coded 'pt-BR' default.

/// Maps a UI [Locale] to the code the Edge Functions accept ('pt-BR'/'en-US').
String backendLanguageCodeForLocale(Locale locale) =>
    locale.languageCode == 'en' ? 'en-US' : 'pt-BR';

/// Widget-side helper: AI output language for the locale currently rendered.
String backendLanguageCode(BuildContext context) =>
    backendLanguageCodeForLocale(Localizations.localeOf(context));

/// Provider-side AI output language — derived from [languageProvider], so any
/// provider that watches it rebuilds when the user switches language.
final outputLanguageCodeProvider = Provider<String>(
  (ref) => backendLanguageCodeForLocale(ref.watch(languageProvider)),
);

/// Localizations for code that has no BuildContext (services/providers that
/// build user-facing sentences deterministically). Watching it makes the
/// dependent provider recompute on a language switch, so no stale-language
/// text survives a PT↔EN change.
final appL10nProvider = Provider<AppLocalizations>(
  (ref) => lookupAppLocalizations(ref.watch(languageProvider)),
);

/// Human-readable language name, in the *presentation* language, for a
/// stored source/output language code ('pt-BR', 'en-US', 'es', ...).
String languageDisplayName(String? code, AppLocalizations l10n) {
  final c = (code ?? '').toLowerCase();
  if (c.startsWith('pt')) return l10n.r16LanguageNamePortuguese;
  if (c.startsWith('en')) return l10n.r16LanguageNameEnglish;
  if (c.startsWith('es')) return l10n.r16LanguageNameSpanish;
  return l10n.r16LanguageNameOther;
}
