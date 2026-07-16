import 'ive_issue.dart';

enum IveExpression { happy, thinking, excited, neutral, winking }

class IveState {
  final String        screenName;
  final String        message;
  final IveExpression expression;
  final bool          bubbleVisible;
  final IveIssue?     activeIssue;

  const IveState({
    this.screenName    = '',
    this.message       = '',
    this.expression    = IveExpression.happy,
    this.bubbleVisible = false,
    this.activeIssue,
  });

  IveState copyWith({
    String?        screenName,
    String?        message,
    IveExpression? expression,
    bool?          bubbleVisible,
    IveIssue?      activeIssue,
    bool           clearIssue = false,
  }) =>
      IveState(
        screenName:    screenName    ?? this.screenName,
        message:       message       ?? this.message,
        expression:    expression    ?? this.expression,
        bubbleVisible: bubbleVisible ?? this.bubbleVisible,
        activeIssue:   clearIssue ? null : (activeIssue ?? this.activeIssue),
      );
}
