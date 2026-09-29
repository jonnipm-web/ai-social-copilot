/// R16 — GLOBAL LANGUAGE CONSISTENCY — Ecosystem Intelligence.
///
/// The deterministic Ecosystem/Executive intelligence used to emit Portuguese
/// sentences ("Seu ecossistema tem 1 projeto...") even with the UI in
/// English. The service now renders text via AppLocalizations. This test
/// runs the SAME fixture through the service in PT and EN and proves:
///   * every number, verdict code, ranking and allocation is identical
///     (localization only changes text — never the decision);
///   * the text actually differs between the two languages;
///   * the EN output carries no Portuguese.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/core/utils/ecosystem_labels.dart';
import 'package:ai_social_copilot/data/models/action_queue_item.dart';
import 'package:ai_social_copilot/data/models/ecosystem_score.dart';
import 'package:ai_social_copilot/data/models/opportunity_lab_item.dart';
import 'package:ai_social_copilot/data/models/priority_recommendation.dart';
import 'package:ai_social_copilot/data/models/project.dart';
import 'package:ai_social_copilot/data/models/resource_allocation.dart';
import 'package:ai_social_copilot/data/models/roi_metric.dart';
import 'package:ai_social_copilot/data/models/weekly_briefing.dart';
import 'package:ai_social_copilot/data/services/ecosystem_intelligence_service.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';

// ── Fixture (user data is language-neutral on purpose) ─────────────────────
final _recent = DateTime.now().subtract(const Duration(days: 1));
final _old    = DateTime(2024, 1, 1);

Project _p(String id, String name, {int priority = 0, String status = 'active'}) =>
    Project(
      id:            id,
      userId:        'uid',
      name:          name,
      priorityScore: priority,
      status:        status,
      createdAt:     _old,
      updatedAt:     _old,
    );

ActionQueueItem _a(String id, String projectId,
        {String status = 'pending', int impact = 50, int effort = 50, DateTime? at}) =>
    ActionQueueItem(
      id:          id,
      userId:      'uid',
      projectId:   projectId,
      title:       'Task $id',
      status:      status,
      impactScore: impact,
      effortScore: effort,
      createdAt:   at ?? _recent,
    );

OpportunityLabItem _o(String id, String projectId, int score,
        {String status = 'approved'}) =>
    OpportunityLabItem(
      id:              id,
      userId:          'uid',
      projectId:       projectId,
      title:           'Lab $id',
      opportunityType: 'content',
      marketScore:     score,
      revenueScore:    score,
      strategicFit:    score,
      finalScore:      score,
      status:          status,
      createdAt:       _recent,
    );

final _projects = [
  _p('p1', 'Alpha', priority: 90),
  _p('p2', 'Bravo', priority: 40),
  _p('p3', 'Charlie', status: 'idea'),      // no data → incomplete analysis
  _p('p4', 'Delta', priority: 10),
];

final _actions = [
  _a('a1', 'p1', status: 'completed'),
  _a('a2', 'p1', status: 'completed'),
  _a('a3', 'p1', impact: 90, effort: 20),   // quick win
  for (var i = 0; i < 7; i++) _a('b$i', 'p2', impact: 30, effort: 70),
  _a('d1', 'p4', at: _old),
];

final _lab = [
  _o('l1', 'p1', 95),
  _o('l2', 'p1', 90),
  _o('l3', 'p1', 85),
  _o('l4', 'p2', 40, status: 'pending'),
];

final _roi = [
  RoiMetric(id: 'r1', userId: 'uid', projectId: 'p1', metricType: 'revenue',
      metricValue: 1500, createdAt: _recent),
];

// ── Run the whole pipeline in one language ─────────────────────────────────
class _Run {
  _Run(this.scores, this.recs, this.briefing, this.hours, this.money);
  final List<EcosystemScore> scores;
  final List<PriorityRecommendation> recs;
  final WeeklyBriefing briefing;
  final ResourceAllocation hours;
  final ResourceAllocation money;

  List<String> get allText => [
        for (final s in scores) ...[...s.strengths, ...s.risks],
        for (final r in recs) ...[r.title, r.reason, r.dataUsed, r.expectedImpact],
        briefing.executiveSummary,
        for (final i in [
          ...briefing.whatChanged,
          ...briefing.whatGrew,
          ...briefing.whatDeclined,
          ...briefing.topPriorities,
          ...briefing.toPause,
          ...briefing.newOpportunities,
          ...briefing.risks,
        ]) ...[i.title, i.detail],
        hours.summary,
        money.summary,
        for (final i in [...hours.items, ...money.items]) i.reason,
      ];
}

_Run _run(Locale locale) {
  final svc = EcosystemIntelligenceService(l10n: lookupAppLocalizations(locale));
  final scores = svc.computeProjectScores(
    projects:   _projects,
    analyses:   const [],
    actions:    _actions,
    labItems:   _lab,
    roiMetrics: _roi,
  );
  return _Run(
    scores,
    svc.generateRecommendations(scores: scores, labItems: _lab, actions: _actions),
    svc.generateBriefing(
      scores:     scores,
      analyses:   const [],
      actions:    _actions,
      labItems:   _lab,
      roiMetrics: _roi,
    ),
    svc.allocateResources(scores: scores, budget: 40, budgetType: 'hours'),
    svc.allocateResources(scores: scores, budget: 1000, budgetType: 'money'),
  );
}

const _ptMarkers = [
  'ecossistema', 'projeto', 'Recomendação', 'recomendação', 'ção', 'ões',
  'você', 'horas', 'Nenhum', 'Seu ', 'ações', 'análise', 'Priorize',
];

