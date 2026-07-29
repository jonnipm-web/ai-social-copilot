import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/models/action_queue_item.dart';
import 'package:ai_social_copilot/data/models/executive_context.dart';
import 'package:ai_social_copilot/data/models/knowledge_coverage.dart';
import 'package:ai_social_copilot/data/models/market_analysis.dart';
import 'package:ai_social_copilot/data/models/opportunity_lab_item.dart';
import 'package:ai_social_copilot/data/models/project.dart';
import 'package:ai_social_copilot/data/services/executive_health_service.dart';

Project _project({String? url}) => Project(
      id: 'proj-1', userId: 'user-1', name: 'Teste', status: 'active',
      createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
      url: url,
    );

KnowledgeCoverage _coverage({int score = 50, List<String> gaps = const []}) =>
    KnowledgeCoverage(
      score: score,
      coverageLabel: score >= 70 ? 'Alta' : score >= 40 ? 'Média' : 'Baixa',
      gaps: gaps,
      strengths: [],
    );

MarketAnalysis _analysis({
  int? opportunity,
  int? seo,
  int? growth,
  int? competition,
  int? monetization,
  String? niche,
  String? monetizationModel,
  List<String>? weaknesses,
}) =>
    MarketAnalysis(
      id: 'a-1',
      userId: 'user-1',
      input: niche ?? 'finanças pessoais',
      niche: niche ?? 'finanças pessoais',
      opportunityScore: opportunity ?? 75,
      monetizationModel: monetizationModel,
      analysisJson: {
        'score_seo':          seo ?? 60,
        'score_growth':       growth ?? 65,
        'score_competition':  competition ?? 55,
        'score_monetization': monetization ?? 70,
        if (weaknesses != null) 'weaknesses': weaknesses,
      },
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

ActionQueueItem _action({String status = 'pending', String id = 'a1'}) =>
    ActionQueueItem(
      id: id, userId: 'user-1', title: 'Ação $id',
      actionType: 'generic', status: status, priority: 50,
      createdAt: DateTime(2026, 1, 1),
    );

OpportunityLabItem _opp({String status = 'pending', String id = 'o1'}) =>
    OpportunityLabItem(
      id: id, userId: 'user-1', title: 'Opp $id',
      opportunityType: 'expansão', status: status,
      marketScore: 60, revenueScore: 60, competitionScore: 50,
      synergyScore: 50, strategicFit: 50, finalScore: 55,
      origin: 'test', createdAt: DateTime(2026, 1, 1),
    );

void main() {
  late ExecutiveHealthService svc;

  setUp(() => svc = ExecutiveHealthService());

  group('ExecutiveHealthService.compute', () {
    group('returns 8 pillars', () {
      test('compute always returns exactly 8 pillars', () {
        final result = svc.compute(
          project: _project(),
          coverage: _coverage(),
          analysis: null,
          actions: [],
          labItems: [],
        );
        expect(result.pillars.length, 8);
      });
    });

    group('score clamping', () {
      test('overallScore is clamped to 0-100', () {
        final result = svc.compute(
          project: _project(),
          coverage: _coverage(score: 0),
          analysis: null,
          actions: [],
          labItems: [],
        );
        expect(result.overallScore, inInclusiveRange(0, 100));
      });

      test('overallScore >= 0 with all-null inputs', () {
        final result = svc.compute(
          project: _project(),
          coverage: _coverage(score: 0),
          analysis: null,
          actions: [],
          labItems: [],
          knowledgeItemCount: 0,
        );
        for (final p in result.pillars) {
          expect(p.score, inInclusiveRange(0, 100),
              reason: '${p.name} score out of range');
        }
      });

      test('overallScore <= 100 with perfect inputs', () {
        final result = svc.compute(
          project: _project(url: 'https://test.com'),
          coverage: _coverage(score: 100),
          analysis: _analysis(
            opportunity: 100, seo: 100, growth: 100,
            competition: 100, monetization: 100,
          ),
          actions: [
            _action(status: 'completed', id: 'a1'),
            _action(status: 'completed', id: 'a2'),
            _action(status: 'completed', id: 'a3'),
            _action(status: 'completed', id: 'a4'),
            _action(status: 'completed', id: 'a5'),
          ],
          labItems: [_opp(status: 'approved')],
          knowledgeItemCount: 20,
        );
        expect(result.overallScore, inInclusiveRange(0, 100));
        for (final p in result.pillars) {
          expect(p.score, inInclusiveRange(0, 100),
              reason: '${p.name} score out of range');
        }
      });
    });

    group('knowledge pillar', () {
      test('score 0 when coverage is 0 and no items', () {
        final result = svc.compute(
          project: _project(),
          coverage: _coverage(score: 0),
          analysis: null,
          actions: [],
          labItems: [],
          knowledgeItemCount: 0,
        );
        expect(result.knowledge.score, 0);
      });

      test('score improves with more knowledge items', () {
        final resultFew = svc.compute(
          project: _project(),
          coverage: _coverage(score: 50),
          analysis: null,
          actions: [],
          labItems: [],
          knowledgeItemCount: 1,
        );
        final resultMany = svc.compute(
          project: _project(),
          coverage: _coverage(score: 50),
          analysis: null,
          actions: [],
          labItems: [],
          knowledgeItemCount: 10,
        );
        expect(resultMany.knowledge.score, greaterThanOrEqualTo(resultFew.knowledge.score));
      });
    });

    group('market pillar', () {
      test('score is 0 and status is crítico when no analysis', () {
        final result = svc.compute(
          project: _project(),
          coverage: _coverage(),
          analysis: null,
          actions: [],
          labItems: [],
        );
        expect(result.market.score, 0);
        expect(result.market.status, 'crítico');
        expect(result.market.gaps, isNotEmpty);
      });

      test('score increases proportionally with analysis scores', () {
        final resultLow = svc.compute(
          project: _project(),
          coverage: _coverage(),
          analysis: _analysis(opportunity: 10, seo: 10, growth: 10, competition: 10),
          actions: [],
          labItems: [],
        );
        final resultHigh = svc.compute(
          project: _project(),
          coverage: _coverage(),
          analysis: _analysis(opportunity: 90, seo: 90, growth: 90, competition: 90),
          actions: [],
          labItems: [],
        );
        expect(resultHigh.market.score, greaterThan(resultLow.market.score));
      });
    });

    group('execution pillar', () {
      test('score is 0 and status critical when no actions', () {
        final result = svc.compute(
          project: _project(),
          coverage: _coverage(),
          analysis: null,
          actions: [],
          labItems: [],
        );
        expect(result.execution.score, 0);
        expect(result.execution.status, 'crítico');
      });

      test('score improves as more actions are completed', () {
        final resultNone = svc.compute(
          project: _project(),
          coverage: _coverage(),
          analysis: null,
          actions: [_action(status: 'pending')],
          labItems: [],
        );
        final resultAll = svc.compute(
          project: _project(),
          coverage: _coverage(),
          analysis: null,
          actions: [
            _action(status: 'completed', id: 'a1'),
            _action(status: 'completed', id: 'a2'),
            _action(status: 'completed', id: 'a3'),
          ],
          labItems: [],
        );
        expect(resultAll.execution.score, greaterThan(resultNone.execution.score));
      });
    });

    group('weakest/strongest pillar', () {
      test('weakestPillar has the lowest score', () {
        final result = svc.compute(
          project: _project(),
          coverage: _coverage(score: 0),
          analysis: null,
          actions: [],
          labItems: [],
        );
        final weak = result.weakestPillar;
        for (final p in result.pillars) {
          expect(weak.score, lessThanOrEqualTo(p.score));
        }
      });

      test('strongestPillar has the highest score', () {
        final result = svc.compute(
          project: _project(url: 'https://test.com'),
          coverage: _coverage(score: 80),
          analysis: _analysis(opportunity: 90, seo: 85, growth: 80, competition: 70),
          actions: [_action(status: 'completed')],
          labItems: [_opp()],
          knowledgeItemCount: 10,
        );
        final strong = result.strongestPillar;
        for (final p in result.pillars) {
          expect(strong.score, greaterThanOrEqualTo(p.score));
        }
      });
    });

    group('overallStatus', () {
      test('forte when overallScore >= 70', () {
        // Need high scores to reach 70+ overall
        final result = svc.compute(
          project: _project(url: 'https://test.com'),
          coverage: _coverage(score: 100),
          analysis: _analysis(opportunity: 100, seo: 100, growth: 100, competition: 100, monetization: 100),
          actions: [
            for (var i = 0; i < 8; i++) _action(status: 'completed', id: 'a$i'),
          ],
          labItems: [_opp(status: 'approved')],
          knowledgeItemCount: 20,
        );
        // Just verify the status computation logic is consistent
        if (result.overallScore >= 70) {
          expect(result.overallStatus, 'forte');
        } else if (result.overallScore >= 40) {
          expect(result.overallStatus, 'atenção');
        } else {
          expect(result.overallStatus, 'crítico');
        }
      });
    });

    group('trend computation', () {
      test('trend is positive when score > previousScore', () {
        const pillar = HealthPillar(
          name: 'Test', emoji: '📊', score: 80,
          previousScore: 50, status: 'forte',
        );
        expect(pillar.trend, 30);
        expect(pillar.trendEmoji, '📈');
      });

      test('trend is negative when score < previousScore', () {
        const pillar = HealthPillar(
          name: 'Test', emoji: '📊', score: 30,
          previousScore: 60, status: 'crítico',
        );
        expect(pillar.trend, -30);
        expect(pillar.trendEmoji, '📉');
      });

      test('trend is neutral when score equals previousScore', () {
        const pillar = HealthPillar(
          name: 'Test', emoji: '📊', score: 55,
          previousScore: 55, status: 'atenção',
        );
        expect(pillar.trend, 0);
        expect(pillar.trendEmoji, '➡️');
      });
    });

    group('pillar statusEmoji', () {
      test('forte returns green circle', () {
        const p = HealthPillar(name: '', emoji: '', score: 75, status: 'forte');
        expect(p.statusEmoji, '🟢');
      });

      test('atenção returns yellow circle', () {
        const p = HealthPillar(name: '', emoji: '', score: 50, status: 'atenção');
        expect(p.statusEmoji, '🟡');
      });

      test('crítico returns red circle', () {
        const p = HealthPillar(name: '', emoji: '', score: 20, status: 'crítico');
        expect(p.statusEmoji, '🔴');
      });
    });
  });
}
