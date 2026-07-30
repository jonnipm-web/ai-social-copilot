import '../models/ive_avatar_context.dart';
import '../models/ive_avatar_state_v2.dart';

// ── Visibility result ─────────────────────────────────────────────────────────

class IveAvatarVisibilityResult {
  final bool                 visible;
  final IveAvatarPlacement   placement;
  final String               reason;

  const IveAvatarVisibilityResult({
    required this.visible,
    required this.placement,
    this.reason = '',
  });

  static const hidden = IveAvatarVisibilityResult(
    visible:   false,
    placement: IveAvatarPlacement.hidden,
  );
}

// ── Routes where avatar is never shown ───────────────────────────────────────

const _kHiddenRoutes = <String>{
  '/',           // splash
  '/login',
  '/signup',
  '/forgot-password',
  '/reset-password',
};

// ── Visibility service ────────────────────────────────────────────────────────

class IveAvatarVisibilityService {
  const IveAvatarVisibilityService();

  IveAvatarVisibilityResult evaluate({
    required IveAvatarContext context,
    required bool             isKeyboardOpen,
    required double           availableHeight,
    required bool             isCriticalDialog,
    required bool             isNavigatingAway,
  }) {
    // Must be authenticated
    if (!context.isAuthenticated) {
      return _hidden('unauthenticated');
    }

    // Protected routes
    if (_kHiddenRoutes.contains(context.routeName)) {
      return _hidden('protected_route:${context.routeName}');
    }

    // Critical modal / dialog blocks avatar
    if (isCriticalDialog) {
      return _hidden('critical_dialog');
    }

    // Navigating away — suppress to avoid flicker
    if (isNavigatingAway) {
      return _hidden('navigating_away');
    }

    // No valid context yet
    if (context.routeName.isEmpty) {
      return _hidden('empty_route');
    }

    // Keyboard open: check if enough room
    if (isKeyboardOpen && availableHeight < 200) {
      return _hidden('keyboard_insufficient_space');
    }

    // Explicit hide from context
    if (context.preferredPlacement == IveAvatarPlacement.hidden) {
      return _hidden('placement_hidden');
    }

    // Disabled state: still show but dimmed — caller renders accordingly
    final placement = _resolvePlacement(context, isKeyboardOpen);

    return IveAvatarVisibilityResult(
      visible:   true,
      placement: placement,
      reason:    'visible',
    );
  }

  IveAvatarPlacement _resolvePlacement(
    IveAvatarContext context,
    bool isKeyboardOpen,
  ) {
    if (context.preferredPlacement != IveAvatarPlacement.automatic) {
      return context.preferredPlacement;
    }

    if (context.compactMode) return IveAvatarPlacement.appBar;
    if (isKeyboardOpen)      return IveAvatarPlacement.inline;

    return IveAvatarPlacement.floatingBottomRight;
  }

  IveAvatarVisibilityResult _hidden(String reason) =>
      IveAvatarVisibilityResult(
        visible:   false,
        placement: IveAvatarPlacement.hidden,
        reason:    reason,
      );

  bool shouldShow({
    required String routeName,
    required bool   isAuthenticated,
  }) {
    if (!isAuthenticated) return false;
    if (_kHiddenRoutes.contains(routeName)) return false;
    return true;
  }
}
