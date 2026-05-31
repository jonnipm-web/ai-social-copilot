import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/persona.dart';
import '../data/services/persona_service.dart';

final personaServiceProvider =
    Provider<PersonaService>((ref) => PersonaService());

final allPersonasProvider = FutureProvider<List<Persona>>((ref) async {
  return ref.read(personaServiceProvider).fetchAll();
});

final personasByBrandProvider =
    FutureProvider.family<List<Persona>, String>((ref, brandId) async {
  return ref.read(personaServiceProvider).fetchByBrand(brandId);
});

class PersonaNotifier extends StateNotifier<AsyncValue<void>> {
  PersonaNotifier(this._service, this._ref)
      : super(const AsyncValue.data(null));

  final PersonaService _service;
  final Ref _ref;

  Future<Persona?> create(Persona persona) async {
    state = const AsyncValue.loading();
    try {
      final created = await _service.create(persona);
      _ref.invalidate(allPersonasProvider);
      _ref.invalidate(personasByBrandProvider(persona.brandId));
      state = const AsyncValue.data(null);
      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<Persona?> update(String id, String brandId, Map<String, dynamic> fields) async {
    state = const AsyncValue.loading();
    try {
      final updated = await _service.update(id, fields);
      _ref.invalidate(allPersonasProvider);
      _ref.invalidate(personasByBrandProvider(brandId));
      state = const AsyncValue.data(null);
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> setStatus(String id, String brandId, String status) async {
    await _service.setStatus(id, status);
    _ref.invalidate(allPersonasProvider);
    _ref.invalidate(personasByBrandProvider(brandId));
  }
}

final personaNotifierProvider =
    StateNotifierProvider<PersonaNotifier, AsyncValue<void>>((ref) {
  return PersonaNotifier(ref.read(personaServiceProvider), ref);
});
