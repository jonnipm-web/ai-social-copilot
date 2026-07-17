import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/post_generation.dart';
import '../data/services/post_service.dart';

final postServiceProvider = Provider<PostService>((_) => PostService());

// Contagem de gerações do mês atual (para controle de cota gratuita)
final monthlyUsageProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(postServiceProvider).countMonthlyGenerations();
});

// Provider do histórico
final historyProvider =
    FutureProvider.autoDispose<List<PostGeneration>>((ref) {
  return ref.watch(postServiceProvider).fetchHistory();
});

// Provider de detalhe por id
final generationDetailProvider =
    FutureProvider.autoDispose.family<PostGeneration, String>((ref, id) {
  return ref.watch(postServiceProvider).fetchById(id);
});

// Notifier para melhoria de post + salvamento
class PostNotifier extends StateNotifier<AsyncValue<PostGeneration?>> {
  PostNotifier(this._service) : super(const AsyncValue.data(null));

  final PostService _service;

  Future<PostGeneration?> improvePost(String text) async {
    state = const AsyncValue.loading();

    final result = await AsyncValue.guard<PostGeneration?>(() async {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Não autenticado');
      final apiResponse = await _service.improvePost(text);
      return PostGeneration.fromApiResponse(
        userId: userId,
        originalText: text,
        response: apiResponse,
      );
    });

    state = result;
    return result.valueOrNull;
  }

  Future<void> saveGeneration(PostGeneration generation) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard<PostGeneration?>(() async {
      return _service.saveGeneration(generation);
    });
  }
}

final postNotifierProvider =
    StateNotifierProvider.autoDispose<PostNotifier, AsyncValue<PostGeneration?>>(
        (ref) {
  return PostNotifier(ref.watch(postServiceProvider));
});
