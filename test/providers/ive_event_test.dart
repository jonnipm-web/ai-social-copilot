import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/core/services/ive_event_bus.dart';
import 'package:ai_social_copilot/data/models/ive_event.dart';

void main() {
  // ── IveEventType enum ─────────────────────────────────────────────────────
  group('IveEventType', () {
    test('contém os 4 tipos de projeto', () {
      expect(IveEventType.values, contains(IveEventType.projectCreated));
      expect(IveEventType.values, contains(IveEventType.projectUpdated));
      expect(IveEventType.values, contains(IveEventType.projectStatusChanged));
      expect(IveEventType.values, contains(IveEventType.projectDeleted));
    });

    test('tem ao menos 14 valores (4 projeto + 10 outros)', () {
      expect(IveEventType.values.length, greaterThanOrEqualTo(14));
    });
  });

  // ── IveEvent factories de projeto ─────────────────────────────────────────
  group('IveEvent factories de projeto', () {
    test('projectCreated preenche entityId e entityName', () {
      final event = IveEvent.projectCreated(
        projectId: 'abc',
        projectName: 'Meu Blog',
      );
      expect(event.type, IveEventType.projectCreated);
      expect(event.entityId, 'abc');
      expect(event.entityName, 'Meu Blog');
      expect(event.payload, isEmpty);
      expect(event.issue, isNull);
    });

    test('projectUpdated preenche entityId e entityName', () {
      final event = IveEvent.projectUpdated(
        projectId: 'xyz',
        projectName: 'Projeto Atualizado',
      );
      expect(event.type, IveEventType.projectUpdated);
      expect(event.entityId, 'xyz');
      expect(event.entityName, 'Projeto Atualizado');
    });

    test('projectStatusChanged inclui status no payload', () {
      final event = IveEvent.projectStatusChanged(
        projectId: 'p1',
        projectName: 'Proj A',
        status: 'active',
      );
      expect(event.type, IveEventType.projectStatusChanged);
      expect(event.payload['status'], 'active');
      expect(event.entityId, 'p1');
      expect(event.entityName, 'Proj A');
    });

    test('projectDeleted preenche entityId e entityName', () {
      final event = IveEvent.projectDeleted(
        projectId: 'del-1',
        projectName: 'Projeto Removido',
      );
      expect(event.type, IveEventType.projectDeleted);
      expect(event.entityId, 'del-1');
      expect(event.entityName, 'Projeto Removido');
    });

    test('timestamp é próximo ao DateTime.now()', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final event = IveEvent.projectCreated(projectId: 'x', projectName: 'Y');
      final after = DateTime.now().add(const Duration(seconds: 1));

      expect(event.timestamp.isAfter(before), isTrue);
      expect(event.timestamp.isBefore(after), isTrue);
    });
  });

  // ── IveEventBus ───────────────────────────────────────────────────────────
  group('IveEventBus', () {
    test('é um singleton', () {
      expect(identical(IveEventBus.instance, IveEventBus.instance), isTrue);
    });

    test('emit publica evento para stream', () async {
      final event = IveEvent.projectCreated(
        projectId: 'bus-p1',
        projectName: 'Bus Test',
      );

      final received = <IveEvent>[];
      final sub = IveEventBus.instance.stream.listen(received.add);

      IveEventBus.instance.emit(event);

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(received, hasLength(1));
      expect(received.first.entityId, 'bus-p1');
    });

    test('múltiplos subscribers recebem o mesmo evento', () async {
      final event = IveEvent.projectDeleted(
        projectId: 'multi-p',
        projectName: 'Multi',
      );

      final r1 = <IveEvent>[];
      final r2 = <IveEvent>[];
      final s1 = IveEventBus.instance.stream.listen(r1.add);
      final s2 = IveEventBus.instance.stream.listen(r2.add);

      IveEventBus.instance.emit(event);

      await Future<void>.delayed(Duration.zero);
      await s1.cancel();
      await s2.cancel();

      expect(r1, hasLength(1));
      expect(r2, hasLength(1));
      expect(r1.first.type, IveEventType.projectDeleted);
    });

    test('stream é broadcast — subscriptions independentes', () async {
      final stream = IveEventBus.instance.stream;
      // Deve poder escutar múltiplas vezes sem erro
      final s1 = stream.listen((_) {});
      final s2 = stream.listen((_) {});
      expect(s1, isNotNull);
      expect(s2, isNotNull);
      await s1.cancel();
      await s2.cancel();
    });
  });
}
