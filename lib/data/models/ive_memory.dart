/// Representa a memória da IVE — sessão (in-memory) + persistente (SharedPreferences).
class IveMemory {
  /// Última rota visitada (persiste)
  final String lastRoute;

  /// ID e nome do último projeto em foco (persiste)
  final String? lastProjectId;
  final String? lastProjectName;

  /// Últimas 5 perguntas feitas ao copilot (persiste)
  final List<String> recentQuestions;

  /// Total de interações com a IVE (persiste)
  final int interactionCount;

  /// Score de saúde do ecossistema na última leitura (sessão)
  final int overallHealthScore;

  /// Snapshot de scores por projeto (sessão)
  final Map<String, int> ecosystemSnapshot;

  /// Alertas já dispensados nesta sessão (sessão)
  final List<String> dismissedAlerts;

  const IveMemory({
    this.lastRoute          = '',
    this.lastProjectId,
    this.lastProjectName,
    this.recentQuestions    = const [],
    this.interactionCount   = 0,
    this.overallHealthScore = 0,
    this.ecosystemSnapshot  = const {},
    this.dismissedAlerts    = const [],
  });

  bool isAlertDismissed(String alertId) => dismissedAlerts.contains(alertId);

  IveMemory copyWith({
    String?        lastRoute,
    String?        lastProjectId,
    String?        lastProjectName,
    List<String>?  recentQuestions,
    int?           interactionCount,
    int?           overallHealthScore,
    Map<String, int>? ecosystemSnapshot,
    List<String>?  dismissedAlerts,
  }) =>
      IveMemory(
        lastRoute:          lastRoute          ?? this.lastRoute,
        lastProjectId:      lastProjectId      ?? this.lastProjectId,
        lastProjectName:    lastProjectName    ?? this.lastProjectName,
        recentQuestions:    recentQuestions    ?? this.recentQuestions,
        interactionCount:   interactionCount   ?? this.interactionCount,
        overallHealthScore: overallHealthScore ?? this.overallHealthScore,
        ecosystemSnapshot:  ecosystemSnapshot  ?? this.ecosystemSnapshot,
        dismissedAlerts:    dismissedAlerts    ?? this.dismissedAlerts,
      );
}
