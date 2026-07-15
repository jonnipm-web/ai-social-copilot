import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/knowledge_analysis.dart';
import '../data/models/knowledge_item.dart';
import '../data/models/persona_training.dart';
import '../data/services/persona_training_service.dart';

final personaTrainingServiceProvider =
    Provider<PersonaTrainingService>((_) => PersonaTrainingService());

final personaTrainingProvider =
    FutureProvider.autoDispose.family<List<PersonaTraining>, String>(
        (ref, personaId) {
  return ref.watch(personaTrainingServiceProvider).fetchForPersona(personaId);
});

// All trainings across all personas — used by learning profiles
final allPersonaTrainingsProvider =
    FutureProvider.autoDispose<List<PersonaTraining>>((ref) {
  return ref.watch(personaTrainingServiceProvider).fetchAll();
});

class PersonaTrainingNotifier
    extends StateNotifier<AsyncValue<PersonaTraining?>> {
  PersonaTrainingNotifier(this._service) : super(const AsyncValue.data(null));

  final PersonaTrainingService _service;

  Future<PersonaTraining?> train({
    required String personaId,
    required KnowledgeItem item,
    required KnowledgeAnalysis analysis,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.trainFromAnalysis(
        personaId: personaId,
        item:      item,
        analysis:  analysis,
      );
      state = AsyncValue.data(result);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final personaTrainingNotifierProvider = StateNotifierProvider.autoDispose<
    PersonaTrainingNotifier, AsyncValue<PersonaTraining?>>(
  (ref) => PersonaTrainingNotifier(ref.watch(personaTrainingServiceProvider)),
);
