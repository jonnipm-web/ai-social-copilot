// Tests for the Opportunity Lab → Action Engine approval flow.
// Verifies: idempotency, error handling, no silent catches, correct sequencing.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ai_social_copilot/data/models/action_queue_item.dart';
import 'package:ai_social_copilot/data/models/opportunity_lab_item.dart';
import 'package:ai_social_copilot/data/services/action_queue_service.dart';
import 'package:ai_social_copilot/data/services/opportunity_lab_service.dart';
import 'package:ai_social_copilot/providers/action_queue_provider.dart';
import 'package:ai_social_copilot/providers/opportunity_lab_provider.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockOpportunityLabService extends Mock implements OpportunityLabService {}
class MockActionQueueService     extends Mock implements ActionQueueService {}

// ── Helpers ───────────────────────────────────────────────────────────────────

OpportunityLabItem _opportunity({
  String id     = 'opp-1',
  String status = 'pending',
  String title  = 'Oportunidade Teste',
  String? projectId,
  String? marketAnalysisId,
  int finalScore   = 70,
  int revenueScore = 60,
  int marketScore  = 75,
  int confidence   = 80,
}) =>
    OpportunityLabItem(
      id:               id,
      userId:           'user-1',
      opportunityType:  'revenue',
      title:            title,
      description:      'Descrição da oportunidade',
      status:           status,
      createdAt:        DateTime(2026, 7, 17),
      projectId:        projectId,
      marketAnalysisId: marketAnalysisId,
      finalScore:       finalScore,
      revenueScore:     revenueScore,
      marketScore:      marketScore,
      confidence:       confidence,
      sources:          const ['fonte-1'],
      rationale:        'Justificativa da IA',
      actionSteps:      const ['Passo 1', 'Passo 2'],
      risks:            const ['Risco 1'],
    );

