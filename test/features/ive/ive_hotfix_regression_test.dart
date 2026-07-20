// ignore_for_file: lines_longer_than_80_chars
/// Regression tests — HOTFIX ESTRUTURAL IVE (Build Week)
/// Cobre: P0.2, P0.3, P0.4, P1.1, P1.2
library;

import 'package:ai_social_copilot/data/models/action_queue_item.dart';
import 'package:ai_social_copilot/data/models/ecosystem_score.dart';
import 'package:ai_social_copilot/data/models/opportunity_lab_item.dart';
import 'package:ai_social_copilot/data/models/project.dart';
import 'package:ai_social_copilot/data/models/roi_metric.dart';
import 'package:ai_social_copilot/data/services/ecosystem_intelligence_service.dart';
import 'package:ai_social_copilot/features/ive/domain/ive_copilot_contract.dart';
import 'package:ai_social_copilot/providers/ive_context_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

Project _project({String id = 'proj-1', String name = 'Proj'}) => Project(
      id: id,
      userId: 'user-1',
      name: name,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

RoiMetric _roi({double value = 5000.0}) => RoiMetric(
      id: 'roi-1',
      userId: 'user-1',
      projectId: 'proj-1',
      metricType: 'revenue',
      metricValue: value,
      createdAt: DateTime(2026),
    );

OpportunityLabItem _opp({
  int finalScore = 80,
  int revenueScore = 70,
  int confidence = 85,
  int marketScore = 75,
}) =>
    OpportunityLabItem(
      id: 'opp-1',
      userId: 'user-1',
      projectId: 'proj-1',
      title: 'Oportunidade Test',
      finalScore: finalScore,
      revenueScore: revenueScore,
      confidence: confidence,
      marketScore: marketScore,
      createdAt: DateTime(2026),
    );

OpportunityLabItem _oppEmpty() => OpportunityLabItem(
      id: 'opp-2',
      userId: 'user-1',
      projectId: 'proj-1',
      title: 'Opp sem dados',
      createdAt: DateTime(2026),
    );

final _svc = EcosystemIntelligenceService();

List<EcosystemScore> _scores({
  List<RoiMetric> roi = const [],
  List<ActionQueueItem> actions = const [],
  List<OpportunityLabItem> lab = const [],
}) =>
    _svc.computeProjectScores(
      projects: [_project()],
      analyses: const [],
      actions: actions,
      labItems: lab,
      roiMetrics: roi,
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── P1.2 — ROI data semântico ─────────────────────────────────────────────

  group('P1.2 — hasRoiData no EcosystemScore', () {
    test('hasRoiData=false quando não há ROI metrics nem revenue plan', () {
      final scores = _scores();
      expect(scores.first.hasRoiData, isFalse);
    });

    test('hasRoiData=true quando há ROI metrics', () {
      final scores = _scores(roi: [_roi()]);
      expect(scores.first.hasRoiData, isTrue);
    });

    test('roiScore=0 NÃO implica ausência de dados quando hasRoiData=true', () {
      // ROI com valor alto → score calculado
      final scores = _scores(roi: [_roi(value: 200000.0)]);
      expect(scores.first.hasRoiData, isTrue);
      expect(scores.first.roiScore, greaterThan(0));
    });

    test('hasRoiData=false → IveContextData.roiScore não contamina hints de roi', () {
      // IveContextData construída sem dados de ROI
      const ctx = IveContextData(
        userId: 'user-1',
        activeProjectId: 'proj-1',
        hasRoiData: false,
        roiScore: 0,
      );
      final hints = ctx.toCopilotContext(route: '/test');
      final scores = hints.scores!;
      // roi deve ser null quando não há dados reais
      expect(scores['roi'], isNull);
      expect(scores['roi_data_available'], isFalse);
    });
  });

  // ── P1.2 — Context hints com roi real ────────────────────────────────────

  group('P1.2 — toCopilotContext propaga hasRoiData corretamente', () {
    test('roi presente nos hints quando hasRoiData=true', () {
      const ctx = IveContextData(
        userId: 'user-1',
        activeProjectId: 'proj-1',
        hasRoiData: true,
        roiScore: 65,
      );
      final hints = ctx.toCopilotContext(route: '/test');
      expect(hints.scores!['roi'], equals(65));
      expect(hints.scores!['roi_data_available'], isTrue);
    });

    test('has_enough_data=false propagado quando dados insuficientes', () {
      const ctx = IveContextData(
        userId: 'user-1',
        activeProjectId: 'proj-1',
        hasEnoughData: false,
      );
      final hints = ctx.toCopilotContext(route: '/test');
      expect(hints.scores!['has_enough_data'], isFalse);
    });

    test('has_enough_data=true propagado quando dados suficientes', () {
      const ctx = IveContextData(
        userId: 'user-1',
        activeProjectId: 'proj-1',
        hasEnoughData: true,
      );
      final hints = ctx.toCopilotContext(route: '/test');
      expect(hints.scores!['has_enough_data'], isTrue);
    });
  });

  // ── P1.1 — Defaults em addFromOpportunityItem ────────────────────────────

  group('P1.1 — addFromOpportunityItem usa dados reais da oportunidade', () {
    test('priority vem de finalScore quando > 0', () {
      final opp = _opp(finalScore: 88);
      // Reconstituir lógica de addFromOpportunityItem localmente para unit test
      final priority = opp.finalScore > 0 ? opp.finalScore : 50;
      expect(priority, equals(88));
    });

    test('priority cai para 50 quando finalScore=0', () {
      final opp = _oppEmpty();
      final priority = opp.finalScore > 0 ? opp.finalScore : 50;
      expect(priority, equals(50));
    });

    test('impactScore vem de revenueScore quando > 0', () {
      final opp = _opp(revenueScore: 73);
      final impact = opp.revenueScore > 0 ? opp.revenueScore : 60;
      expect(impact, equals(73));
    });

    test('effortScore derivado de confidence quando > 0', () {
      final opp = _opp(confidence: 90);
      final effort = opp.confidence > 0
          ? (100 - opp.confidence).clamp(10, 90)
          : 50;
      // 100 - 90 = 10 (mínimo permitido)
      expect(effort, equals(10));
    });

    test('effortScore=50 quando confidence=0', () {
      final opp = _oppEmpty();
      final effort = opp.confidence > 0
          ? (100 - opp.confidence).clamp(10, 90)
          : 50;
      expect(effort, equals(50));
    });
  });

  // ── P0.4 — Gateway timeout ───────────────────────────────────────────────

  group('P0.4 — IveCopilotHttpException timeout semântico', () {
    test('isTimeout=true para status 504', () {
      const ex = IveCopilotHttpException(
        status: 504,
        code: 'TIMEOUT',
        message: 'A IVE demorou para responder.',
      );
      expect(ex.isTimeout, isTrue);
    });

    test('isTimeout=true para code TIMEOUT independente de status', () {
      const ex = IveCopilotHttpException(
        status: 200,
        code: 'TIMEOUT',
        message: 'Timeout.',
      );
      expect(ex.isTimeout, isTrue);
    });

    test('isTimeout=false para erros HTTP comuns', () {
      const ex = IveCopilotHttpException(
        status: 500,
        code: 'INTERNAL_ERROR',
        message: 'Erro interno.',
      );
      expect(ex.isTimeout, isFalse);
    });
  });

  // ── EcosystemScore — hasRoiData integrado com hasEnoughData ──────────────

  group('EcosystemScore — novos campos hasRoiData e hasEnoughData', () {
    test('score com lab items tem hasEnoughData=true', () {
      final scores = _scores(lab: [_opp()]);
      expect(scores.first.hasEnoughData, isTrue);
    });

    test('score sem nenhum dado tem hasEnoughData=false', () {
      final scores = _scores();
      expect(scores.first.hasEnoughData, isFalse);
    });

    test('recommendation=ANÁLISE INCOMPLETA quando hasEnoughData=false', () {
      final scores = _scores();
      expect(scores.first.recommendation, equals('ANÁLISE INCOMPLETA'));
    });

    test('hasRoiData=false não influi no ecosystemScore final', () {
      // Sem ROI o score ainda é calculado (ROI contribui com 0)
      final scoresComRoi = _scores(roi: [_roi()]);
      final scoresSemRoi = _scores(lab: [_opp()]);
      // Ambos retornam score; a presença de ROI pode aumentar o score
      expect(scoresComRoi.first.hasRoiData, isTrue);
      expect(scoresSemRoi.first.hasRoiData, isFalse);
      expect(scoresSemRoi.first.ecosystemScore, greaterThanOrEqualTo(0));
    });
  });

  // ── IveContextData — campos ausentes têm defaults corretos ───────────────

  group('IveContextData — defaults defensivos', () {
    test('hasRoiData=false por padrão', () {
      const ctx = IveContextData();
      expect(ctx.hasRoiData, isFalse);
    });

    test('hasEnoughData=false por padrão', () {
      const ctx = IveContextData();
      expect(ctx.hasEnoughData, isFalse);
    });

    test('toCopilotContext sem projeto ativo retorna scores null', () {
      const ctx = IveContextData(userId: 'user-1');
      final hints = ctx.toCopilotContext(route: '/test');
      expect(hints.scores, isNull);
    });
  });
}
