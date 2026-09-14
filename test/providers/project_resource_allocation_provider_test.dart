import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/models/project_resource_allocation.dart';
import 'package:ai_social_copilot/data/services/project_resource_allocation_service.dart';
import 'package:ai_social_copilot/providers/project_resource_allocation_provider.dart';

// ── Fake service — nunca toca Supabase.instance, evitando a classe de bug já
// corrigida uma vez neste projeto ("make ContextCopilotNotifier's Supabase
// client access lazy"). Implementa a interface diretamente, sem herdar da
// classe concreta. ─────────────────────────────────────────────────────────
class FakeProjectResourceAllocationService
    implements ProjectResourceAllocationServiceInterface {
  FakeProjectResourceAllocationService(this._current);

  ProjectResourceAllocation _current;
  int fetchCallCount = 0;
  int saveCallCount = 0;
  bool failNextSave = false;
  Duration saveDelay = Duration.zero;

  @override
  Future<ProjectResourceAllocation> fetch(String projectId) async {
    fetchCallCount++;
    return _current;
  }

  @override
  Future<ProjectResourceAllocation> save(ProjectResourceAllocation allocation) async {
    saveCallCount++;
    if (saveDelay > Duration.zero) await Future<void>.delayed(saveDelay);
    if (failNextSave) throw Exception('simulated save failure');
    _current = ProjectResourceAllocation(
      projectId: allocation.projectId,
      hoursAllocated: allocation.hoursAllocated,
      budgetAllocatedCents: allocation.budgetAllocatedCents,
      currency: allocation.currency,
      updatedAt: DateTime(2026, 9, 14),
    );
    return _current;
  }
}

const _projectId = 'p1';

ProjectResourceAllocation _allocation({
  int hours = 0,
  int cents = 0,
  String currency = 'BRL',
}) =>
    ProjectResourceAllocation(
      projectId: _projectId,
      hoursAllocated: hours,
      budgetAllocatedCents: cents,
      currency: currency,
      updatedAt: DateTime(2026, 1, 1),
    );

// `projectResourceAllocationProvider` is `.autoDispose` — a bare
// `container.read()` never keeps it alive (only `watch`/`listen` do), so
// without an explicit subscription the provider is disposed and silently
// recreated (back to AsyncLoading) between two `read()` calls in the same
// test. `container.listen` here plays the same role a widget's `ref.watch`
// plays in production: it keeps the element alive for the container's
// lifetime, exactly like the sheet's `ref.watch(...)` does when this
// section is actually on screen.
ProviderContainer _container(FakeProjectResourceAllocationService svc) {
  final container = ProviderContainer(
    overrides: [
      projectResourceAllocationServiceProvider.overrideWithValue(svc),
    ],
  );
  container.listen(projectResourceAllocationProvider(_projectId), (_, __) {});
  return container;
}

