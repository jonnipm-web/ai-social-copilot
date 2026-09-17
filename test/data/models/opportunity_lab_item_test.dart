import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/models/opportunity_lab_item.dart';

// COMMERCIAL-EXPERIENCE-CLOSURE-16 (mission Section 17/18) — knowledgeItemIds
// round-trip coverage. copyWith is exercised deliberately: adding a new
// field to a positional-style copyWith (every field re-listed explicitly in
// the constructor call) is exactly the kind of change that silently drops
// the new field if the author forgets to also add it inside copyWith's own
// body -- this test would have caught that class of bug.
void main() {
  OpportunityLabItem buildItem({List<String> knowledgeItemIds = const []}) => OpportunityLabItem(
        id:               'opp-1',
        userId:           'user-1',
        projectId:        'proj-1',
        title:            'Título',
        createdAt:        DateTime(2026, 1, 1),
        knowledgeItemIds: knowledgeItemIds,
      );

  test('toInsertMap includes knowledge_item_ids', () {
    final map = buildItem(knowledgeItemIds: ['k1', 'k2']).toInsertMap();
    expect(map['knowledge_item_ids'], ['k1', 'k2']);
  });

  test('fromMap parses knowledge_item_ids', () {
    final item = OpportunityLabItem.fromMap({
      'id':                 'opp-1',
      'user_id':            'user-1',
      'title':              'Título',
      'created_at':         '2026-01-01T00:00:00.000Z',
      'knowledge_item_ids': ['k1', 'k2'],
    });
    expect(item.knowledgeItemIds, ['k1', 'k2']);
  });

  test('fromMap defaults knowledge_item_ids to empty when absent (pre-migration rows)', () {
    final item = OpportunityLabItem.fromMap({
      'id':         'opp-1',
      'user_id':    'user-1',
      'title':      'Título',
      'created_at': '2026-01-01T00:00:00.000Z',
    });
    expect(item.knowledgeItemIds, isEmpty);
  });

  test('copyWith preserves knowledgeItemIds (no accidental reset to empty)', () {
    final item = buildItem(knowledgeItemIds: ['k1']);
    final copy = item.copyWith(status: 'approved');
    expect(copy.knowledgeItemIds, ['k1']);
    expect(copy.status, 'approved');
  });
}