void main() {
  late _Run pt;
  late _Run en;

  setUpAll(() {
    pt = _run(const Locale('pt'));
    en = _run(const Locale('en'));
  });

  group('R16 ecosystem language invariance', () {
    test('fixture exercises several verdicts (sanity)', () {
      final codes = pt.scores.map((s) => s.recommendation).toSet();
      expect(codes, contains('ANÁLISE INCOMPLETA'));
      expect(codes.length, greaterThanOrEqualTo(2));
      expect(pt.recs, isNotEmpty);
      expect(pt.hours.items, isNotEmpty);
    });

    test('scores, verdict codes and ranking are identical in PT and EN', () {
      expect(en.scores.length, pt.scores.length);
      for (var i = 0; i < pt.scores.length; i++) {
        final a = pt.scores[i];
        final b = en.scores[i];
        expect(b.project.id, a.project.id, reason: 'ranking changed at $i');
        expect(b.ecosystemScore, a.ecosystemScore);
        expect(b.opportunityScore, a.opportunityScore);
        expect(b.strategicFit, a.strategicFit);
        expect(b.synergyScore, a.synergyScore);
        expect(b.roiScore, a.roiScore);
        expect(b.momentumScore, a.momentumScore);
        expect(b.marketScore, a.marketScore);
        expect(b.executionScore, a.executionScore);
        expect(b.hasEnoughData, a.hasEnoughData);
        expect(b.recommendation, a.recommendation,
            reason: 'verdict codes are logic keys and must never be translated');
        expect(b.strengths.length, a.strengths.length);
        expect(b.risks.length, a.risks.length);
        expect(b.quickWins, a.quickWins);
      }
    });

    test('recommendations keep type/entity/confidence/order', () {
      expect(en.recs.length, pt.recs.length);
      for (var i = 0; i < pt.recs.length; i++) {
        expect(en.recs[i].type, pt.recs[i].type);
        expect(en.recs[i].entityId, pt.recs[i].entityId);
        expect(en.recs[i].confidence, pt.recs[i].confidence);
      }
    });

    test('briefing and allocation numbers are identical', () {
      expect(en.briefing.overallHealthScore, pt.briefing.overallHealthScore);
      expect(en.briefing.whatChanged.map((i) => i.impact).toList(),
          pt.briefing.whatChanged.map((i) => i.impact).toList());
      expect(en.briefing.topPriorities.map((i) => i.title).toList(),
          pt.briefing.topPriorities.map((i) => i.title).toList());
      expect(en.briefing.risks.length, pt.briefing.risks.length);
      for (final pair in [[pt.hours, en.hours], [pt.money, en.money]]) {
        expect(pair[1].items.length, pair[0].items.length);
        for (var i = 0; i < pair[0].items.length; i++) {
          expect(pair[1].items[i].score.project.id, pair[0].items[i].score.project.id);
          expect(pair[1].items[i].allocation, pair[0].items[i].allocation);
          expect(pair[1].items[i].percentage, pair[0].items[i].percentage);
          expect(pair[1].items[i].expectedRoiScore, pair[0].items[i].expectedRoiScore);
        }
      }
    });

    test('text differs between PT and EN', () {
      expect(en.briefing.executiveSummary, isNot(pt.briefing.executiveSummary));
      expect(en.hours.summary, isNot(pt.hours.summary));
      expect(en.allText, isNot(equals(pt.allText)));
      expect(pt.briefing.executiveSummary, contains('ecossistema'));
    });

    test('EN output contains no Portuguese', () {
      for (final line in en.allText) {
        for (final m in _ptMarkers) {
          expect(line.contains(m), isFalse,
              reason: 'EN text "$line" contains Portuguese marker "$m"');
        }
      }
      // Verdict codes must not leak raw into EN prose either.
      for (final line in en.allText) {
        for (final code in const ['ESCALAR', 'ACELERAR', 'MANTER', 'VALIDAR', 'PAUSAR', 'INCOMPLETA']) {
          expect(line.contains(code), isFalse,
              reason: 'EN text "$line" shows raw verdict code "$code"');
        }
      }
    });

    test('ecosystemVerdictLabel maps every code and passes unknowns through', () {
      final enL = lookupAppLocalizations(const Locale('en'));
      final ptL = lookupAppLocalizations(const Locale('pt'));
      expect(ecosystemVerdictLabel('ESCALAR', enL), 'SCALE');
      expect(ecosystemVerdictLabel('ACELERAR', enL), 'ACCELERATE');
      expect(ecosystemVerdictLabel('MANTER', enL), 'MAINTAIN');
      expect(ecosystemVerdictLabel('VALIDAR', enL), 'VALIDATE');
      expect(ecosystemVerdictLabel('PAUSAR', enL), 'PAUSE');
      expect(ecosystemVerdictLabel('ANÁLISE INCOMPLETA', enL), 'INCOMPLETE ANALYSIS');
      expect(ecosystemVerdictLabel('MANTER', ptL), 'MANTER');
      expect(ecosystemVerdictLabel('ANÁLISE INCOMPLETA', ptL), 'ANÁLISE INCOMPLETA');
      expect(ecosystemVerdictLabel('SOMETHING_ELSE', enL), 'SOMETHING_ELSE');
    });

    test('default constructor keeps legacy Portuguese output', () {
      final legacy = EcosystemIntelligenceService().generateBriefing(
        scores: const [], analyses: const [], actions: const [],
        labItems: const [], roiMetrics: const [],
      );
      expect(legacy.whatChanged.single.title, 'Nenhuma atividade nova esta semana');
    });
  });
}
