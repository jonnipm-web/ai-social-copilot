import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/models/project_resource_allocation.dart';
import 'package:ai_social_copilot/data/services/project_resource_allocation_service.dart';
import 'package:ai_social_copilot/providers/project_resource_allocation_provider.dart';

// ── Fake service — nunca toca Supabase.instance, evitando a classe de bug já
// corrigida uma vez neste projeto ("make ContextCopilotNotifier's Supabase
// client access lazy"). Implementa a interface diretamente, sem herdar da
// classe concreta. ─────────────────────────────────────────────────────────
// Codex Gate 1 (mission 12, Phase B) P2 — this fake used to hold a single
// `_current` field and IGNORE the `projectId` argument passed to
// fetch()/save() entirely, so no test using it could ever prove the
// provider/service pair actually routes by project — a two-project mixup
// would have passed silently. Now keyed by projectId, like the real
// Supabase-backed service is keyed by its `project_id` column.
class FakeProjectResourceAllocationService
    implements ProjectResourceAllocationServiceInterface {
  FakeProjectResourceAllocationService(ProjectResourceAllocation initial)
      : _byProject = {initial.projectId: initial};

  FakeProjectResourceAllocationService.multi(
    Map<String, ProjectResourceAllocation> initial,
  ) : _byProject = Map.of(initial);

  final Map<String, ProjectResourceAllocation> _byProject;
  int fetchCallCount = 0;
  int saveCallCount = 0;
  bool failNextSave = false;
  Duration saveDelay = Duration.zero;

  @override
  Future<ProjectResourceAllocation> fetch(String projectId) async {
    fetchCallCount++;
    return _byProject[projectId] ?? ProjectResourceAllocation.empty(projectId);
  }

  @override
  Future<ProjectResourceAllocation> save(ProjectResourceAllocation allocation) async {
    saveCallCount++;
    if (saveDelay > Duration.zero) await Future<void>.delayed(saveDelay);
    if (failNextSave) throw Exception('simulated save failure');
    final saved = ProjectResourceAllocation(
      projectId: allocation.projectId,
      hoursAllocated: allocation.hoursAllocated,
      budgetAllocatedCents: allocation.budgetAllocatedCents,
      currency: allocation.currency,
      updatedAt: DateTime(2026, 9, 14),
    );
    _byProject[allocation.projectId] = saved;
    return saved;
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
ProviderContainer _container(
  FakeProjectResourceAllocationService svc, {
  String projectId = _projectId,
}) {
  final container = ProviderContainer(
    overrides: [
      projectResourceAllocationServiceProvider.overrideWithValue(svc),
    ],
  );
  container.listen(projectResourceAllocationProvider(projectId), (_, __) {});
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

  // ── Roteamento por projeto — Codex Gate 1 P2 ────────────────────────────
  group('roteamento por projectId', () {
    test(
      'dois projetos diferentes carregam e salvam de forma isolada, '
      'sem vazar dados entre providers (mesmo container/serviço)',
      () async {
        final svc = FakeProjectResourceAllocationService.multi({
          'p1': ProjectResourceAllocation(
            projectId: 'p1',
            hoursAllocated: 10,
            budgetAllocatedCents: 100000,
            currency: 'BRL',
            updatedAt: DateTime(2026, 1, 1),
          ),
          'p2': ProjectResourceAllocation(
            projectId: 'p2',
            hoursAllocated: 999,
            budgetAllocatedCents: 5000000,
            currency: 'USD',
            updatedAt: DateTime(2026, 1, 1),
          ),
        });

        final container = ProviderContainer(
          overrides: [
            projectResourceAllocationServiceProvider.overrideWithValue(svc),
          ],
        );
        addTearDown(container.dispose);
        container.listen(projectResourceAllocationProvider('p1'), (_, __) {});
        container.listen(projectResourceAllocationProvider('p2'), (_, __) {});
        await Future<void>.delayed(Duration.zero);

        final state1 = container.read(projectResourceAllocationProvider('p1')).valueOrNull!;
        final state2 = container.read(projectResourceAllocationProvider('p2')).valueOrNull!;

        // Cada provider carregou o valor do SEU PRÓPRIO projeto — a falha
        // que o fake antigo (com um único `_current` ignorando projectId)
        // não conseguia detectar.
        expect(state1.saved.hoursAllocated, 10);
        expect(state1.saved.currency, 'BRL');
        expect(state2.saved.hoursAllocated, 999);
        expect(state2.saved.currency, 'USD');

        // Editar/salvar em p1 não pode afetar p2.
        final notifier1 = container.read(projectResourceAllocationProvider('p1').notifier);
        notifier1.updateHoursPreview(77);
        await notifier1.save();

        final after1 = container.read(projectResourceAllocationProvider('p1')).valueOrNull!;
        final after2 = container.read(projectResourceAllocationProvider('p2')).valueOrNull!;
        expect(after1.saved.hoursAllocated, 77);
        expect(after2.saved.hoursAllocated, 999); // p2 intacto
      },
    );
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
