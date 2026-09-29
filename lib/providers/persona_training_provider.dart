import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/knowledge_analysis.dart';
import '../data/models/knowledge_item.dart';
import '../data/models/persona_training.dart';
import '../core/utils/language_utils.dart';
import '../data/services/persona_training_service.dart';
import '../l10n/app_localizations.dart';

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
  PersonaTrainingNotifier(this._service, {AppLocalizations Function()? l10n})
      : _l10n = l10n,
        super(const AsyncValue.data(null));

  final PersonaTrainingService _service;
  /// R16 — current UI-language localizations for persisted summary text.
  final AppLocalizations Function()? _l10n;

  Future<PersonaTraining?> train({
    required String personaId,
    required KnowledgeItem item,
    required KnowledgeAnalysis analysis,
  }) async {
    AppLocalizations? l10n;
    try {
      l10n = _l10n?.call();
    } catch (_) {
      l10n = null; // service falls back to PT
    }
    state = const AsyncValue.loading();
    try {
      final result = await _service.trainFromAnalysis(
        personaId: personaId,
        item:      item,
        analysis:  analysis,
        l10n:      l10n,
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
  (ref) => PersonaTrainingNotifier(
    ref.watch(personaTrainingServiceProvider),
    l10n: () => ref.read(appL10nProvider),
  ),
);
