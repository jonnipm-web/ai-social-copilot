import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/brand.dart';
import '../data/services/brand_service.dart';

final brandServiceProvider = Provider<BrandService>((ref) => BrandService());

final brandsProvider = FutureProvider<List<Brand>>((ref) async {
  return ref.read(brandServiceProvider).fetchAll();
});

final brandDetailProvider =
    FutureProvider.family<Brand, String>((ref, id) async {
  return ref.read(brandServiceProvider).fetchById(id);
});

class BrandNotifier extends StateNotifier<AsyncValue<void>> {
  BrandNotifier(this._service, this._ref) : super(const AsyncValue.data(null));

  final BrandService _service;
  final Ref _ref;

  Future<Brand?> create(Brand brand) async {
    state = const AsyncValue.loading();
    try {
      final created = await _service.create(brand);
      _ref.invalidate(brandsProvider);
      state = const AsyncValue.data(null);
      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<Brand?> update(String id, Map<String, dynamic> fields) async {
    state = const AsyncValue.loading();
    try {
      final updated = await _service.update(id, fields);
      _ref.invalidate(brandsProvider);
      _ref.invalidate(brandDetailProvider(id));
      state = const AsyncValue.data(null);
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> setStatus(String id, String status) async {
    await _service.setStatus(id, status);
    _ref.invalidate(brandsProvider);
  }

  Future<void> seedIfEmpty() async {
    await _service.seedInitialBrands();
    _ref.invalidate(brandsProvider);
  }
}

final brandNotifierProvider =
    StateNotifierProvider<BrandNotifier, AsyncValue<void>>((ref) {
  return BrandNotifier(ref.read(brandServiceProvider), ref);
});
