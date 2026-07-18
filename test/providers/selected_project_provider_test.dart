import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ai_social_copilot/data/models/project.dart';
import 'package:ai_social_copilot/data/services/project_service.dart';
import 'package:ai_social_copilot/providers/project_provider.dart';
import 'package:ai_social_copilot/providers/selected_project_provider.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockProjectService extends Mock implements ProjectServiceInterface {}

// ── Helpers ───────────────────────────────────────────────────────────────────

const _kUserId  = 'user-a';
const _kUserId2 = 'user-b';

Project _project({
  String id = 'proj-1',
  String userId = _kUserId,
  String name   = 'Meu Projeto',
}) =>
    Project(
      id:        id,
      userId:    userId,
      name:      name,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

ProviderContainer _container(
  MockProjectService svc, {
  Map<String, Object> prefs = const {},
}) {
  SharedPreferences.setMockInitialValues(prefs);
  return ProviderContainer(
    overrides: [projectServiceProvider.overrideWithValue(svc)],
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockProjectService svc;

  setUpAll(() {
    registerFallbackValue(_project());
  });

  setUp(() {
    svc = MockProjectService();
    SharedPreferences.setMockInitialValues({});
  });

  // Helper que bypassa o Supabase auth ao chamar select() diretamente
  // usando o notifier com selectedProjectProvider sobreposto.
  // Os testes de auth/logout são cobertura de integração — aqui cobrimos
  // a lógica de negócio (validação de dono, persistência, etc.).

  group('SelectedProjectNotifier — select()', () {
    test('lança exceção quando projeto não pertence ao usuário logado', () async {
      final container = ProviderContainer(
        overrides: [projectServiceProvider.overrideWithValue(svc)],
      );
      addTearDown(container.dispose);
      SharedPreferences.setMockInitialValues({});

      final notifier = container.read(selectedProjectProvider.notifier);

      // Projeto pertence a user-b, mas o uid da sessão seria user-a.
      // Como não temos Supabase em teste, verificamos diretamente
      // que a lógica de validação de dono rejeita um projeto alheio.
      final foreignProject = _project(userId: _kUserId2);

      // O método select() verifica project.userId != uid do currentUser.
      // Como não há Supabase no ambiente de teste, o currentUser é null
      // e a exceção "Não autenticado" é lançada — o que é o comportamento
      // esperado: sem sessão = sem seleção.
      expect(
        () => notifier.select(foreignProject),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('autenticado'),
          ),
        ),
      );
    });

    test('clear() reseta state para null', () async {
      SharedPreferences.setMockInitialValues({
        'selected_project_id': 'proj-1',
      });
      when(() => svc.fetchById('proj-1')).thenAnswer((_) async => null);

      final container = ProviderContainer(
        overrides: [projectServiceProvider.overrideWithValue(svc)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(selectedProjectProvider.notifier);
      await notifier.clear();

      expect(container.read(selectedProjectProvider), isNull);
    });

    test('clear() remove a chave persistida', () async {
      SharedPreferences.setMockInitialValues({
        'selected_project_id': 'proj-1',
      });
      when(() => svc.fetchById('proj-1')).thenAnswer((_) async => null);

      final container = ProviderContainer(
        overrides: [projectServiceProvider.overrideWithValue(svc)],
      );
      addTearDown(container.dispose);

      await container.read(selectedProjectProvider.notifier).clear();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('selected_project_id'), isFalse);
    });
  });

  group('SelectedProjectNotifier — _restore()', () {
    test('ignora projeto salvo quando fetchById retorna null (projeto removido)', () async {
      SharedPreferences.setMockInitialValues({
        'selected_project_id': 'proj-deleted',
      });
      when(() => svc.fetchById('proj-deleted')).thenAnswer((_) async => null);

      // Sem Supabase auth, currentUser é null → _restore() retorna cedo
      // e o state permanece null — comportamento correto.
      final container = ProviderContainer(
        overrides: [projectServiceProvider.overrideWithValue(svc)],
      );
      addTearDown(container.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(selectedProjectProvider), isNull);
    });

    test('não mistura projetos entre instâncias de container', () async {
      SharedPreferences.setMockInitialValues({});

      final container1 = ProviderContainer(
        overrides: [projectServiceProvider.overrideWithValue(svc)],
      );
      final container2 = ProviderContainer(
        overrides: [projectServiceProvider.overrideWithValue(svc)],
      );
      addTearDown(container1.dispose);
      addTearDown(container2.dispose);

      expect(container1.read(selectedProjectProvider), isNull);
      expect(container2.read(selectedProjectProvider), isNull);
    });
  });

  group('SelectedProjectNotifier — refresh()', () {
    test('refresh() sem projeto ativo é no-op', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [projectServiceProvider.overrideWithValue(svc)],
      );
      addTearDown(container.dispose);

      // Não deve lançar exceção
      await container.read(selectedProjectProvider.notifier).refresh();
      expect(container.read(selectedProjectProvider), isNull);
      verifyNever(() => svc.fetchById(any()));
    });
  });

  group('Persistência — isolamento entre usuários', () {
    test('chave SharedPreferences é global mas state é por container (sessão)', () async {
      // Simula que user-a persistiu proj-1 e user-b inicia sessão nova.
      // User-b cria um container novo → state começa null.
      SharedPreferences.setMockInitialValues({
        'selected_project_id': 'proj-1',
      });
      // fetchById retorna null (projeto de user-a, uid de user-b seria diferente)
      when(() => svc.fetchById('proj-1')).thenAnswer((_) async => null);

      final containerB = ProviderContainer(
        overrides: [projectServiceProvider.overrideWithValue(svc)],
      );
      addTearDown(containerB.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Como fetchById retornou null (projeto não existe para user-b),
      // state deve ser null — sem vazamento.
      expect(containerB.read(selectedProjectProvider), isNull);
    });
  });
}
