// MODULE-FOUNDATION-AND-ENTITLEMENT-02 — client cache of the server
// capability set is default-deny and cannot be "upgraded" by a forged or
// malformed payload.

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/core/utils/snackbar_utils.dart';
import 'package:ai_social_copilot/data/models/module_access.dart';

void main() {
  final valid = <String, dynamic>{
    'subject': {'type': 'user', 'plan': 'free', 'roles': <String>[]},
    'correlation_id': 'abc12345',
    'modules': [
      {'module_id': 'knowledge-vault', 'allowed': true},
      {'module_id': 'personas', 'allowed': false, 'code': 'MODULE_NOT_AVAILABLE'},
      {'module_id': 'pro-thing', 'allowed': false, 'code': 'PLAN_REQUIRED', 'required_plan': 'pro'},
    ],
  };

  test('parses allowed and denied modules', () {
    final a = ServerModuleAccess.fromMap(valid);
    expect(a.plan, 'free');
    expect(a.isAllowed('knowledge-vault'), isTrue);
    expect(a.isAllowed('personas'), isFalse);
    expect(a.modules['pro-thing']!.requiredPlan, 'pro');
    expect(a.allowedModuleIds, {'knowledge-vault'});
  });

  test('unknown module is denied (default deny)', () {
    expect(ServerModuleAccess.fromMap(valid).isAllowed('campaigns'), isFalse);
  });

  test('only a literal true grants; truthy-looking values do not', () {
    final a = ServerModuleAccess.fromMap({
      'subject': {'plan': 'free', 'roles': <String>[]},
      'modules': [
        {'module_id': 'a', 'allowed': 'true'},
        {'module_id': 'b', 'allowed': 1},
        {'module_id': 'c'},
        {'allowed': true},
        'not-a-map',
      ],
    });
    expect(a.allowedModuleIds, isEmpty);
  });

  test('malformed payload throws instead of producing an allow-all cache', () {
    expect(() => ServerModuleAccess.fromMap({'modules': <dynamic>[]}), throwsFormatException);
    expect(() => ServerModuleAccess.fromMap({'subject': <String, dynamic>{}, 'modules': 'all'}), throwsFormatException);
  });

  test('entitlement error codes are recognised and translated; quota stays separate', () {
    expect(entitlementErrorCode(Exception('PLAN_REQUIRED')), 'PLAN_REQUIRED');
    expect(isPlanRequiredError(Exception('PLAN_REQUIRED')), isTrue);
    expect(entitlementErrorCode(Exception('MODULE_NOT_AVAILABLE')), 'MODULE_NOT_AVAILABLE');
    expect(entitlementErrorCode(Exception('boom')), isNull);
    expect(extractErrorMessage(Exception('ENTITLEMENT_UNAVAILABLE')), contains('verificar'));
    expect(extractErrorMessage(Exception('QUOTA_EXCEEDED')), contains('limite'));
    expect(entitlementErrorCode(Exception('QUOTA_EXCEEDED')), isNull);
  });
}
