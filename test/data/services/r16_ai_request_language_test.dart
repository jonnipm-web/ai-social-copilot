import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/core/utils/language_utils.dart';
import 'package:ai_social_copilot/data/services/knowledge_service.dart';
import 'package:ai_social_copilot/data/services/post_service.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';
import 'package:ai_social_copilot/providers/auto_bootstrap_provider.dart';

// R16 — the PRESENTATION language decides the AI output language. These
// tests pin the request bodies sent to the Edge Functions so a regression
// back to `item.language` (source metadata) or a hard-coded 'pt-BR' fails.
void main() {
  group('R16 AI request bodies carry the presentation language', () {
    test('improve-post body sends the given output language', () {
      final body = buildImprovePostBody('Texto original em português', language: 'en-US');
      expect(body['language'], 'en-US');
      expect(body['text'], 'Texto original em português');
      expect(body.containsKey('idempotency_key'), isFalse);
    });

    test('improve-post body keeps the idempotency key when given', () {
      final body = buildImprovePostBody('Hello world text', language: 'pt-BR', idempotencyKey: 'k-1');
      expect(body['language'], 'pt-BR');
      expect(body['idempotency_key'], 'k-1');
    });

    test('extract-knowledge body uses output language, never a source language', () {
      // Source document is Portuguese; the UI is English -> output must be en-US.
      final body = buildExtractKnowledgeBody(
        content: 'Conteúdo do documento em português do Brasil.',
        outputLanguage: backendLanguageCodeForLocale(const Locale('en')),
      );
      expect(body['language'], 'en-US');
    });

    test('backendLanguageCodeForLocale maps pt/en locales', () {
      expect(backendLanguageCodeForLocale(const Locale('pt')), 'pt-BR');
      expect(backendLanguageCodeForLocale(const Locale('en')), 'en-US');
    });
  });

  group('R16 bootstrap progress text is localized', () {
    test('English', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        BootstrapState.buildProgressText(l10n, 1, 3, l10n.bootstrapStepGeneratingActions),
        'Project 1/3 — Generating actions',
      );
      expect(BootstrapState.buildProgressText(l10n, 2, 3, null), 'Project 2/3');
    });

    test('Portuguese', () {
      final l10n = lookupAppLocalizations(const Locale('pt'));
      expect(
        BootstrapState.buildProgressText(l10n, 1, 3, l10n.bootstrapStepGeneratingActions),
        'Projeto 1/3 — Gerando ações',
      );
    });
  });
}
