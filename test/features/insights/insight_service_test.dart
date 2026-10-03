import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/core/constants/app_constants.dart';
import 'package:ai_social_copilot/data/models/copilot_turn.dart';
import 'package:ai_social_copilot/data/models/opportunity_lab_item.dart';

// Unit tests for InsightService business logic that doesn't touch Supabase.
// DB integration tests (Supabase) require a live project — deferred.

// Mirrors the private helper in InsightService so logic can be tested standalone.
String _titleFromQuestion(String q) {
  final trimmed = q.trim();
  return trimmed.length <= 60 ? trimmed : '${trimmed.substring(0, 57)}…';
}

List<String> _actionStepsFromSuggestion(CopilotActionSuggestion? s) {
  if (s == null) return [];
  return [s.label];
}

OpportunityLabItem _makeItem({
  String id = 'fake-id',
  String origin = AppConstants.originIveAnalysis,
  String title  = 'Fake insight',
}) =>
    OpportunityLabItem(
      id:        id,
      userId:    'uid',
      title:     title,
      origin:    origin,
      createdAt: DateTime(2026, 10, 3),
    );

void main() {
  group('title truncation', () {
    test('short question used verbatim', () {
      const q = 'Qual o potencial de crescimento?';
      expect(_titleFromQuestion(q), q);
    });

    test('exactly 60 chars used verbatim', () {
      final q = 'a' * 60;
      expect(_titleFromQuestion(q), q);
    });

    test('question over 60 chars truncated with ellipsis', () {
      final q = 'a' * 80;
      final title = _titleFromQuestion(q);
      expect(title.length, 58); // 57 + '…'
      expect(title.endsWith('…'), isTrue);
    });

    test('whitespace-only question trims to empty', () {
      expect(_titleFromQuestion('   '), '');
    });
  });

  group('action steps from suggestion', () {
    test('null suggestion produces empty list', () {
      expect(_actionStepsFromSuggestion(null), isEmpty);
    });

    test('suggestion with label produces single-element list', () {
      final s = CopilotActionSuggestion(
        type:  'create_action',
        label: 'Criar plano de expansão',
        data:  {},
      );
      expect(_actionStepsFromSuggestion(s), ['Criar plano de expansão']);
    });
  });

  group('originIveAnalysis constant', () {
    test('constant value is ive_analysis', () {
      expect(AppConstants.originIveAnalysis, 'ive_analysis');
    });

    test('item created with correct origin', () {
      final item = _makeItem();
      expect(item.origin, AppConstants.originIveAnalysis);
    });

    test('manually-created item does NOT have insight origin', () {
      final item = _makeItem(origin: 'manual');
      expect(item.origin, isNot(AppConstants.originIveAnalysis));
    });
  });

  group('insightFreeMonthlyLimit constant', () {
    test('free limit is 5', () {
      expect(AppConstants.insightFreeMonthlyLimit, 5);
    });
  });

  group('CopilotTurn model for insight creation', () {
    test('turn without action suggestion: actionSuggestion is null', () {
      final turn = CopilotTurn(
        role:       'assistant',
        content:    'Análise concluída.',
        confidence: 85,
        sources:    ['doc-1'],
        timestamp:  DateTime(2026, 10, 3),
      );
      expect(turn.actionSuggestion, isNull);
      expect(turn.confidence, 85);
      expect(turn.sources, ['doc-1']);
    });

    test('turn with action suggestion exposes label', () {
      final turn = CopilotTurn(
        role:    'assistant',
        content: 'Análise com ação.',
        actionSuggestion: CopilotActionSuggestion(
          type:  'add_to_actions',
          label: 'Lançar campanha de email',
          data:  {'priority': 'high'},
        ),
        timestamp: DateTime(2026, 10, 3),
      );
      expect(turn.actionSuggestion!.label, 'Lançar campanha de email');
    });
  });

  group('insight list management logic', () {
    test('filtering by id removes correct item', () {
      final a = _makeItem(id: 'a');
      final b = _makeItem(id: 'b');
      final items = [a, b];
      final after = items.where((i) => i.id != 'a').toList();
      expect(after.length, 1);
      expect(after.first.id, 'b');
    });

    test('prepending new item puts it first', () {
      final existing = _makeItem(id: 'old', title: 'Old insight');
      final fresh    = _makeItem(id: 'new', title: 'New insight');
      final updated  = [fresh, existing];
      expect(updated.first.id, 'new');
      expect(updated.last.id, 'old');
    });
  });
}
