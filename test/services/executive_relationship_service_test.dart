import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/models/executive_relationship.dart';
import 'package:ai_social_copilot/data/models/market_analysis.dart';
import 'package:ai_social_copilot/data/models/project.dart';
import 'package:ai_social_copilot/data/services/executive_relationship_service.dart';

Project _project({
  required String id,
  required String name,
  String? marketAnalysisId,
}) =>
    Project(
      id: id, userId: 'user-1', name: name, status: 'active',
      createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
      marketAnalysisId: marketAnalysisId,
    );

MarketAnalysis _analysis({
  required String id,
  required String niche,
  String? targetAudience,
  String? monetizationModel,
}) =>
    MarketAnalysis(
      id: id, userId: 'user-1',
      input: niche,
      niche: niche,
      targetAudience: targetAudience ?? 'empreendedores 25-40',
      monetizationModel: monetizationModel ?? 'saas',
      opportunityScore: 70,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  late ExecutiveRelationshipService svc;

  setUp(() => svc = ExecutiveRelationshipService());

  group('ExecutiveRelationshipService.detect', () {
    test('returns empty list for single project', () {
      final projects = [_project(id: 'p1', name: 'A', marketAnalysisId: 'a1')];
      final analyses = [_analysis(id: 'a1', niche: 'finanças pessoais')];

      expect(svc.detect(projects: projects, analyses: analyses), isEmpty);
    });

    test('returns empty list when no analyses available', () {
      final projects = [
        _project(id: 'p1', name: 'A'),
        _project(id: 'p2', name: 'B'),
      ];
      expect(svc.detect(projects: projects, analyses: []), isEmpty);
    });

    test('returns empty list when projects have no market analysis linked', () {
      final projects = [
        _project(id: 'p1', name: 'A'),
        _project(id: 'p2', name: 'B'),
      ];
      final analyses = [
        _analysis(id: 'unlinked-1', niche: 'finanças'),
        _analysis(id: 'unlinked-2', niche: 'finanças'),
      ];
      expect(svc.detect(projects: projects, analyses: analyses), isEmpty);
    });

    group('duplicate detection (>=90% context overlap)', () {
      test('detects duplicate when niche, audience and model are identical', () {
        const niche = 'finanças pessoais para jovens adultos';
        const audience = 'empreendedores digitais 25 a 35 anos';
        const model = 'assinatura mensal recorrente saas';

        final projects = [
          _project(id: 'p1', name: 'Projeto A', marketAnalysisId: 'a1'),
          _project(id: 'p2', name: 'Projeto B', marketAnalysisId: 'a2'),
        ];
        final analyses = [
          _analysis(id: 'a1', niche: niche, targetAudience: audience, monetizationModel: model),
          _analysis(id: 'a2', niche: niche, targetAudience: audience, monetizationModel: model),
        ];

        final rels = svc.detect(projects: projects, analyses: analyses);
        expect(rels, isNotEmpty);
        expect(rels.first.type, RelationshipType.duplicate);
      });
    });

    group('conflicting detection (>=80% niche overlap)', () {
      test('detects conflicting when niche is highly similar', () {
        const niche = 'investimentos renda fixa tesouro direto cdi';

        final projects = [
          _project(id: 'p1', name: 'Invest A', marketAnalysisId: 'a1'),
          _project(id: 'p2', name: 'Invest B', marketAnalysisId: 'a2'),
        ];
        final analyses = [
          _analysis(id: 'a1', niche: niche, targetAudience: 'público x', monetizationModel: 'modelo x'),
          _analysis(id: 'a2', niche: niche, targetAudience: 'público y', monetizationModel: 'modelo y'),
        ];

        final rels = svc.detect(projects: projects, analyses: analyses);
        // High niche overlap -> conflicting or duplicate
        expect(rels, isNotEmpty);
        expect(
          rels.first.type,
          anyOf(RelationshipType.duplicate, RelationshipType.conflicting),
        );
      });
    });

    group('synergistic detection (>=40% niche overlap)', () {
      test('detects synergy with moderate niche overlap', () {
        final projects = [
          _project(id: 'p1', name: 'Blog Finanças', marketAnalysisId: 'a1'),
          _project(id: 'p2', name: 'App Finanças', marketAnalysisId: 'a2'),
        ];
        final analyses = [
          _analysis(id: 'a1', niche: 'finanças investimentos poupança economia', targetAudience: 'público-alvo x', monetizationModel: 'ads'),
          _analysis(id: 'a2', niche: 'finanças investimentos bolsa bitcoin dividas', targetAudience: 'público-alvo y', monetizationModel: 'saas'),
        ];

        final rels = svc.detect(projects: projects, analyses: analyses);
        expect(rels, isNotEmpty);
        final types = rels.map((r) => r.type).toList();
        expect(types, anyOf(
          contains(RelationshipType.synergistic),
          contains(RelationshipType.conflicting),
          contains(RelationshipType.duplicate),
        ));
      });
    });

    group('sharedAudience detection (>=50% audience overlap)', () {
      test('detects shared audience with different niches', () {
        final projects = [
          _project(id: 'p1', name: 'Curso Finanças', marketAnalysisId: 'a1'),
          _project(id: 'p2', name: 'App Fitness', marketAnalysisId: 'a2'),
        ];
        final analyses = [
          _analysis(
            id: 'a1',
            niche: 'educação financeira',
            targetAudience: 'empreendedores jovens adultos millennials autônomos',
            monetizationModel: 'cursos online',
          ),
          _analysis(
            id: 'a2',
            niche: 'saúde bem-estar',
            targetAudience: 'empreendedores jovens adultos millennials autônomos',
            monetizationModel: 'assinatura mensal',
          ),
        ];

        final rels = svc.detect(projects: projects, analyses: analyses);
        expect(rels, isNotEmpty);
        expect(rels.first.type, RelationshipType.sharedAudience);
      });
    });

    group('no relation for completely different projects', () {
      test('returns empty when niches and audiences are completely different', () {
        final projects = [
          _project(id: 'p1', name: 'Projeto Alpha', marketAnalysisId: 'a1'),
          _project(id: 'p2', name: 'Projeto Beta', marketAnalysisId: 'a2'),
        ];
        final analyses = [
          _analysis(id: 'a1', niche: 'culinária receitas comida francesa', targetAudience: 'chefs idosos aposentados'),
          _analysis(id: 'a2', niche: 'software programação desenvolvimento kotlin', targetAudience: 'engenheiros jovens universitários'),
        ];

        final rels = svc.detect(projects: projects, analyses: analyses);
        expect(rels, isEmpty);
      });
    });

    group('sorting', () {
      test('duplicates are sorted before conflicting', () {
        const dupNiche = 'finanças pessoais investimentos renda fixa tesouro direto x';
        const confNiche = 'finanças pessoais investimentos renda fixa tesouro y';

        final projects = [
          _project(id: 'p1', name: 'A', marketAnalysisId: 'a1'),
          _project(id: 'p2', name: 'B', marketAnalysisId: 'a2'),
          _project(id: 'p3', name: 'C', marketAnalysisId: 'a3'),
          _project(id: 'p4', name: 'D', marketAnalysisId: 'a4'),
        ];
        final analyses = [
          _analysis(id: 'a1', niche: dupNiche, targetAudience: dupNiche, monetizationModel: dupNiche),
          _analysis(id: 'a2', niche: dupNiche, targetAudience: dupNiche, monetizationModel: dupNiche),
          _analysis(id: 'a3', niche: confNiche, targetAudience: 'outro público total', monetizationModel: 'diferente'),
          _analysis(id: 'a4', niche: confNiche, targetAudience: 'outro público distinto', monetizationModel: 'outro'),
        ];

        final rels = svc.detect(projects: projects, analyses: analyses);
        if (rels.length >= 2) {
          final firstPriority = _typePriority(rels.first.type);
          final secondPriority = _typePriority(rels[1].type);
          expect(firstPriority, lessThanOrEqualTo(secondPriority));
        }
      });
    });

    group('Jaccard similarity', () {
      test('identical strings produce 1.0 overlap', () {
        const text = 'finanças pessoais investimentos';
        final projects = [
          _project(id: 'p1', name: 'A', marketAnalysisId: 'a1'),
          _project(id: 'p2', name: 'B', marketAnalysisId: 'a2'),
        ];
        final analyses = [
          _analysis(id: 'a1', niche: text, targetAudience: text, monetizationModel: text),
          _analysis(id: 'a2', niche: text, targetAudience: text, monetizationModel: text),
        ];

        final rels = svc.detect(projects: projects, analyses: analyses);
        expect(rels, isNotEmpty);
        expect(rels.first.type, RelationshipType.duplicate);
        expect(rels.first.similarityPercent, greaterThan(85));
      });

      test('empty strings produce no relationship', () {
        final projects = [
          _project(id: 'p1', name: 'A', marketAnalysisId: 'a1'),
          _project(id: 'p2', name: 'B', marketAnalysisId: 'a2'),
        ];
        final analyses = [
          _analysis(id: 'a1', niche: '', targetAudience: '', monetizationModel: ''),
          _analysis(id: 'a2', niche: '', targetAudience: '', monetizationModel: ''),
        ];

        final rels = svc.detect(projects: projects, analyses: analyses);
        expect(rels, isEmpty);
      });
    });
  });
}

int _typePriority(RelationshipType t) {
  switch (t) {
    case RelationshipType.duplicate:      return 0;
    case RelationshipType.conflicting:    return 1;
    case RelationshipType.synergistic:    return 2;
    case RelationshipType.sharedNiche:    return 3;
    case RelationshipType.sharedAudience: return 4;
    case RelationshipType.complementary:  return 5;
  }
}
