import 'package:flutter/widgets.dart' show AppLifecycleState;

/// IVE-COMMERCIAL-TARGETED-REMEDIATION-06S — paid-state refresh.
///
/// Stripe Checkout opens in a separate browser tab
/// (upgrade_screen.dart's `launchUrl(..., webOnlyWindowName: '_blank')`),
/// so the original app tab is never reloaded when the user returns — the
/// webhook updates `profiles.role`/`monthly_limit` entirely server-side,
/// with nothing in the original tab to trigger a refetch. This is the
/// residual gap flagged (not fixed, by explicit mission boundary — no
/// Stripe/webhook/migration changes) in Remediation 06R's report.
///
/// [shouldRefreshProfileOnResume] is the pure decision: refresh only on an
/// actual resume-from-background transition, and only when a session
/// exists — never fabricate entitlement for a signed-out user, never
/// refresh on every lifecycle event (inactive/hidden/paused/detached all
/// return false). See lib/app.dart for how this drives an actual
/// `ref.invalidate(currentProfileProvider)` — never a local role/quota
/// write; the server remains the only source of truth for what the next
/// fetch returns.
bool shouldRefreshProfileOnResume({
  required AppLifecycleState state,
  required bool isAuthenticated,
}) {
  return state == AppLifecycleState.resumed && isAuthenticated;
}
