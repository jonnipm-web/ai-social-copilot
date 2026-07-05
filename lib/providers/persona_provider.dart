import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/persona.dart';
import '../data/services/persona_service.dart';

final personaServiceProvider = Provider<PersonaService>((_) => PersonaService());

final personasProvider = FutureProvider.autoDispose<List<Persona>>((ref) {
  return ref.watch(personaServiceProvider).fetchAll();
});

final personaByIdProvider =
    FutureProvider.autoDispose.family<Persona?, String>((ref, id) {
  return ref.watch(personaServiceProvider).fetchById(id);
});

class PersonaNotifier extends StateNotifier<AsyncValue<Persona?>> {
  PersonaNotifier(this._service) : super(const AsyncValue.data(null));

  final PersonaService _service;

  Future<Persona?> create(Persona persona) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _service.create(persona));
    state = result;
    return result.valueOrNull;
  }

  Future<Persona?> update(String id, Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _service.update(id, data));
    state = result;
    return result.valueOrNull;
  }

  Future<void> delete(String id) async {
    state = const AsyncValue.loading();
    try {
      await _service.delete(id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final personaNotifierProvider =
    StateNotifierProvider.autoDispose<PersonaNotifier, AsyncValue<Persona?>>(
        (ref) => PersonaNotifier(ref.watch(personaServiceProvider)));
