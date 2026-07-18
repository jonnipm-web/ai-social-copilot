// Testes de guard de autenticação nos services.
// Validam que todos os services críticos lançam exceção quando
// não há sessão ativa (currentUser == null).
//
// Como os services dependem de Supabase.instance.client em runtime,
// e Supabase não está inicializado no ambiente de teste, .currentUser
// retorna null → os guards lançam Exception antes de qualquer query.
// Isso é exatamente o comportamento que queremos verificar.

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ai_social_copilot/data/models/action_queue_item.dart';
import 'package:ai_social_copilot/data/models/calendar_item.dart';
import 'package:ai_social_copilot/data/models/content_item.dart';
import 'package:ai_social_copilot/data/models/knowledge_item.dart';
import 'package:ai_social_copilot/data/models/opportunity_lab_item.dart';
import 'package:ai_social_copilot/data/models/post_generation.dart';
import 'package:ai_social_copilot/data/services/action_queue_service.dart';
import 'package:ai_social_copilot/data/services/business_memory_service.dart';
import 'package:ai_social_copilot/data/services/calendar_service.dart';
import 'package:ai_social_copilot/data/services/campaign_service.dart';
import 'package:ai_social_copilot/data/services/content_service.dart';
import 'package:ai_social_copilot/data/services/copilot_service.dart';
import 'package:ai_social_copilot/data/services/knowledge_service.dart';
import 'package:ai_social_copilot/data/services/opportunity_lab_service.dart';
import 'package:ai_social_copilot/data/services/performance_service.dart';
import 'package:ai_social_copilot/data/services/persona_training_service.dart';
import 'package:ai_social_copilot/data/services/post_service.dart';
import 'package:ai_social_copilot/data/services/project_service.dart';
import 'package:ai_social_copilot/data/services/roi_metric_service.dart';
import 'package:ai_social_copilot/data/services/website_analyzer_service.dart';

// ── Helper ────────────────────────────────────────────────────────────────────

Matcher throwsNotAuthenticated() => throwsA(
      isA<Exception>().having(
        (e) => e.toString(),
        'message',
        anyOf(
          contains('autenticado'),
          contains('Autenticado'),
          contains('authenticated'),
        ),
      ),
    );

// ── Fake model builders ───────────────────────────────────────────────────────

KnowledgeItem _fakeKnowledgeItem() => KnowledgeItem(
      id: '', userId: '', title: 'Test', content: '',
      createdAt: DateTime(2026), updatedAt: DateTime(2026),
    );

ActionQueueItem _fakeActionQueueItem() => ActionQueueItem(
      id: '', userId: '', title: 'Test',
      createdAt: DateTime(2026),
    );

OpportunityLabItem _fakeOpportunityLabItem() => OpportunityLabItem(
      id: '', userId: '', title: 'Test',
      createdAt: DateTime(2026),
    );

CalendarItem _fakeCalendarItem() => CalendarItem(
      id: '', userId: '',
      createdAt: DateTime(2026), updatedAt: DateTime(2026),
    );

ContentItem _fakeContentItem() => ContentItem(
      id: '', userId: '', type: 'artigo', title: 'Test',
      createdAt: DateTime(2026), updatedAt: DateTime(2026),
    );

