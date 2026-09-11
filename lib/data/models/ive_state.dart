import 'ive_issue.dart';

enum IveExpression { happy, thinking, excited, neutral, winking }

// ── Interaction state ─────────────────────────────────────────────────────────
// Temporary overlay driven by an in-flight IVE chat request (see IveNotifier
// .beginThinking()/.completeInteraction()). When non-null it takes visual
// priority over `expression`/`activeIssue` (IveVisualStateMapper); when it is
// cleared the mapper falls back to whatever `expression`/`activeIssue` have
// live-updated to in the meantime — never a stale snapshot.
enum IveInteractionState { thinking, speaking }

class IveState {
  final String              screenName;
  final String              message;
  final IveExpression       expression;
  final bool                bubbleVisible;
  final IveIssue?           activeIssue;
  final IveInteractionState? interaction;

  const IveState({
    this.screenName    = '',
    this.message       = '',
    this.expression    = IveExpression.happy,
    this.bubbleVisible = false,
    this.activeIssue,
    this.interaction,
  });

  IveState copyWith({
    String?              screenName,
    String?              message,
    IveExpression?       expression,
    bool?                bubbleVisible,
    IveIssue?            activeIssue,
    bool                 clearIssue = false,
    IveInteractionState? interaction,
    bool                 clearInteraction = false,
  }) =>
      IveState(
        screenName:    screenName    ?? this.screenName,
        message:       message       ?? this.message,
        expression:    expression    ?? this.expression,
        bubbleVisible: bubbleVisible ?? this.bubbleVisible,
        activeIssue:   clearIssue ? null : (activeIssue ?? this.activeIssue),
        interaction:   clearInteraction ? null : (interaction ?? this.interaction),
      );
}
