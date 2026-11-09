import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/models/action_queue_item.dart';

// HANDOFF action-detail §2 — bootstrap-created actions were stored with the
// default origin 'manual' plus an opportunity id, and the detail page said
// "Adicionado manualmente". effectiveOrigin reads that combination (which
// no manual path produces) as 'auto_bootstrap'.
ActionQueueItem _item({String origin = 'manual', String? opp}) =>
    ActionQueueItem(
      id: 'a1',
      userId: 'u1',
      title: 'Criar curso',
      createdAt: DateTime(2026, 7, 15),
      origin: origin,
      opportunityLabId: opp,
    );

void main() {
  test('manual + opportunity id is read as auto_bootstrap', () {
    expect(_item(opp: 'opp-1').effectiveOrigin, 'auto_bootstrap');
  });

  test('a truly manual action stays manual', () {
    expect(_item().effectiveOrigin, 'manual');
  });

  test('explicit origins are never rewritten', () {
    expect(_item(origin: 'opportunity_lab', opp: 'opp-1').effectiveOrigin,
        'opportunity_lab');
    expect(_item(origin: 'auto_bootstrap', opp: 'opp-1').effectiveOrigin,
        'auto_bootstrap');
  });
}
