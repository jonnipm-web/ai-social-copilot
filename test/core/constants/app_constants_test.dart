import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/core/constants/app_constants.dart';

// COMMERCIAL-V1-PHYSICAL-QA-RECOVERY (PQ-03) — AppConstants.planLimits is
// read by ProfileService.updateRole() and written directly to
// profiles.monthly_limit when an admin manually changes a user's role.
// Found stale during this mission's audit: 'pro' said 100 (real value is
// 300, per supabase/functions/stripe-webhook/index.ts's PRO_ROLE_LIMIT).
// FREE=15 per Owner decision 2026-09-30. Migration
// 20261014000000_free_quota_15.sql (LAB) carries this value for the server.
void main() {
  test('planLimits mirrors the server-side entitlement values exactly', () {
    expect(AppConstants.planLimits['admin'], 99999);
    expect(AppConstants.planLimits['premium'], 1000);
    expect(AppConstants.planLimits['pro'], 300);
    expect(AppConstants.planLimits['beta_tester'], 50);
    expect(AppConstants.planLimits['free'], 15);
  });

  test('limitForRole falls back to the FREE limit (15) for an unmapped role', () {
    expect(AppConstants.limitForRole('unknown_future_role'), 15);
  });

  test('limitForRole resolves every known role to its mapped value', () {
    for (final role in AppConstants.planLimits.keys) {
      expect(AppConstants.limitForRole(role), AppConstants.planLimits[role]);
    }
  });
}
