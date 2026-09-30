import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/core/constants/app_constants.dart';

// COMMERCIAL-V1-PHYSICAL-QA-RECOVERY (PQ-03) — AppConstants.planLimits is
// read by ProfileService.updateRole() and written directly to
// profiles.monthly_limit when an admin manually changes a user's role.
// Found stale during this mission's audit: 'pro' said 100 (real value is
// 300, per supabase/functions/stripe-webhook/index.ts's PRO_ROLE_LIMIT).
// IV-MAIN-RECONCILIATION-01 (2026-09-30): FREE=5 is the current commercial
// decision. Migration 20261014000000_free_quota_15.sql is DO_NOT_APPLY.
// Server (profiles.monthly_limit default) = 5. Client must mirror.
void main() {
  test('planLimits mirrors the server-side entitlement values exactly', () {
    expect(AppConstants.planLimits['admin'], 99999);
    expect(AppConstants.planLimits['premium'], 1000);
    expect(AppConstants.planLimits['pro'], 300);
    expect(AppConstants.planLimits['beta_tester'], 50);
    expect(AppConstants.planLimits['free'], 5);
  });

  test('limitForRole falls back to the FREE limit (5) for an unmapped role', () {
    expect(AppConstants.limitForRole('unknown_future_role'), 5);
  });

  test('limitForRole resolves every known role to its mapped value', () {
    for (final role in AppConstants.planLimits.keys) {
      expect(AppConstants.limitForRole(role), AppConstants.planLimits[role]);
    }
  });
}
