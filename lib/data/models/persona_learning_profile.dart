import 'dart:math' as math;

import 'persona.dart';
import 'persona_training.dart';

class PersonaLearningProfile {
  final Persona persona;
  final int trainingCount;
  final int vocabularySize;
  final int brandValueCount;
  final int learningScore;
  final List<String> knownTopics;
  final List<String> knownNiches;
  final DateTime? lastTrainedAt;
  final bool hasRecentTraining;

  const PersonaLearningProfile({
    required this.persona,
    required this.trainingCount,
    required this.vocabularySize,
    required this.brandValueCount,
    required this.learningScore,
    required this.knownTopics,
    required this.knownNiches,
    this.lastTrainedAt,
    required this.hasRecentTraining,
  });

  String get learningLabel {
    if (learningScore >= 80) return 'Especialista';
    if (learningScore >= 60) return 'Avançado';
    if (learningScore >= 40) return 'Intermediário';
    if (learningScore >= 20) return 'Iniciante';
    return 'Sem Treinamento';
  }

  String get learningEmoji {
    if (learningScore >= 80) return '🧠';
    if (learningScore >= 60) return '📚';
    if (learningScore >= 40) return '📖';
    if (learningScore >= 20) return '📝';
    return '⭕';
  }

  // Confidence reflects how much data backs the persona's knowledge
  double get confidenceLevel => learningScore / 100.0;

  static PersonaLearningProfile compute({
    required Persona persona,
    required List<PersonaTraining> trainings,
    DateTime? now,
  }) {
    final ref    = now ?? DateTime.now();
    final cutoff = ref.subtract(const Duration(days: 30));

    final vocabulary  = <String>{};
    final brandValues = <String>{};

    for (final t in trainings) {
      vocabulary.addAll(t.vocabularyJson);
      brandValues.addAll(t.brandValuesJson);
    }

    final hasRecent = trainings.any((t) => t.createdAt.isAfter(cutoff));
    final lastAt = trainings.isNotEmpty
        ? trainings.map((t) => t.createdAt).reduce((a, b) => a.isAfter(b) ? a : b)
        : null;

    // Learning score: weighted formula based on depth + recency
    final trainingPts = math.min(40, trainings.length * 10);
    final vocabPts    = math.min(20, vocabulary.length);
    final valuePts    = math.min(20, brandValues.length * 2);
    final summaryPts  = trainings.any((t) => (t.trainingSummary?.isNotEmpty ?? false)) ? 10 : 0;
    final recentPts   = hasRecent ? 10 : 0;
    final score = (trainingPts + vocabPts + valuePts + summaryPts + recentPts).clamp(0, 100);

    final topics = trainings
        .map((t) => t.toneProfileJson['topic'] as String? ?? '')
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();

    final niches = trainings
        .map((t) => t.audienceJson['niche'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();

    return PersonaLearningProfile(
      persona:           persona,
      trainingCount:     trainings.length,
      vocabularySize:    vocabulary.length,
      brandValueCount:   brandValues.length,
      learningScore:     score,
      knownTopics:       topics,
      knownNiches:       niches,
      lastTrainedAt:     lastAt,
      hasRecentTraining: hasRecent,
    );
  }
}
