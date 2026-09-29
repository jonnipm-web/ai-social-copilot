import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/models/market_analysis.dart';
import 'package:ai_social_copilot/data/models/opportunity_lab_item.dart';
import 'package:ai_social_copilot/data/models/project.dart';
import 'package:ai_social_copilot/data/services/content_localization_service.dart';

// R16 — presentation localization of persisted content: the merge must
// overlay translated presentation columns on a COPY of the row, never touch
// the original map, keep codes/scores intact and, for projects, keep the
// original description editable (side-by-side column).
void main() {
  final oppRow = <String, dynamic>{
    'id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'user_id': 'u1',
    'title': 'Expandir para o Brasil',
    'description': 'Projeto voltado a dispositivos RCBO',
    'opportunity_type': 'expansão',
    'final_score': 82,
    'status': 'pending',
    'created_at': '2026-09-01T00:00:00Z',
  };

  test('translated payload replaces presentation columns on a copy', () {
    final entry = debugLocalizedEntry('pt-BR', {
      'title': 'Expand into Brazil',
      'description': 'Project focused on RCBO devices',
    });
    final merged = mergeLocalized('opportunity_lab', oppRow, entry, 'en-US');

    expect(merged['title'], 'Expand into Brazil');
    expect(merged[kLocalizedFromKey], 'pt-BR');
    expect(merged['opportunity_type'], 'expansão'); // canonical code untouched
    expect(merged['final_score'], 82); // score untouched
    expect(oppRow['title'], 'Expandir para o Brasil'); // original not mutated
    expect(merged['${kOriginalPrefix}title'], 'Expandir para o Brasil'); // original kept for logic

    final item = OpportunityLabItem.fromMap(merged);
    expect(item.title, 'Expand into Brazil');
    expect(item.localizedFrom, 'pt-BR');
    expect(item.finalScore, 82);
  });

  test('row already in the presentation language is returned unchanged', () {
    final entry = debugLocalizedEntry('en-US', {'title': 'Same'});
    final merged = mergeLocalized('opportunity_lab', oppRow, entry, 'en-US');
    expect(identical(merged, oppRow), isTrue);
    expect(OpportunityLabItem.fromMap(merged).localizedFrom, isNull);
  });

  test('unknown detected source language still marks the row as translated (R16 §9)', () {
    final entry = debugLocalizedEntry(null, {'title': 'Expand into Brazil'});
    final merged = mergeLocalized('opportunity_lab', oppRow, entry, 'en-US');
    expect(merged[kLocalizedFromKey], 'und');
    expect(OpportunityLabItem.fromMap(merged).localizedFrom, 'und');
  });

  test('market analysis keeps the original niche for language-independent logic (R16 §20)', () {
    final row = <String, dynamic>{
      'id': 'm1', 'user_id': 'u1', 'input': 'rcbo', 'niche': 'Dispositivos elétricos',
      'created_at': '2026-09-01T00:00:00Z', 'updated_at': '2026-09-01T00:00:00Z',
    };
    final merged = mergeLocalized('market_analyses', row,
        debugLocalizedEntry('pt-BR', {'niche': 'Electrical devices'}), 'en-US');
    final a = MarketAnalysis.fromMap(merged);
    expect(a.niche, 'Electrical devices');
    expect(a.nicheOriginal, 'Dispositivos elétricos');
    expect(MarketAnalysis.fromMap(row).nicheOriginal, 'Dispositivos elétricos');
  });

  test('missing/failed localization falls back to the original row', () {
    expect(identical(mergeLocalized('opportunity_lab', oppRow, null, 'en-US'), oppRow), isTrue);
    final empty = debugLocalizedEntry(null, {});
    expect(identical(mergeLocalized('opportunity_lab', oppRow, empty, 'en-US'), oppRow), isTrue);
  });

  test('projects keep the ORIGINAL description editable (side-by-side)', () {
    final projectRow = <String, dynamic>{
      'id': 'p1',
      'user_id': 'u1',
      'name': 'RCBO Brasil',
      'description': 'Projeto voltado à introdução e expansão do uso de dispositivos RCBO',
      'created_at': '2026-09-01T00:00:00Z',
      'updated_at': '2026-09-02T00:00:00Z',
    };
    final entry = debugLocalizedEntry('pt-BR', {
      'description': 'Project focused on introducing and expanding the use of RCBO devices',
    });
    final merged = mergeLocalized('projects', projectRow, entry, 'en-US');
    final project = Project.fromMap(merged);

    expect(project.description, startsWith('Projeto voltado')); // original kept for edit forms
    expect(project.presentedDescription, startsWith('Project focused')); // display uses translation
    expect(project.name, 'RCBO Brasil'); // proper noun never translated
    expect(project.localizedFrom, 'pt-BR');
  });

  test('identityLocalizer returns rows untouched', () async {
    final rows = [oppRow];
    expect(await identityLocalizer('opportunity_lab', rows), same(rows));
  });
}
