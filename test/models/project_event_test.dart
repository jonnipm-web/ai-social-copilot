import 'package:flutter_test/flutter_test.dart';
import 'package:ai_social_copilot/data/models/project_event.dart';

void main() {
  group('ProjectEvent', () {
    group('fromJson / toJson round-trip', () {
      test('parses all fields correctly', () {
        final json = {
          'id': 'evt-1',
          'project_id': 'proj-1',
          'user_id': 'user-1',
          'event_type': 'analysis_completed',
          'title': 'Análise concluída',
          'description': 'Score: 85',
          'metadata': {'opportunity_score': 85},
          'source_module': 'market_intelligence',
          'source_entity_id': 'analysis-uuid',
          'idempotency_key': 'proj-1_analysisCompleted_analysis-uuid',
          'created_at': '2026-01-15T10:00:00.000Z',
        };

        final event = ProjectEvent.fromJson(json);

        expect(event.id, 'evt-1');
        expect(event.projectId, 'proj-1');
        expect(event.userId, 'user-1');
        expect(event.eventType, ProjectEventType.analysisCompleted);
        expect(event.title, 'Análise concluída');
        expect(event.description, 'Score: 85');
        expect(event.metadata, {'opportunity_score': 85});
        expect(event.sourceModule, 'market_intelligence');
        expect(event.sourceEntityId, 'analysis-uuid');
        expect(event.idempotencyKey, 'proj-1_analysisCompleted_analysis-uuid');
        expect(event.createdAt.year, 2026);
      });

      test('toJson omits null optional fields', () {
        final event = ProjectEvent(
          id: 'evt-2',
          projectId: 'proj-2',
          userId: 'user-2',
          eventType: ProjectEventType.projectCreated,
          title: 'Projeto criado',
          description: '',
          createdAt: DateTime.now(),
        );

        final json = event.toJson();

        expect(json.containsKey('source_module'), isFalse);
        expect(json.containsKey('source_entity_id'), isFalse);
        expect(json.containsKey('idempotency_key'), isFalse);
        expect(json['event_type'], 'project_created');
      });

      test('toJson includes optional fields when present', () {
        final event = ProjectEvent(
          id: 'evt-3',
          projectId: 'proj-3',
          userId: 'user-3',
          eventType: ProjectEventType.documentAdded,
          title: 'Doc adicionado',
          description: '',
          sourceModule: 'knowledge_vault',
          sourceEntityId: 'doc-uuid',
          idempotencyKey: 'proj-3_documentAdded_doc-uuid',
          createdAt: DateTime.now(),
        );

        final json = event.toJson();

        expect(json['source_module'], 'knowledge_vault');
        expect(json['source_entity_id'], 'doc-uuid');
        expect(json['idempotency_key'], 'proj-3_documentAdded_doc-uuid');
      });
    });

    group('event type mapping', () {
      test('all types serialize to snake_case DB values', () {
        final expected = {
          ProjectEventType.projectCreated: 'project_created',
          ProjectEventType.stageChanged: 'stage_changed',
          ProjectEventType.analysisCompleted: 'analysis_completed',
          ProjectEventType.decisionTaken: 'decision_taken',
          ProjectEventType.opportunityCreated: 'opportunity_created',
          ProjectEventType.documentAdded: 'document_added',
          ProjectEventType.actionCompleted: 'action_completed',
          ProjectEventType.checkIn: 'check_in',
          ProjectEventType.interviewCompleted: 'interview_completed',
          ProjectEventType.relationshipDetected: 'relationship_detected',
          ProjectEventType.healthChanged: 'health_changed',
          ProjectEventType.priorityChanged: 'priority_changed',
        };

        for (final entry in expected.entries) {
          final event = ProjectEvent(
            id: '',
            projectId: '',
            userId: '',
            eventType: entry.key,
            title: '',
            description: '',
            createdAt: DateTime.now(),
          );
          expect(event.toJson()['event_type'], entry.value,
              reason: 'Type ${entry.key} should map to "${entry.value}"');
        }
      });

      test('fromJson round-trips all type strings', () {
        final types = [
          'project_created',
          'stage_changed',
          'analysis_completed',
          'decision_taken',
          'opportunity_created',
          'document_added',
          'action_completed',
          'check_in',
          'interview_completed',
          'relationship_detected',
          'health_changed',
          'priority_changed',
        ];

        for (final t in types) {
          final json = {
            'id': '',
            'project_id': '',
            'user_id': '',
            'event_type': t,
            'title': '',
            'description': '',
            'metadata': <String, dynamic>{},
            'created_at': DateTime.now().toIso8601String(),
          };
          final event = ProjectEvent.fromJson(json);
          expect(event.toJson()['event_type'], t,
              reason: 'Type string "$t" should round-trip correctly');
        }
      });

      test('unknown type defaults to checkIn', () {
        final json = {
          'id': '',
          'project_id': '',
          'user_id': '',
          'event_type': 'unknown_event_type',
          'title': '',
          'description': '',
          'metadata': <String, dynamic>{},
          'created_at': DateTime.now().toIso8601String(),
        };
        final event = ProjectEvent.fromJson(json);
        expect(event.eventType, ProjectEventType.checkIn);
      });
    });

    group('filterGroup getter', () {
      test('analysis types map to Análises', () {
        for (final t in [
          ProjectEventType.analysisCompleted,
          ProjectEventType.healthChanged,
          ProjectEventType.priorityChanged,
        ]) {
          final e = ProjectEvent(
            id: '',
            projectId: '',
            userId: '',
            eventType: t,
            title: '',
            description: '',
            createdAt: DateTime.now(),
          );
          expect(e.filterGroup, 'Análises', reason: '$t should be Análises');
        }
      });

      test('knowledge types map to Conhecimento', () {
        for (final t in [
          ProjectEventType.documentAdded,
          ProjectEventType.interviewCompleted,
        ]) {
          final e = ProjectEvent(
            id: '',
            projectId: '',
            userId: '',
            eventType: t,
            title: '',
            description: '',
            createdAt: DateTime.now(),
          );
          expect(e.filterGroup, 'Conhecimento',
              reason: '$t should be Conhecimento');
        }
      });

      test('decision types map to Decisões', () {
        for (final t in [
          ProjectEventType.decisionTaken,
          ProjectEventType.checkIn,
        ]) {
          final e = ProjectEvent(
            id: '',
            projectId: '',
            userId: '',
            eventType: t,
            title: '',
            description: '',
            createdAt: DateTime.now(),
          );
          expect(e.filterGroup, 'Decisões', reason: '$t should be Decisões');
        }
      });

      test('opportunityCreated maps to Oportunidades', () {
        final e = ProjectEvent(
          id: '',
          projectId: '',
          userId: '',
          eventType: ProjectEventType.opportunityCreated,
          title: '',
          description: '',
          createdAt: DateTime.now(),
        );
        expect(e.filterGroup, 'Oportunidades');
      });

      test('actionCompleted maps to Ações', () {
        final e = ProjectEvent(
          id: '',
          projectId: '',
          userId: '',
          eventType: ProjectEventType.actionCompleted,
          title: '',
          description: '',
          createdAt: DateTime.now(),
        );
        expect(e.filterGroup, 'Ações');
      });

      test('project lifecycle types map to Projeto', () {
        for (final t in [
          ProjectEventType.projectCreated,
          ProjectEventType.stageChanged,
          ProjectEventType.relationshipDetected,
        ]) {
          final e = ProjectEvent(
            id: '',
            projectId: '',
            userId: '',
            eventType: t,
            title: '',
            description: '',
            createdAt: DateTime.now(),
          );
          expect(e.filterGroup, 'Projeto', reason: '$t should be Projeto');
        }
      });
    });

    group('emoji getter', () {
      test('each type returns non-empty emoji', () {
        for (final t in ProjectEventType.values) {
          final e = ProjectEvent(
            id: '',
            projectId: '',
            userId: '',
            eventType: t,
            title: '',
            description: '',
            createdAt: DateTime.now(),
          );
          expect(e.emoji.isNotEmpty, isTrue, reason: '$t should have an emoji');
        }
      });
    });

    group('null-safe parsing', () {
      test('handles missing optional fields gracefully', () {
        final json = <String, dynamic>{
          'id': 'evt-null',
          'project_id': 'proj-1',
          'user_id': 'user-1',
          'event_type': 'check_in',
          'created_at': '2026-01-01T00:00:00.000Z',
        };

        expect(() => ProjectEvent.fromJson(json), returnsNormally);
        final event = ProjectEvent.fromJson(json);
        expect(event.title, '');
        expect(event.description, '');
        expect(event.metadata, isEmpty);
        expect(event.sourceModule, isNull);
        expect(event.sourceEntityId, isNull);
        expect(event.idempotencyKey, isNull);
      });

      test('handles invalid date gracefully', () {
        final json = <String, dynamic>{
          'id': '',
          'project_id': '',
          'user_id': '',
          'event_type': 'check_in',
          'created_at': 'not-a-date',
        };

        final event = ProjectEvent.fromJson(json);
        expect(event.createdAt, isA<DateTime>());
      });
    });
  });
}