PostGeneration _fakePostGeneration() => PostGeneration(
      id: '', userId: '', originalText: '', improvedText: '',
      professionalVersion: '', casualVersion: '', persuasiveVersion: '',
      commentReply: '', clarityScore: 0, impactScore: 0, engagementScore: 0,
      createdAt: DateTime(2026),
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() async {
    try {
      await Supabase.initialize(
        url: 'http://localhost:54321',
        anonKey: 'test-anon-key',
      );
    } catch (_) {}
  });

  group('Auth guard — fetchAll() sem sessão', () {
    test('PostService.fetchHistory() lança exceção', () {
      expect(PostService().fetchHistory(), throwsNotAuthenticated());
    });

    test('PostService.countMonthlyGenerations() lança exceção', () {
      expect(PostService().countMonthlyGenerations(), throwsNotAuthenticated());
    });

    test('CampaignService.fetchAll() lança exceção', () {
      expect(CampaignService().fetchAll(), throwsNotAuthenticated());
    });

    test('PerformanceService.fetchAll() lança exceção', () {
      expect(PerformanceService().fetchAll(), throwsNotAuthenticated());
    });

    test('RoiMetricService.fetchAll() lança exceção', () {
      expect(RoiMetricService().fetchAll(), throwsNotAuthenticated());
    });

    test('BusinessMemoryService.fetchAll() lança exceção', () {
      expect(BusinessMemoryService().fetchAll(), throwsNotAuthenticated());
    });

    // Testa os filtros condicionais (projectId e memoryType) — validam
    // que os parâmetros compilam corretamente após a correção que moveu
    // .order() para depois dos filtros (evitando TypeError em TransformBuilder).
    test('BusinessMemoryService.fetchAll(projectId:) lança exceção antes de query', () {
      expect(
        BusinessMemoryService().fetchAll(projectId: 'proj-test'),
        throwsNotAuthenticated(),
      );
    });

    test('BusinessMemoryService.fetchAll(memoryType:) lança exceção antes de query', () {
      expect(
        BusinessMemoryService().fetchAll(memoryType: 'opportunity'),
        throwsNotAuthenticated(),
      );
    });

    test('ProjectService.fetchAll() lança exceção', () {
      expect(ProjectService().fetchAll(), throwsNotAuthenticated());
    });

    test('KnowledgeService.fetchAll() lança exceção', () {
      expect(KnowledgeService().fetchAll(), throwsNotAuthenticated());
    });

    test('ActionQueueService.fetchAll() lança exceção', () {
      expect(ActionQueueService().fetchAll(), throwsNotAuthenticated());
    });

    test('OpportunityLabService.fetchAll() lança exceção', () {
      expect(OpportunityLabService().fetchAll(), throwsNotAuthenticated());
    });

    test('CalendarService.fetchAll() lança exceção', () {
      expect(CalendarService().fetchAll(), throwsNotAuthenticated());
    });

    test('ContentService.fetchAll() lança exceção', () {
      expect(ContentService().fetchAll(), throwsNotAuthenticated());
    });

    test('PersonaTrainingService.fetchAll() lança exceção', () {
      expect(PersonaTrainingService().fetchAll(), throwsNotAuthenticated());
    });

    test('WebsiteAnalyzerService.fetchAll() lança exceção', () {
      expect(WebsiteAnalyzerService().fetchAll(), throwsNotAuthenticated());
    });

    test('CopilotService.fetchSessions() lança exceção', () {
      expect(CopilotService().fetchSessions(), throwsNotAuthenticated());
    });
  });

  group('Auth guard — create() sem sessão', () {
    test('KnowledgeService.create() lança exceção', () {
      expect(
        KnowledgeService().create(_fakeKnowledgeItem()),
        throwsNotAuthenticated(),
      );
    });

    test('ActionQueueService.create() lança exceção', () {
      expect(
        ActionQueueService().create(_fakeActionQueueItem()),
        throwsNotAuthenticated(),
      );
    });

    test('OpportunityLabService.create() lança exceção', () {
      expect(
        OpportunityLabService().create(_fakeOpportunityLabItem()),
        throwsNotAuthenticated(),
      );
    });

    test('CalendarService.create() lança exceção', () {
      expect(
        CalendarService().create(_fakeCalendarItem()),
        throwsNotAuthenticated(),
      );
    });

    test('ContentService.create() lança exceção', () {
      expect(
        ContentService().create(_fakeContentItem()),
        throwsNotAuthenticated(),
      );
    });

    test('PostService.saveGeneration() lança exceção', () {
      expect(
        PostService().saveGeneration(_fakePostGeneration()),
        throwsNotAuthenticated(),
      );
    });
  });
}
