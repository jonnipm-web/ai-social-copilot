import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/features/action_engine/screens/action_engine_screen.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';

// COMMERCIAL-V1-PHYSICAL-QA-RECOVERY (section 6 spot-check) -- found
// action_detail_screen.dart's _TypeBadge rendering item.actionType
// .toUpperCase() raw (same bug class as PQ-05's competitor.type).
void main() {
  test('actionEngineTypeLabel maps known canonical values, PT and EN', () async {
    final pt = await AppLocalizations.delegate.load(const Locale('pt'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));

    expect(actionEngineTypeLabel(pt, 'task'), 'Tarefa');
    expect(actionEngineTypeLabel(pt, 'opportunity'), 'Oportunidade');
    expect(actionEngineTypeLabel(en, 'task'), 'Task');
    expect(actionEngineTypeLabel(en, 'opportunity'), 'Opportunity');
  });

  test('unmapped/legacy actionType falls back to itself rather than throwing', () async {
    final pt = await AppLocalizations.delegate.load(const Locale('pt'));
    expect(actionEngineTypeLabel(pt, 'valor-legado-desconhecido'), 'valor-legado-desconhecido');
  });
}