void main() {
  // ── Load inicial ────────────────────────────────────────────────────────
  group('Carregamento inicial', () {
    test('carrega o valor salvo e inicia preview == saved, status == saved', () async {
      final svc = FakeProjectResourceAllocationService(_allocation(hours: 20, cents: 500000));
      final container = _container(svc);
      addTearDown(container.dispose);

      expect(
        container.read(projectResourceAllocationProvider(_projectId)),
        const AsyncLoading<ProjectResourceAllocationEditState>(),
      );

      await Future<void>.delayed(Duration.zero);

      final state = container.read(projectResourceAllocationProvider(_projectId)).valueOrNull;
      expect(state, isNotNull);
      expect(state!.saved.hoursAllocated, 20);
      expect(state.preview.hoursAllocated, 20);
      expect(state.status, AllocationEditStatus.saved);
      expect(state.isDirty, isFalse);
      expect(svc.fetchCallCount, 1);
    });
  });

  // ── Edição só afeta o preview ───────────────────────────────────────────
  group('updateHoursPreview / updateBudgetPreviewCents', () {
    test('altera apenas preview, nunca saved, e marca status editing', () async {
      final svc = FakeProjectResourceAllocationService(_allocation(hours: 10, cents: 100000));
      final container = _container(svc);
      addTearDown(container.dispose);
      await Future<void>.delayed(Duration.zero);

      final notifier = container.read(projectResourceAllocationProvider(_projectId).notifier);
      notifier.updateHoursPreview(30);

      final state = container.read(projectResourceAllocationProvider(_projectId)).valueOrNull!;
      expect(state.preview.hoursAllocated, 30);
      expect(state.saved.hoursAllocated, 10);
      expect(state.status, AllocationEditStatus.editing);
      expect(state.isDirty, isTrue);
      expect(svc.saveCallCount, 0);
    });

    test('updateBudgetPreviewCents altera apenas o preview', () async {
      final svc = FakeProjectResourceAllocationService(_allocation(cents: 100000));
      final container = _container(svc);
      addTearDown(container.dispose);
      await Future<void>.delayed(Duration.zero);

      final notifier = container.read(projectResourceAllocationProvider(_projectId).notifier);
      notifier.updateBudgetPreviewCents(250000);

      final state = container.read(projectResourceAllocationProvider(_projectId)).valueOrNull!;
      expect(state.preview.budgetAllocatedCents, 250000);
      expect(state.saved.budgetAllocatedCents, 100000);
      expect(svc.saveCallCount, 0);
    });
  });

  // ── cancel() — Section 12: restaura o valor salvo exatamente ────────────
  group('cancel()', () {
    test('descarta o preview e restaura exatamente o saved', () async {
      final svc = FakeProjectResourceAllocationService(_allocation(hours: 15, cents: 300000));
      final container = _container(svc);
      addTearDown(container.dispose);
      await Future<void>.delayed(Duration.zero);

      final notifier = container.read(projectResourceAllocationProvider(_projectId).notifier);
      notifier.updateHoursPreview(999);
      notifier.updateBudgetPreviewCents(1);
      notifier.cancel();

      final state = container.read(projectResourceAllocationProvider(_projectId)).valueOrNull!;
      expect(state.preview.hoursAllocated, 15);
      expect(state.preview.budgetAllocatedCents, 300000);
      expect(state.status, AllocationEditStatus.saved);
      expect(state.isDirty, isFalse);
      expect(svc.saveCallCount, 0);
    });
  });

  // ── save() — ciclo SAVED → EDITING → SAVING → SAVED ─────────────────────
  group('save()', () {
    test('persiste o preview e promove a saved em caso de sucesso', () async {
      final svc = FakeProjectResourceAllocationService(_allocation(hours: 0, cents: 0));
      final container = _container(svc);
      addTearDown(container.dispose);
      await Future<void>.delayed(Duration.zero);

      final notifier = container.read(projectResourceAllocationProvider(_projectId).notifier);
      notifier.updateHoursPreview(50);
      notifier.updateBudgetPreviewCents(999900);

      await notifier.save();

      final state = container.read(projectResourceAllocationProvider(_projectId)).valueOrNull!;
      expect(state.status, AllocationEditStatus.saved);
      expect(state.saved.hoursAllocated, 50);
      expect(state.saved.budgetAllocatedCents, 999900);
      expect(state.preview.hoursAllocated, 50);
      expect(state.isDirty, isFalse);
      expect(svc.saveCallCount, 1);
    });

    test('em caso de erro, marca status error e preserva o preview em edição', () async {
      final svc = FakeProjectResourceAllocationService(_allocation(hours: 5, cents: 0))
        ..failNextSave = true;
      final container = _container(svc);
      addTearDown(container.dispose);
      await Future<void>.delayed(Duration.zero);

      final notifier = container.read(projectResourceAllocationProvider(_projectId).notifier);
      notifier.updateHoursPreview(60);
      await notifier.save();

      final state = container.read(projectResourceAllocationProvider(_projectId)).valueOrNull!;
      expect(state.status, AllocationEditStatus.error);
      expect(state.error, isNotNull);
      // O preview em edição não é perdido — o usuário pode tentar salvar de novo.
      expect(state.preview.hoursAllocated, 60);
      // saved permanece o último valor efetivamente persistido.
      expect(state.saved.hoursAllocated, 5);
    });

    test(
      'Codex Gate 1 P1 — edição feita DURANTE um save() em andamento não é '
      'perdida quando o save resolve (revision token)',
      () async {
        final svc = FakeProjectResourceAllocationService(_allocation(hours: 10, cents: 0))
          ..saveDelay = const Duration(milliseconds: 30);
        final container = _container(svc);
        addTearDown(container.dispose);
        await Future<void>.delayed(Duration.zero);

        final notifier = container.read(projectResourceAllocationProvider(_projectId).notifier);
        notifier.updateHoursPreview(20);
        final saveFuture = notifier.save(); // captura preview=20 antes do await

        // Edição mais nova chega enquanto o save de hours=20 ainda está em voo.
        await Future<void>.delayed(const Duration(milliseconds: 5));
        notifier.updateHoursPreview(999);

        await saveFuture;

        final state = container.read(projectResourceAllocationProvider(_projectId)).valueOrNull!;
        // A edição mais nova (999) NÃO pode ter sido sobrescrita pelo
        // resultado stale do save (20) — este é exatamente o bug do Gate 1.
        expect(state.preview.hoursAllocated, 999);
        expect(state.status, AllocationEditStatus.editing);
        // O baseline "saved" reflete o que o servidor de fato persistiu
        // (20), para que isDirty compare corretamente contra a realidade.
        expect(state.saved.hoursAllocated, 20);
        expect(state.isDirty, isTrue);
        expect(svc.saveCallCount, 1);
      },
    );

    test(
      'Codex Gate 1 P1 — cancel() durante um save() em andamento não é '
      'revertido quando o save resolve',
      () async {
        final svc = FakeProjectResourceAllocationService(_allocation(hours: 10, cents: 0))
          ..saveDelay = const Duration(milliseconds: 30);
        final container = _container(svc);
        addTearDown(container.dispose);
        await Future<void>.delayed(Duration.zero);

        final notifier = container.read(projectResourceAllocationProvider(_projectId).notifier);
        notifier.updateHoursPreview(20);
        final saveFuture = notifier.save();

        await Future<void>.delayed(const Duration(milliseconds: 5));
        notifier.cancel();

        await saveFuture;

        final state = container.read(projectResourceAllocationProvider(_projectId)).valueOrNull!;
        // cancel() já havia restaurado preview para o saved original (10) —
        // o save (que persistiu 20) não pode reverter isso de volta a 20.
        expect(state.preview.hoursAllocated, 10);
        expect(state.status, AllocationEditStatus.saved);
      },
    );

    test('uma segunda chamada de save() concorrente é um no-op (guard síncrono)', () async {
      final svc = FakeProjectResourceAllocationService(_allocation(hours: 0, cents: 0))
        ..saveDelay = const Duration(milliseconds: 30);
      final container = _container(svc);
      addTearDown(container.dispose);
      await Future<void>.delayed(Duration.zero);

      final notifier = container.read(projectResourceAllocationProvider(_projectId).notifier);
      notifier.updateHoursPreview(70);

      final firstSave = notifier.save();
      final secondSave = notifier.save(); // deve ser no-op — status já é "saving"

      await Future.wait([firstSave, secondSave]);

      expect(svc.saveCallCount, 1);
      final state = container.read(projectResourceAllocationProvider(_projectId)).valueOrNull!;
      expect(state.status, AllocationEditStatus.saved);
      expect(state.saved.hoursAllocated, 70);
    });
  });

  // ── isDirty ──────────────────────────────────────────────────────────────
  group('isDirty', () {
    test('é falso quando preview == saved em todos os campos', () async {
      final svc = FakeProjectResourceAllocationService(_allocation(hours: 8, cents: 1000, currency: 'USD'));
      final container = _container(svc);
      addTearDown(container.dispose);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(projectResourceAllocationProvider(_projectId)).valueOrNull!;
      expect(state.isDirty, isFalse);
    });
  });
}
