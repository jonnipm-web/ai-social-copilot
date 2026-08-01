import '../models/ive_avatar_context.dart';
import '../models/ive_avatar_state_v2.dart';

// ── IveAvatarContextService ───────────────────────────────────────────────────
//
// Builds IveAvatarContext for known routes and module types.
// Does not depend on any Riverpod provider — callers supply raw data.

class IveAvatarContextService {
  const IveAvatarContextService();

  IveAvatarContext buildForRoute({
    required String routeName,
    required bool isAuthenticated,
    String? projectId,
    String? title,
    String? currentTask,
    bool hasActiveAnalysis = false,
    bool hasUnreadInsight = false,
  }) {
    final module = _moduleForRoute(routeName);
    final placement = _placementForRoute(routeName);
    final compact = _isCompactRoute(routeName);

    return IveAvatarContext(
      routeName: routeName,
      sourceType: 'route',
      projectId: projectId,
      module: module,
      title: title,
      currentTask: currentTask,
      isAuthenticated: isAuthenticated,
      hasActiveAnalysis: hasActiveAnalysis,
      hasUnreadInsight: hasUnreadInsight,
      compactMode: compact,
      preferredPlacement: placement,
      canInteract: isAuthenticated,
    );
  }

  IveAvatarContext buildForCard({
    required String routeName,
    required String sourceId,
    required String sourceType,
    required bool isAuthenticated,
    String? title,
    String? projectId,
  }) {
    return IveAvatarContext(
      routeName: routeName,
      sourceType: sourceType,
      sourceId: sourceId,
      projectId: projectId,
      title: title,
      isAuthenticated: isAuthenticated,
      compactMode: true,
      preferredPlacement: IveAvatarPlacement.cardHeader,
      canInteract: isAuthenticated,
    );
  }

  String _moduleForRoute(String route) {
    if (route.startsWith('/projects')) return 'projects';
    if (route.startsWith('/opportunity-lab')) return 'opportunity_lab';
    if (route.startsWith('/action-engine')) return 'action_engine';
    if (route.startsWith('/ecosystem')) return 'ecosystem';
    if (route.startsWith('/market-intelligence')) return 'market_intelligence';
    if (route.startsWith('/knowledge')) return 'knowledge';
    if (route.startsWith('/dashboard')) return 'dashboard';
    if (route.startsWith('/personas')) return 'personas';
    if (route.startsWith('/campaigns')) return 'campaigns';
    return 'general';
  }

  IveAvatarPlacement _placementForRoute(String route) {
    if (route == '/dashboard' || route == '/home') {
      return IveAvatarPlacement.floatingBottomRight;
    }
    return IveAvatarPlacement.automatic;
  }

  bool _isCompactRoute(String route) {
    const compactRoutes = {
      '/knowledge',
      '/calendar',
      '/history',
      '/admin',
    };
    return compactRoutes.contains(route);
  }
}
