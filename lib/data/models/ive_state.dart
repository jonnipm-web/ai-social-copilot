enum IveExpression { happy, thinking, excited, neutral, winking }

class IveState {
  final String screenName;
  final String message;
  final IveExpression expression;
  final bool bubbleVisible;

  const IveState({
    this.screenName  = '',
    this.message     = '',
    this.expression  = IveExpression.happy,
    this.bubbleVisible = false,
  });

  IveState copyWith({
    String?        screenName,
    String?        message,
    IveExpression? expression,
    bool?          bubbleVisible,
  }) =>
      IveState(
        screenName:    screenName    ?? this.screenName,
        message:       message       ?? this.message,
        expression:    expression    ?? this.expression,
        bubbleVisible: bubbleVisible ?? this.bubbleVisible,
      );
}
