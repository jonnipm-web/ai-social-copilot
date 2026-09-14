import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/core/utils/uuid_v4.dart';

void main() {
  final uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  test('newUuidV4 produces a valid, lowercase RFC 4122 v4 UUID shape', () {
    for (var i = 0; i < 200; i++) {
      final id = newUuidV4();
      expect(id, matches(uuidPattern), reason: '"$id" is not a valid v4 UUID shape');
    }
  });

  test('newUuidV4 does not repeat across many calls (collision-free in practice)', () {
    final seen = <String>{};
    for (var i = 0; i < 1000; i++) {
      seen.add(newUuidV4());
    }
    expect(seen.length, 1000);
  });
}
