import 'package:ai_social_copilot/data/models/action_queue_item.dart';
import 'package:ai_social_copilot/data/models/project.dart';
import 'package:ai_social_copilot/data/services/action_queue_service.dart';
import 'package:ai_social_copilot/data/services/project_service.dart';
import 'package:ai_social_copilot/features/ive/domain/ive_action_proposal.dart';
import 'package:ai_social_copilot/features/ive/services/ive_action_executor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockActionQueueService extends Mock implements ActionQueueService {}

class MockProjectService extends Mock implements ProjectServiceInterface {}

void main() {
  late MockActionQueueService actionService;
  late MockProjectService projectService;
  late ServiceBackedIveActionExecutor executor;
  late IveActionProposal proposal;

  Project ownedProject() => Project(
        id: 'project-1',
        userId: 'user-1',
        name: 'Projeto principal',
        createdAt: DateTime.utc(2026, 7, 18),
        updatedAt: DateTime.utc(2026, 7, 18),
      );

  ActionQueueItem persisted({
    String id = 'action-1',
    String userId = 'user-1',
    String projectId = 'project-1',
    String title = 'Validar oferta',
    List<String>? sources,
  }) =>
      ActionQueueItem(
        id: id,
        userId: userId,
        projectId: projectId,
        title: title,
        status: 'pending',
        createdAt: DateTime.utc(2026, 7, 18),
        sources: sources ?? [proposal.persistenceMarker],
      );

  setUpAll(() {
    registerFallbackValue(ActionQueueItem(
      id: '',
      userId: '',
      title: '',
      createdAt: DateTime.utc(2026),
    ));
  });

  setUp(() {
    actionService = MockActionQueueService();
    projectService = MockProjectService();
    executor = ServiceBackedIveActionExecutor(
      actionService: actionService,
      projectService: projectService,
    );
    final now = DateTime.now().toUtc();
    proposal = IveActionProposal(
      proposalId: 'proposal-1',
      userId: 'user-1',
      projectId: 'project-1',
      projectName: 'Projeto principal',
      title: 'Validar oferta',
      description: 'Entrevistar cinco clientes',
      priority: 80,
      impact: 90,
      effort: 30,
      rationale: 'Reduz o risco principal.',
      origin: 'ive',
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 15)),
    );

    when(() => actionService.currentUserId).thenReturn('user-1');
    when(() => projectService.fetchById('project-1'))
        .thenAnswer((_) async => ownedProject());
  });

  test('cria uma ação real e só conclui depois de reler e validar', () async {
    final created = persisted();
    when(() => actionService.fetchAll(projectId: 'project-1'))
        .thenAnswer((_) async => []);
    when(() => actionService.create(any())).thenAnswer((_) async => created);
    when(() => actionService.fetchById('action-1'))
        .thenAnswer((_) async => created);

    final result = await executor.execute(proposal);

    expect(result.action.id, 'action-1');
    expect(result.recoveredExisting, isFalse);
    verifyInOrder([
      () => projectService.fetchById('project-1'),
      () => actionService.fetchAll(projectId: 'project-1'),
      () => actionService.create(any()),
      () => actionService.fetchById('action-1'),
    ]);
  });

  test('repetir confirmação no mesmo executor não duplica a ação', () async {
    final created = persisted();
    when(() => actionService.fetchAll(projectId: 'project-1'))
        .thenAnswer((_) async => []);
    when(() => actionService.create(any())).thenAnswer((_) async => created);
    when(() => actionService.fetchById('action-1'))
        .thenAnswer((_) async => created);

    final first = await executor.execute(proposal);
    final second = await executor.execute(proposal);

    expect(second, same(first));
    verify(() => actionService.create(any())).called(1);
  });

  test('retry recupera ação pelo marcador persistente sem recriar', () async {
    final existing = persisted();
    when(() => actionService.fetchAll(projectId: 'project-1'))
        .thenAnswer((_) async => [existing]);

    final result = await executor.execute(proposal);

    expect(result.action.id, 'action-1');
    expect(result.recoveredExisting, isTrue);
    verifyNever(() => actionService.create(any()));
    verifyNever(() => actionService.fetchById(any()));
  });

  test('bloqueia sessão diferente da proposta', () async {
    when(() => actionService.currentUserId).thenReturn('user-2');

    await expectLater(executor.execute(proposal), throwsStateError);

    verifyNever(() => projectService.fetchById(any()));
    verifyNever(() => actionService.create(any()));
  });

  test('falha se a releitura não corresponder à proposta confirmada', () async {
    final created = persisted();
    final wrongProject = persisted(projectId: 'project-2');
    when(() => actionService.fetchAll(projectId: 'project-1'))
        .thenAnswer((_) async => []);
    when(() => actionService.create(any())).thenAnswer((_) async => created);
    when(() => actionService.fetchById('action-1'))
        .thenAnswer((_) async => wrongProject);

    await expectLater(executor.execute(proposal), throwsStateError);
  });

  test('14 retry após recriar executor recupera marcador sem duplicar',
      () async {
    final created = persisted();
    var fetchCount = 0;
    when(() => actionService.fetchAll(projectId: 'project-1'))
        .thenAnswer((_) async {
      fetchCount++;
      return fetchCount == 1 ? <ActionQueueItem>[] : [created];
    });
    when(() => actionService.create(any())).thenAnswer((_) async => created);
    when(() => actionService.fetchById('action-1'))
        .thenAnswer((_) async => created);

    await executor.execute(proposal);
    final recreatedExecutor = ServiceBackedIveActionExecutor(
      actionService: actionService,
      projectService: projectService,
    );
    final retry = await recreatedExecutor.execute(proposal);

    expect(retry.recoveredExisting, isTrue);
    expect(retry.proposalId, proposal.proposalId);
    expect(retry.idempotencyKey, proposal.idempotencyKey);
    verify(() => actionService.create(any())).called(1);
  });
}
