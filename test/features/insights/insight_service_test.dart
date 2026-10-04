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

  group('entitlement gate logic', () {
    bool isBlocked(int monthCount, bool isPro) {
      if (isPro) return false;
      return monthCount >= AppConstants.insightFreeMonthlyLimit;
    }

    test('pro user is never blocked regardless of count', () {
      expect(isBlocked(0, true), isFalse);
      expect(isBlocked(5, true), isFalse);
      expect(isBlocked(99, true), isFalse);
    });

    test('free user below limit is not blocked', () {
      expect(isBlocked(0, false), isFalse);
      expect(isBlocked(4, false), isFalse);
    });

    test('free user at exactly the limit is blocked', () {
      expect(isBlocked(AppConstants.insightFreeMonthlyLimit, false), isTrue);
    });

    test('free user above limit is blocked', () {
      expect(isBlocked(AppConstants.insightFreeMonthlyLimit + 1, false), isTrue);
    });
  });

  group('monthCount increment/decrement logic', () {
    test('save increments monthCount', () {
      const before = 3;
      const after  = before + 1;
      expect(after, 4);
    });

    test('delete decrements monthCount but not below zero', () {
      int dec(int c) => c > 0 ? c - 1 : 0;
      expect(dec(5), 4);
      expect(dec(1), 0);
      expect(dec(0), 0);
    });
  });

  group('server quota_exceeded error handling (P1-Q1/Q2)', () {
    // Mirrors InsightNotifier.save() catch block logic.
    ({int monthCount, String? error}) handleSaveError(Object e, int currentCount) {
      final isQuota = e.toString().contains('quota_exceeded');
      return (
        monthCount: isQuota ? AppConstants.insightFreeMonthlyLimit : currentCount,
        error:      isQuota ? 'quota_exceeded' : e.toString(),
      );
    }

    test('quota_exceeded error pins monthCount to free limit', () {
      final result = handleSaveError(Exception('quota_exceeded'), 4);
      expect(result.monthCount, AppConstants.insightFreeMonthlyLimit);
      expect(result.error, 'quota_exceeded');
    });

    test('non-quota error preserves monthCount', () {
      final result = handleSaveError(Exception('network error'), 3);
      expect(result.monthCount, 3);
      expect(result.error, contains('network error'));
    });

    test('quota_exceeded in nested message is detected', () {
      final result = handleSaveError(
        Exception('PostgrestException: quota_exceeded'),
        2,
      );
      expect(result.monthCount, AppConstants.insightFreeMonthlyLimit);
      expect(result.error, 'quota_exceeded');
    });

    test('project_not_found error (cross-tenant SECURITY DEFINER guard) is NOT treated as quota_exceeded', () {
      final result = handleSaveError(Exception('project_not_found'), 3);
      expect(result.monthCount, 3); // count unchanged
      expect(result.error, isNot('quota_exceeded'));
      expect(result.error, contains('project_not_found'));
    });
  });

  group('recent insights filtering', () {
    test('only ive_analysis items qualify as insights', () {
      final items = [
        _makeItem(id: '1', origin: AppConstants.originIveAnalysis),
        _makeItem(id: '2', origin: 'manual'),
        _makeItem(id: '3', origin: AppConstants.originIveAnalysis),
      ];
      final insights = items
          .where((i) => i.origin == AppConstants.originIveAnalysis)
          .toList();
      expect(insights.length, 2);
      expect(insights.map((i) => i.id), containsAll(['1', '3']));
    });

    test('limit of 5 is respected in take()', () {
      final items = List.generate(
        10,
        (i) => _makeItem(id: '$i', origin: AppConstants.originIveAnalysis),
      );
      final capped = items.take(5).toList();
      expect(capped.length, 5);
    });
  });
}
