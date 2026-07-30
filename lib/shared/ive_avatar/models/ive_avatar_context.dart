import 'ive_avatar_state_v2.dart';

// ── IveAvatarContext — immutable context passed to the avatar ─────────────────
//
// The avatar must not depend directly on another screen's BuildContext.
// Instead, callers populate this object and pass it in.

class IveAvatarContext {
  final String  routeName;
  final String  sourceType;
  final String? sourceId;
  final String? projectId;
  final String? module;
  final String? title;
  final String? currentTask;
  final String? status;
  final int     importance;       // 0 = low, 1 = medium, 2 = high, 3 = critical
  final bool    canInteract;
  final bool    isAuthenticated;
  final bool    hasActiveAnalysis;
  final bool    hasUnreadInsight;
  final bool    compactMode;
  final IveAvatarPlacement preferredPlacement;

  const IveAvatarContext({
    this.routeName        = '',
    this.sourceType       = '',
    this.sourceId,
    this.projectId,
    this.module,
    this.title,
    this.currentTask,
    this.status,
    this.importance       = 0,
    this.canInteract      = true,
    this.isAuthenticated  = false,
    this.hasActiveAnalysis = false,
    this.hasUnreadInsight = false,
    this.compactMode      = false,
    this.preferredPlacement = IveAvatarPlacement.automatic,
  });

  static const empty = IveAvatarContext();

  IveAvatarContext copyWith({
    String?  routeName,
    String?  sourceType,
    String?  sourceId,
    String?  projectId,
    String?  module,
    String?  title,
    String?  currentTask,
    String?  status,
    int?     importance,
    bool?    canInteract,
    bool?    isAuthenticated,
    bool?    hasActiveAnalysis,
    bool?    hasUnreadInsight,
    bool?    compactMode,
    IveAvatarPlacement? preferredPlacement,
  }) {
    return IveAvatarContext(
      routeName:         routeName        ?? this.routeName,
      sourceType:        sourceType       ?? this.sourceType,
      sourceId:          sourceId         ?? this.sourceId,
      projectId:         projectId        ?? this.projectId,
      module:            module           ?? this.module,
      title:             title            ?? this.title,
      currentTask:       currentTask      ?? this.currentTask,
      status:            status           ?? this.status,
      importance:        importance       ?? this.importance,
      canInteract:       canInteract      ?? this.canInteract,
      isAuthenticated:   isAuthenticated  ?? this.isAuthenticated,
      hasActiveAnalysis: hasActiveAnalysis ?? this.hasActiveAnalysis,
      hasUnreadInsight:  hasUnreadInsight ?? this.hasUnreadInsight,
      compactMode:       compactMode      ?? this.compactMode,
      preferredPlacement: preferredPlacement ?? this.preferredPlacement,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IveAvatarContext &&
          routeName        == other.routeName        &&
          sourceType       == other.sourceType       &&
          sourceId         == other.sourceId         &&
          projectId        == other.projectId        &&
          module           == other.module           &&
          title            == other.title            &&
          currentTask      == other.currentTask      &&
          status           == other.status           &&
          importance       == other.importance       &&
          canInteract      == other.canInteract      &&
          isAuthenticated  == other.isAuthenticated  &&
          hasActiveAnalysis == other.hasActiveAnalysis &&
          hasUnreadInsight == other.hasUnreadInsight &&
          compactMode      == other.compactMode      &&
          preferredPlacement == other.preferredPlacement;

  @override
  int get hashCode => Object.hash(
        routeName, sourceType, sourceId, projectId, module,
        title, currentTask, status, importance, canInteract,
        isAuthenticated, hasActiveAnalysis, hasUnreadInsight,
        compactMode, preferredPlacement,
      );
}