ActionQueueItem _action({
  String id              = 'action-1',
  String opportunityLabId = 'opp-1',
  String status          = 'pending',
}) =>
    ActionQueueItem(
      id:               id,
      userId:           'user-1',
      actionType:       'opportunity',
      title:            '[Lab] Oportunidade Teste',
      priority:         70,
      impactScore:      60,
      effortScore:      50,
      roiScore:         70,
      marketScore:      75,
      confidence:       80,
      status:           status,
      createdAt:        DateTime(2026, 7, 17),
      opportunityLabId: opportunityLabId,
      origin:           'opportunity_lab',
      sources:          const ['fonte-1'],
      rationale:        'Justificativa da IA',
      plan:             const ['Passo 1', 'Passo 2'],
      risks:            const ['Risco 1'],
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockOpportunityLabService mockOppSvc;
  late MockActionQueueService    mockActionSvc;

  setUp(() {
    mockOppSvc    = MockOpportunityLabService();
    mockActionSvc = MockActionQueueService();

    registerFallbackValue(_opportunity());
    registerFallbackValue(_action());
  });

  ProviderContainer _container() => ProviderContainer(
    overrides: [
      opportunityLabServiceProvider.overrideWithValue(mockOppSvc),
      actionQueueServiceProvider.overrideWithValue(mockActionSvc),
    ],
  );

  // ── 1. Pending → creates exactly one action then approves ──────────────────
  test('pending opportunity creates action first, then approves', () async {
    final opp    = _opportunity();
    final action = _action();

    when(() => mockActionSvc.currentUserId).thenReturn('user-1');
    when(() => mockActionSvc.create(any())).thenAnswer((_) async => action);
    when(() => mockOppSvc.updateStatus('opp-1', 'approved')).thenAnswer((_) async => opp);
    when(() => mockOppSvc.fetchAll(projectId: any(named: 'projectId')))
        .thenAnswer((_) async => [opp.copyWith(status: 'approved')]);

    final container = _container();
    addTearDown(container.dispose);

    final oppNotifier    = container.read(opportunityLabNotifierProvider.notifier);
    final actionNotifier = container.read(actionQueueNotifierProvider.notifier);

    final result = await oppNotifier.approveAndCreateAction(opp, actionNotifier);

    expect(result.id, equals('action-1'));
    expect(result.opportunityLabId, equals('opp-1'));

    // Action created BEFORE opportunity approved
    verifyInOrder([
      () => mockActionSvc.create(any()),
      () => mockOppSvc.updateStatus('opp-1', 'approved'),
    ]);
  });

  // ── 2. Second call returns existing action (idempotent) ────────────────────
  test('second call for same opportunity returns existing action via service', () async {
    final opp    = _opportunity();
    final action = _action();

    when(() => mockActionSvc.currentUserId).thenReturn('user-1');
    // Service is idempotent: returns existing action on duplicate
    when(() => mockActionSvc.create(any())).thenAnswer((_) async => action);
    when(() => mockOppSvc.updateStatus(any(), any())).thenAnswer((_) async => opp);
    when(() => mockOppSvc.fetchAll(projectId: any(named: 'projectId')))
        .thenAnswer((_) async => [opp.copyWith(status: 'approved')]);

    final container = _container();
    addTearDown(container.dispose);

    final oppNotifier    = container.read(opportunityLabNotifierProvider.notifier);
    final actionNotifier = container.read(actionQueueNotifierProvider.notifier);

    final result1 = await oppNotifier.approveAndCreateAction(opp, actionNotifier);
    final result2 = await oppNotifier.approveAndCreateAction(opp, actionNotifier);

    // Both calls return the same action
    expect(result1.id, equals(result2.id));
  });

  // ── 3. Already-approved opportunity does not call updateStatus again ────────
  test('already-approved opportunity skips updateStatus', () async {
    final opp    = _opportunity(status: 'approved');
    final action = _action();

    when(() => mockActionSvc.currentUserId).thenReturn('user-1');
    when(() => mockActionSvc.create(any())).thenAnswer((_) async => action);
    when(() => mockOppSvc.fetchAll(projectId: any(named: 'projectId')))
        .thenAnswer((_) async => [opp]);

    final container = _container();
    addTearDown(container.dispose);

    final oppNotifier    = container.read(opportunityLabNotifierProvider.notifier);
    final actionNotifier = container.read(actionQueueNotifierProvider.notifier);

    await oppNotifier.approveAndCreateAction(opp, actionNotifier);

    // updateStatus must NOT be called for already-approved opportunity
    verifyNever(() => mockOppSvc.updateStatus(any(), any()));
  });

  // ── 4. Action creation failure does NOT approve the opportunity ─────────────
  test('if action creation fails, opportunity is not approved', () async {
    final opp = _opportunity();

    when(() => mockActionSvc.currentUserId).thenReturn('user-1');
    when(() => mockActionSvc.create(any()))
        .thenThrow(Exception('Network error'));

    final container = _container();
    addTearDown(container.dispose);

    final oppNotifier    = container.read(opportunityLabNotifierProvider.notifier);
    final actionNotifier = container.read(actionQueueNotifierProvider.notifier);

    await expectLater(
      oppNotifier.approveAndCreateAction(opp, actionNotifier),
      throwsException,
    );

    // Opportunity must not be approved when action creation fails
    verifyNever(() => mockOppSvc.updateStatus(any(), any()));
  });

  // ── 5. Error propagates — no silent catch ──────────────────────────────────
  test('action creation error propagates to caller — no silent swallow', () async {
    final opp = _opportunity();

    when(() => mockActionSvc.currentUserId).thenReturn('user-1');
    when(() => mockActionSvc.create(any()))
        .thenThrow(Exception('Supabase error'));

    final container = _container();
    addTearDown(container.dispose);

    final oppNotifier    = container.read(opportunityLabNotifierProvider.notifier);
    final actionNotifier = container.read(actionQueueNotifierProvider.notifier);

    expect(
      () => oppNotifier.approveAndCreateAction(opp, actionNotifier),
      throwsException,
    );
  });

  // ── 6. Context preserved: key fields mapped correctly ─────────────────────
  test('action preserves opportunity context fields', () async {
    final opp = _opportunity(
      projectId:        'proj-1',
      marketAnalysisId: 'analysis-1',
      finalScore:       85,
      revenueScore:     70,
      marketScore:      90,
      confidence:       88,
    );

    ActionQueueItem? capturedItem;
    when(() => mockActionSvc.currentUserId).thenReturn('user-1');
    when(() => mockActionSvc.create(any())).thenAnswer((invocation) async {
      capturedItem = invocation.positionalArguments.first as ActionQueueItem;
      return _action();
    });
    when(() => mockOppSvc.updateStatus(any(), any())).thenAnswer((_) async => opp);
    when(() => mockOppSvc.fetchAll(projectId: any(named: 'projectId')))
        .thenAnswer((_) async => [opp]);

    final container = _container();
    addTearDown(container.dispose);

    final oppNotifier    = container.read(opportunityLabNotifierProvider.notifier);
    final actionNotifier = container.read(actionQueueNotifierProvider.notifier);

    await oppNotifier.approveAndCreateAction(opp, actionNotifier);

    expect(capturedItem, isNotNull);
    expect(capturedItem!.projectId,        equals('proj-1'));
    expect(capturedItem!.marketAnalysisId, equals('analysis-1'));
    expect(capturedItem!.opportunityLabId, equals('opp-1'));
    expect(capturedItem!.marketScore,      equals(90));
    expect(capturedItem!.confidence,       equals(88));
    expect(capturedItem!.roiScore,         equals(85));
    expect(capturedItem!.impactScore,      equals(70));
    expect(capturedItem!.origin,           equals('opportunity_lab'));
  });

  // ── 7. fetchByOpportunityLabId wired correctly ────────────────────────────
  test('fetchByOpportunityLabId returns action for given opportunity id', () async {
    final action = _action();

    when(() => mockActionSvc.fetchByOpportunityLabId('opp-1'))
        .thenAnswer((_) async => action);

    final container = _container();
    addTearDown(container.dispose);

    final result = await container
        .read(actionByOpportunityLabIdProvider('opp-1').future);

    expect(result?.id, equals('action-1'));
    expect(result?.opportunityLabId, equals('opp-1'));
  });
}
