enum ValidationStatus { pass, warning, fail }

class ValidationTest {
  final String id;
  final String name;
  final String description;
  final ValidationStatus status;
  final int passed;
  final int total;
  final List<String> failedItems;
  final String? suggestion;

  const ValidationTest({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    required this.passed,
    required this.total,
    this.failedItems = const [],
    this.suggestion,
  });

  double get passRate => total == 0 ? 1.0 : passed / total;
  int get failedCount => total - passed;

  String get statusLabel {
    switch (status) {
      case ValidationStatus.pass:    return 'PASSOU';
      case ValidationStatus.warning: return 'ATENÇÃO';
      case ValidationStatus.fail:    return 'FALHOU';
    }
  }

  String get statusEmoji {
    switch (status) {
      case ValidationStatus.pass:    return '✅';
      case ValidationStatus.warning: return '⚠️';
      case ValidationStatus.fail:    return '❌';
    }
  }
}

class ValidationReport {
  final List<ValidationTest> tests;
  final DateTime runAt;
  final int projectsAudited;
  final int documentsFound;
  final int documentsIndexed;
  final int assetsFound;
  final int orphanAssets;
  final int personasAudited;
  final int personasWithLearning;
  final int personasWithoutLearning;
  final int opportunitiesAudited;
  final int recommendationsAudited;
  final int scoresAudited;
  final int invalidScores;
  final int brokenRules;
  final int problemsFound;
  final int intelligenceScoreBefore;
  final int intelligenceScoreAfter;

  const ValidationReport({
    required this.tests,
    required this.runAt,
    required this.projectsAudited,
    required this.documentsFound,
    required this.documentsIndexed,
    required this.assetsFound,
    required this.orphanAssets,
    required this.personasAudited,
    required this.personasWithLearning,
    required this.personasWithoutLearning,
    required this.opportunitiesAudited,
    required this.recommendationsAudited,
    required this.scoresAudited,
    required this.invalidScores,
    required this.brokenRules,
    required this.problemsFound,
    required this.intelligenceScoreBefore,
    required this.intelligenceScoreAfter,
  });

  int get passedTests    => tests.where((t) => t.status == ValidationStatus.pass).length;
  int get warningTests   => tests.where((t) => t.status == ValidationStatus.warning).length;
  int get failedTests    => tests.where((t) => t.status == ValidationStatus.fail).length;
  double get healthRatio => tests.isEmpty ? 0 : passedTests / tests.length;

  String get overallLabel {
    if (healthRatio >= 0.9) return 'Sistema Saudável';
    if (healthRatio >= 0.6) return 'Atenção Necessária';
    return 'Problemas Críticos';
  }
}
