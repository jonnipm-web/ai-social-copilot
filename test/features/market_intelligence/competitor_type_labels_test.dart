import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/features/market_intelligence/competitor_type_labels.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';

// COMMERCIAL-V1-PHYSICAL-QA-RECOVERY (PQ-05) -- the Owner physically found
// "ASPIRATIONAL"/"DIRECT"/"INDIRECT" rendered verbatim in the PT-BR
// Competitor Discovery screen (competitor.type.toUpperCase() shown raw).
// Same explicit-expected-value pattern as
// test/features/opportunity_lab/opportunity_type_labels_test.dart.
void main() {
  const expectedPt = {
    'direct':       'Direto',
    'indirect':     'Indireto',
    'aspirational': 'Aspiracional',
  };

  const expectedEn = {
    'direct':       'Direct',
    'indirect':     'Indirect',
    'aspirational': 'Aspirational',
  };

  test('kCompetitorTypes is exactly the set this test covers', () {
    expect(kCompetitorTypes.toSet(), expectedPt.keys.toSet());
    expect(kCompetitorTypes.toSet(), expectedEn.keys.toSet());
  });

  test('every canonical type maps to the exact expected PT-BR label (never the raw English value)', () async {
    final pt = await AppLocalizations.delegate.load(const Locale('pt'));
    for (final canonical in kCompetitorTypes) {
      expect(competitorTypeLabel(canonical, pt), expectedPt[canonical],
          reason: 'unexpected PT label for "$canonical" -- if this shows the raw '
              'English value ("direct"/"indirect"/"aspirational"), PQ-05 regressed');
    }
  });

  test('every canonical type maps to the exact expected EN label', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    for (final canonical in kCompetitorTypes) {
      expect(competitorTypeLabel(canonical, en), expectedEn[canonical],
          reason: 'unexpected EN label for "$canonical"');
    }
  });

  test('unmapped/legacy value falls back to itself rather than throwing', () async {
    final pt = await AppLocalizations.delegate.load(const Locale('pt'));
    expect(competitorTypeLabel('valor-legado-desconhecido', pt), 'valor-legado-desconhecido');
  });
}
