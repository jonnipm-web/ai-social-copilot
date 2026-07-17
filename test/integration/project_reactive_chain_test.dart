/// Teste de integração: verifica a cadeia reativa completa
///
/// Projeto criado → projectsNotifierProvider atualiza → IveEventBus emite
/// → todos os módulos que watcham projectsProvider são invalidados
///
/// Não usa Supabase real — usa overrides de provider com dados fake.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ai_social_copilot/core/services/ive_event_bus.dart';
import 'package:ai_social_copilot/data/models/ive_event.dart';
import 'package:ai_social_copilot/data/models/project.dart';
import 'package:ai_social_copilot/data/services/project_service.dart';
import 'package:ai_social_copilot/providers/project_provider.dart';

class MockProjectService extends Mock implements ProjectServiceInterface {}

Project _p(String id, String name) => Project(
      id: id,
      userId: 'uid',
      name: name,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  group('Cadeia reativa — Criar projeto', () {
    test('create → estado atualiza → evento emitido', () async {
      final svc = MockProjectService();
      final p1 = _p('p1', 'Projeto Existente');
      final p2 = _p('p2', 'Novo Projeto');

      when(() => svc.fetchAll())
          .thenAnswer((_) async => [p1])
          .thenAnswer((_) async => [p1, p2]);
      when(() => svc.create(any())).thenAnswer((_) async => p2);

      final container = ProviderContainer(overrides: [
        projectServiceProvider.overrideWithValue(svc),
      ]);
      addTearDown(container.dispose);

      // Aguarda carregamento inicial
      await container.read(projectsNotifierProvider.future);
      expect(
        container.read(projectsNotifierProvider).valueOrNull?.length,
        1,
      );

      // Captura evento
      final events = <IveEvent>[];
      final sub = IveEventBus.instance.stream.listen(events.add);

      // Cria projeto
      await container
          .read(projectsNotifierProvider.notifier)
          .create({'name': 'Novo Projeto', 'type': 'website'});

      // Aguarda refetch
      await container.read(projectsNotifierProvider.future);
      await sub.cancel();

      // Estado atualizado
      final projects = container.read(projectsNotifierProvider).valueOrNull;
      expect(projects?.length, 2);
      expect(projects?.map((p) => p.name), contains('Novo Projeto'));

      // Evento emitido
      final created = events.where(
        (e) => e.type == IveEventType.projectCreated,
      );
      expect(created, hasLength(1));
      expect(created.first.entityId, 'p2');
      expect(created.first.entityName, 'Novo Projeto');
    });

    test('projectsProvider e projectsNotifierProvider são o mesmo objeto', () {
      // Garantia da fonte única de verdade — o alias é idêntico
      expect(identical(projectsProvider, projectsNotifierProvider), isTrue);
    });

    test('.future disponível no provider — watchers de inteligência funcionam',
        () async {
      final svc = MockProjectService();
      final projects = [_p('p1', 'A'), _p('p2', 'B')];
      when(() => svc.fetchAll()).thenAnswer((_) async => projects);

      final container = ProviderContainer(overrides: [
        projectServiceProvider.overrideWithValue(svc),
      ]);
      addTearDown(container.dispose);

      // Simula o que ecosystemScoresProvider faz:
      // ref.watch(projectsProvider.future) → Future<List<Project>>
      final result = await container.read(projectsProvider.future);

      expect(result, hasLength(2));
      expect(result.map((p) => p.name), containsAll(['A', 'B']));
    });

    test('invalidate dispara rebuild (como weekly_briefing_screen faz)', () async {
      final svc = MockProjectService();
      var callCount = 0;
      when(() => svc.fetchAll()).thenAnswer((_) async {
        callCount++;
        return [_p('p$callCount', 'V$callCount')];
      });

      final container = ProviderContainer(overrides: [
        projectServiceProvider.overrideWithValue(svc),
      ]);
      addTearDown(container.dispose);

      await container.read(projectsNotifierProvider.future);
      expect(callCount, 1);

      // Invalida como o refresh button da tela faz
      container.invalidate(projectsProvider);

      await container.read(projectsNotifierProvider.future);
      expect(callCount, 2);
    });
  });

  group('Cadeia reativa — Deletar projeto', () {
    test('delete → optimistic remove → evento emitido → refetch confirma', () async {
      final svc = MockProjectService();
      final p1 = _p('p1', 'A Manter');
      final p2 = _p('p2', 'A Excluir');

      when(() => svc.fetchAll())
          .thenAnswer((_) async => [p1, p2])
          .thenAnswer((_) async => [p1]);
      when(() => svc.delete('p2')).thenAnswer((_) async {});

      final container = ProviderContainer(overrides: [
        projectServiceProvider.overrideWithValue(svc),
      ]);
      addTearDown(container.dispose);

      await container.read(projectsNotifierProvider.future);

      final events = <IveEvent>[];
      final sub = IveEventBus.instance.stream.listen(events.add);

      await container
          .read(projectsNotifierProvider.notifier)
          .delete('p2');

      await container.read(projectsNotifierProvider.future);
      await sub.cancel();

      // Lista não contém mais p2
      final ids = container
          .read(projectsNotifierProvider)
          .valueOrNull
          ?.map((p) => p.id)
          .toList();
      expect(ids, isNot(contains('p2')));
      expect(ids, contains('p1'));

      // Evento correto emitido
      final deleted = events.where(
        (e) => e.type == IveEventType.projectDeleted,
      );
      expect(deleted, hasLength(1));
      expect(deleted.first.entityName, 'A Excluir');
    });
  });

  group('Cadeia reativa — Mudar status', () {
    test('updateStatus → emite projectStatusChanged com status e nome corretos',
        () async {
      final svc = MockProjectService();
      final original = _p('p1', 'Meu Projeto');
      final updated = Project(
        id: 'p1',
        userId: 'uid',
        name: 'Meu Projeto',
        status: 'active',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      when(() => svc.fetchAll()).thenAnswer((_) async => [original]);
      when(() => svc.update('p1', any())).thenAnswer((_) async => updated);

      final container = ProviderContainer(overrides: [
        projectServiceProvider.overrideWithValue(svc),
      ]);
      addTearDown(container.dispose);

      await container.read(projectsNotifierProvider.future);

      final events = <IveEvent>[];
      final sub = IveEventBus.instance.stream.listen(events.add);

      await container
          .read(projectsNotifierProvider.notifier)
          .updateStatus('p1', 'active');

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      final statusEvents = events.where(
        (e) => e.type == IveEventType.projectStatusChanged,
      );
      expect(statusEvents, hasLength(1));
      expect(statusEvents.first.payload['status'], 'active');
      expect(statusEvents.first.entityName, 'Meu Projeto');
    });
  });
}
