import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/l10n/app_localizations.dart';
import 'package:ai_social_copilot/providers/market_analysis_provider.dart';

// R16 — the Opportunity Lab rows auto-seeded from a market analysis are
// PERSISTED: their client-built text must be written in the user's current
// UI language, with AI fixed-value codes ("Alto"/"Médio"/"Baixo") mapped to
// localized labels.
void main() {
  final pt = lookupAppLocalizations(const Locale('pt'));
  final en = lookupAppLocalizations(const Locale('en'));

  const action = {
    'action': 'Launch a newsletter',
    'impact': 'Alto',
    'effort': 'Médio',
    'timeframe': '3-6 meses',
  };

  test('EN UI → English seed text, no Portuguese', () {
    final t = buildOpportunitySeedTexts(action, 'example.com', en);
    expect(t.description, 'Impact: High · Effort: Medium');
    expect(t.rationale,
        'Identified by Market Intelligence based on the analysis of example.com.');
    expect(t.risks, ['Effort: Medium']);
    expect(t.actionSteps, ['Estimated timeframe: 3-6 months']);
    final all = [t.description, t.rationale, ...t.risks, ...t.actionSteps].join(' ');
    for (final w in ['Impacto', 'Esforço', 'Prazo', 'Identificado', 'Médio', 'Alto', 'meses']) {
      expect(all.contains(w), isFalse, reason: 'leaked PT word: $w');
    }
  });

  test('PT UI → Portuguese seed text', () {
    final t = buildOpportunitySeedTexts(action, 'example.com', pt);
    expect(t.description, 'Impacto: Alto · Esforço: Médio');
    expect(t.rationale,
        'Identificado pelo Market Intelligence com base na análise de example.com.');
    expect(t.risks, ['Esforço: Médio']);
    expect(t.actionSteps, ['Prazo estimado: 3-6 meses']);
  });

  test('missing fields → localized N/A and empty lists', () {
    final t = buildOpportunitySeedTexts(const {'action': 'x'}, 'in', en);
    expect(t.description, 'Impact: N/A · Effort: N/A');
    expect(t.risks, isEmpty);
    expect(t.actionSteps, isEmpty);
    final tp = buildOpportunitySeedTexts(const {'action': 'x'}, 'in', pt);
    expect(tp.description, 'Impacto: N/D · Esforço: N/D');
  });

  test('AI-provided rationale is kept verbatim', () {
    final t = buildOpportunitySeedTexts(
        const {'action': 'x', 'rationale': 'Because demand is rising.'}, 'in', pt);
    expect(t.rationale, 'Because demand is rising.');
  });
}
