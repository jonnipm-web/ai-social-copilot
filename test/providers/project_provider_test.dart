import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ai_social_copilot/core/services/ive_event_bus.dart';
import 'package:ai_social_copilot/data/models/ive_event.dart';
import 'package:ai_social_copilot/data/models/project.dart';
import 'package:ai_social_copilot/data/services/project_service.dart';
import 'package:ai_social_copilot/providers/project_provider.dart';

// ── Fake service ─────────────────────────────────────────────────────────────

class MockProjectService extends Mock implements ProjectServiceInterface {}

// ── Helper ────────────────────────────────────────────────────────────────────

Project _project({
  String id = 'p1',
  String name = 'Projeto Teste',
  String status = 'idea',
}) =>
    Project(
      id: id,
      userId: 'user-1',
      name: name,
      status: status,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

ProviderContainer _container(MockProjectService svc) => ProviderContainer(
      overrides: [
        projectServiceProvider.overrideWithValue(svc),
      ],
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockProjectService svc;

  setUp(() {
    svc = MockProjectService();
  });

  tearDown(() {
    // Garante que o event bus não vaza entre testes
  });

  // ── Estado inicial ────────────────────────────────────────────────────────
  group('Estado inicial', () {
    test('começa em loading e vai para data após fetchAll()', () async {
      final p = _project();
      when(() => svc.fetchAll()).thenAnswer((_) async => [p]);

      final container = _container(svc);
      addTearDown(container.dispose);

      // Inicialmente loading
      expect(
        container.read(projectsNotifierProvider),
        const AsyncLoading<List<Project>>(),
      );

      // Aguarda a resolução
      final result = await container.read(projectsNotifierProvider.future);

      expect(result, [p]);
      expect(
        container.read(projectsNotifierProvider),
        AsyncData([p]),
      );
      verify(() => svc.fetchAll()).called(1);
    });

    test('projectsProvider é o mesmo provider que projectsNotifierProvider', () {
      // Garante que o alias aponta para a mesma instância
      expect(identical(projectsProvider, projectsNotifierProvider), isTrue);
    });

    test('estado de erro ao falha no fetchAll()', () async {
      when(() => svc.fetchAll()).thenThrow(Exception('DB offline'));

      final container = _container(svc);
      addTearDown(container.dispose);

      final state = await container
          .read(projectsNotifierProvider.future)
          .then(AsyncData.new)
          .onError((e, st) => AsyncError<List<Project>>(e!, st));

      expect(state, isA<AsyncError<List<Project>>>());
    });
  });

  // ── create() ─────────────────────────────────────────────────────────────
  group('create()', () {
    test('adiciona projeto à lista e re-fetcha do DB', () async {
      final initial = [_project(id: 'p1')];
      final created = _project(id: 'p2', name: 'Novo Projeto');
      final afterCreate = [...initial, created];

      when(() => svc.fetchAll())
          .thenAnswer((_) async => initial)
          .thenAnswer((_) async => afterCreate);
      when(() => svc.create(any())).thenAnswer((_) async => created);

      final container = _container(svc);
      addTearDown(container.dispose);

      await container.read(projectsNotifierProvider.future);

      await container
          .read(projectsNotifierProvider.notifier)
          .create({'name': 'Novo Projeto', 'type': 'website'});

      // Aguarda re-fetch
      await container.read(projectsNotifierProvider.future);

      final state = container.read(projectsNotifierProvider).valueOrNull;
      expect(state, containsAll([initial.first, created]));

      verify(() => svc.create(any())).called(1);
      // fetchAll chamado 2x: inicial + após create
      verify(() => svc.fetchAll()).called(greaterThanOrEqualTo(2));
    });

    test('emite IveEvent.projectCreated no event bus', () async {
      final created = _project(id: 'p-new', name: 'Blog Tech');

      when(() => svc.fetchAll()).thenAnswer((_) async => []);
      when(() => svc.create(any())).thenAnswer((_) async => created);

      final container = _container(svc);
      addTearDown(container.dispose);
      await container.read(projectsNotifierProvider.future);

      IveEvent? received;
      final sub =
          IveEventBus.instance.stream.listen((e) => received = e);

      await container
          .read(projectsNotifierProvider.notifier)
          .create({'name': 'Blog Tech'});

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(received, isNotNull);
      expect(received!.type, IveEventType.projectCreated);
      expect(received!.entityId, 'p-new');
      expect(received!.entityName, 'Blog Tech');
    });

    test('retorna o projeto criado', () async {
      final created = _project(id: 'ret-id', name: 'Return Test');
      when(() => svc.fetchAll()).thenAnswer((_) async => []);
      when(() => svc.create(any())).thenAnswer((_) async => created);

      final container = _container(svc);
      addTearDown(container.dispose);
      await container.read(projectsNotifierProvider.future);

      final result = await container
          .read(projectsNotifierProvider.notifier)
          .create({'name': 'Return Test'});

      expect(result.id, 'ret-id');
    });
  });

  // ── updateStatus() ────────────────────────────────────────────────────────
  group('updateStatus()', () {
    test('atualiza status na lista local e re-fetcha', () async {
      final original = _project(id: 'p1', status: 'idea');
      final updated = _project(id: 'p1', status: 'active');

      when(() => svc.fetchAll())
          .thenAnswer((_) async => [original])
          .thenAnswer((_) async => [updated]);
      when(() => svc.update('p1', any()))
          .thenAnswer((_) async => updated);

      final container = _container(svc);
      addTearDown(container.dispose);
      await container.read(projectsNotifierProvider.future);

      await container
          .read(projectsNotifierProvider.notifier)
          .updateStatus('p1', 'active');

      await container.read(projectsNotifierProvider.future);
      final state = container.read(projectsNotifierProvider).valueOrNull;
      expect(state!.first.status, 'active');
    });

    test('emite IveEvent.projectStatusChanged com status correto', () async {
      final p = _project(id: 'p1', name: 'Blog');
      final updated = _project(id: 'p1', name: 'Blog', status: 'active');

      when(() => svc.fetchAll()).thenAnswer((_) async => [p]);
      when(() => svc.update('p1', any())).thenAnswer((_) async => updated);

      final container = _container(svc);
      addTearDown(container.dispose);
      await container.read(projectsNotifierProvider.future);

      IveEvent? received;
      final sub = IveEventBus.instance.stream.listen((e) => received = e);

      await container
          .read(projectsNotifierProvider.notifier)
          .updateStatus('p1', 'active');

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(received!.type, IveEventType.projectStatusChanged);
      expect(received!.payload['status'], 'active');
      expect(received!.entityId, 'p1');
      expect(received!.entityName, 'Blog');
    });
  });

  // ── delete() ─────────────────────────────────────────────────────────────
  group('delete()', () {
    test('remove projeto da lista imediatamente (optimistic)', () async {
      final p1 = _project(id: 'p1', name: 'A');
      final p2 = _project(id: 'p2', name: 'B');

      when(() => svc.fetchAll()).thenAnswer((_) async => [p1, p2]);
      when(() => svc.delete('p1')).thenAnswer((_) async {});
      when(() => svc.fetchAll()).thenAnswer((_) async => [p2]);

      final container = _container(svc);
      addTearDown(container.dispose);
      await container.read(projectsNotifierProvider.future);

      // Não aguarda — verifica estado otimista imediato
      final future = container
          .read(projectsNotifierProvider.notifier)
          .delete('p1');

      // Imediatamente após chamar delete, o estado já não tem 'p1'
      final stateOptimistic =
          container.read(projectsNotifierProvider).valueOrNull;
      expect(stateOptimistic?.map((p) => p.id), isNot(contains('p1')));

      await future;
    });

    test('reverte estado se delete falhar no Supabase', () async {
      final p1 = _project(id: 'p1');
      final p2 = _project(id: 'p2');

      when(() => svc.fetchAll()).thenAnswer((_) async => [p1, p2]);
      when(() => svc.delete('p1')).thenThrow(Exception('FK violation'));

      final container = _container(svc);
      addTearDown(container.dispose);
      await container.read(projectsNotifierProvider.future);

      await expectLater(
        container.read(projectsNotifierProvider.notifier).delete('p1'),
        throwsException,
      );

      // Lista restaurada
      final state = container.read(projectsNotifierProvider).valueOrNull;
      expect(state?.map((p) => p.id), contains('p1'));
    });

    test('emite IveEvent.projectDeleted com nome correto', () async {
      final p = _project(id: 'p1', name: 'Meu Blog');

      when(() => svc.fetchAll()).thenAnswer((_) async => [p]);
      when(() => svc.delete('p1')).thenAnswer((_) async {});

      final container = _container(svc);
      addTearDown(container.dispose);
      await container.read(projectsNotifierProvider.future);

      IveEvent? received;
      final sub = IveEventBus.instance.stream.listen((e) => received = e);

      await container
          .read(projectsNotifierProvider.notifier)
          .delete('p1');

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(received!.type, IveEventType.projectDeleted);
      expect(received!.entityId, 'p1');
      expect(received!.entityName, 'Meu Blog');
    });
  });

  // ── update() ─────────────────────────────────────────────────────────────
  group('updateFields()', () {
    test('atualiza campos arbitrários e emite projectUpdated', () async {
      final original = _project(id: 'p1', name: 'Old');
      final updated = _project(id: 'p1', name: 'New');

      when(() => svc.fetchAll()).thenAnswer((_) async => [original]);
      when(() => svc.update('p1', any())).thenAnswer((_) async => updated);

      final container = _container(svc);
      addTearDown(container.dispose);
      await container.read(projectsNotifierProvider.future);

      IveEvent? received;
      final sub = IveEventBus.instance.stream.listen((e) => received = e);

      await container
          .read(projectsNotifierProvider.notifier)
          .updateFields('p1', {'name': 'New'});

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(received!.type, IveEventType.projectUpdated);
      expect(received!.entityName, 'New');

      final state = container.read(projectsNotifierProvider).valueOrNull;
      expect(state!.first.name, 'New');
    });
  });
}
