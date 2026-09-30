import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/core/constants/app_constants.dart';
import 'package:ai_social_copilot/data/models/action_queue_item.dart';
import 'package:ai_social_copilot/data/models/decision_validation.dart';
import 'package:ai_social_copilot/data/models/ecosystem_score.dart';
import 'package:ai_social_copilot/data/models/ive_issue.dart';
import 'package:ai_social_copilot/data/models/knowledge_coverage.dart';
import 'package:ai_social_copilot/data/models/knowledge_item.dart';
import 'package:ai_social_copilot/data/models/project.dart';
import 'package:ai_social_copilot/data/models/project_intelligence_profile.dart';
import 'package:ai_social_copilot/data/services/document_context_builder.dart';
import 'package:ai_social_copilot/data/services/project_intelligence_service.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';
import 'package:ai_social_copilot/providers/ive_context_provider.dart';
import 'package:ai_social_copilot/providers/ive_provider.dart';

// ── R16 — GLOBAL LANGUAGE CONSISTENCY ────────────────────────────────────────
// Deterministic, Dart-built user-facing text (IVE bubbles, alerts, grounding
// warnings, decision-gate labels, model display labels) must follow the
// PRESENTATION language: an English UI never shows Portuguese and a
// Portuguese UI never falls back to English. Canonical codes (maturity
// stages, gap codes, verdicts) stay language-neutral.

final _en = lookupAppLocalizations(const Locale('en'));
final _pt = lookupAppLocalizations(const Locale('pt'));

/// Portuguese-only markers: accented letters that never occur in the English
/// copy, plus a few very common PT function words.
final _ptMarkers = RegExp(
  r'[ãõçáéíóúâêôà]|\b(não|você|seu|sua|ações|projeto|oportunidades|análise|nenhum|nenhuma)\b',
  caseSensitive: false,
);

void expectEnglish(String text, {String? reason}) {
  expect(text, isNotEmpty, reason: reason);
  expect(_ptMarkers.hasMatch(text), isFalse,
      reason: 'Portuguese leaked into EN UI: "$text" ${reason ?? ''}');
}

void expectPortuguese(String text, {String? reason}) {
  expect(text, isNotEmpty, reason: reason);
  expect(_ptMarkers.hasMatch(text), isTrue,
      reason: 'expected Portuguese text, got: "$text" ${reason ?? ''}');
}

Project _project(String id, {String name = 'Alpha'}) => Project(
      id:        id,
      userId:    'user-1',
      name:      name,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

EcosystemScore _score(String id, int eco) => EcosystemScore(
      project:          _project(id),
      opportunityScore: 0,
      strategicFit:     0,
      synergyScore:     0,
      roiScore:         0,
      momentumScore:    0,
      ecosystemScore:   eco,
      recommendation:   'MANTER',
      strengths:        const [],
      risks:            const [],
      quickWins:        const [],
      totalRoi:         0,
      actionCount:      0,
      completedActions: 0,
      labItemCount:     0,
    );

ActionQueueItem _action(String id) => ActionQueueItem(
      id:        id,
      userId:    'user-1',
      title:     'Task $id',
      createdAt: DateTime(2026, 1, 1),
    );

const _routes = [
  AppConstants.routeProjects,
  AppConstants.routeOpportunityLab,
  AppConstants.routeEcosystem,
  AppConstants.routeEcosystemBriefing,
  AppConstants.routePersonas,
  AppConstants.routeKnowledge,
  AppConstants.routeActionEngine,
  AppConstants.routeIntelligenceDebug,
];

void main() {
  group('R16 — IVE route greetings', () {
    test('EN: every route greeting is English', () {
      for (final r in _routes) {
        final msgs = iveRouteMessages(r, _en);
        expect(msgs, hasLength(3), reason: r);
        for (final m in msgs) {
          expectEnglish(m, reason: r);
        }
      }
    });

    test('PT: every route greeting is Portuguese', () {
      for (final r in _routes) {
        final msgs = iveRouteMessages(r, _pt);
        expect(msgs, hasLength(3), reason: r);
        // At least one line per route carries a PT marker (some short lines
        // may have none, e.g. "Posso ..."), and none equals the EN copy.
        expect(msgs.any(_ptMarkers.hasMatch), isTrue, reason: r);
        expect(msgs, isNot(equals(iveRouteMessages(r, _en))), reason: r);
      }
    });

    test('unmapped route yields no greeting', () {
      expect(iveRouteMessages('/nowhere', _en), isEmpty);
    });
  });

  group('R16 — IVE context-aware bubble', () {
    const ctx = IveContextData(
      healthScore:               62,
      pendingActionsCount:       4,
      pendingOpportunitiesCount: 3,
      topProjectName:            'Alpha',
      topProjectScore:           81,
    );

    test('EN output is English for every mapped route', () {
      for (final r in [
        AppConstants.routeEcosystem,
        AppConstants.routeProjects,
        AppConstants.routeOpportunityLab,
        AppConstants.routeEcosystemBriefing,
        AppConstants.routeActionEngine,
      ]) {
        expectEnglish(buildIveContextMessage(ctx, r, _en), reason: r);
      }
    });

    test('PT output is Portuguese', () {
      expectPortuguese(buildIveContextMessage(ctx, AppConstants.routeProjects, _pt));
      expectPortuguese(buildIveContextMessage(ctx, AppConstants.routeActionEngine, _pt));
      expectPortuguese(buildIveContextMessage(ctx, AppConstants.routeEcosystem, _pt));
    });

    test('bottleneck fallback is localized', () {
      final en = buildIveContextMessage(ctx, AppConstants.routeEcosystem, _en);
      expect(en, contains(_en.ctxIveCtxBottleneckFallback));
      expect(en, isNot(contains('execução')));
    });

    test('health 0 (no data) still yields no message', () {
      const empty = IveContextData();
      expect(buildIveContextMessage(empty, AppConstants.routeEcosystem, _en), isEmpty);
    });
  });

  group('R16 — ecosystem alerts (shown in UI and sent to the AI)', () {
    test('health-low alert follows the locale', () {
      final scores = [_score('p1', 35)];
      final en = selectEcosystemAlert(scores: scores, health: 35, pending: const [], l10n: _en);
      final pt = selectEcosystemAlert(scores: scores, health: 35, pending: const [], l10n: _pt);
      expectEnglish(en.alertMessage);
      expectPortuguese(pt.alertMessage);
      expect(en.alertId, pt.alertId); // ids are language-neutral
    });

    test('critical-project alert follows the locale', () {
      final scores = [_score('ok', 90), _score('bad', 20)];
      final en = selectEcosystemAlert(scores: scores, health: 55, pending: const [], l10n: _en);
      expectEnglish(en.alertMessage);
      expect(en.alertId, 'score_critical_bad');
    });

    test('overdue-actions alert follows the locale', () {
      final pending = List.generate(6, (i) => _action('a$i'));
      final en = selectEcosystemAlert(scores: const [], health: 0, pending: pending, l10n: _en);
      final pt = selectEcosystemAlert(scores: const [], health: 0, pending: pending, l10n: _pt);
      expectEnglish(en.alertMessage);
      expectPortuguese(pt.alertMessage);
    });
  });

  group('R16 — grounding warnings', () {
    KnowledgeItem item(String id, String content) => KnowledgeItem(
          id:        id,
          userId:    'uid',
          title:     'Doc $id',
          content:   content,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );

    test('EMPTY_CONTENT / BUDGET_EXCEEDED messages follow the locale; codes unchanged', () {
      final items = [
        item('1', ''),
        item('2', 'word ' * 400),
        item('3', 'text ' * 400),
      ];
      final en = DocumentContextBuilder.buildGrounding(items, maxChars: 300, l10n: _en);
      final pt = DocumentContextBuilder.buildGrounding(items, maxChars: 300, l10n: _pt);
      expect(en.warnings.map((w) => w.code), contains('EMPTY_CONTENT'));
      expect(en.warnings.map((w) => w.code), contains('BUDGET_EXCEEDED'));
      for (final w in en.warnings) {
        expectEnglish(w.message, reason: w.code);
      }
      expect(pt.warnings.any((w) => _ptMarkers.hasMatch(w.message)), isTrue);
    });
  });

  group('R16 — IveIssue localization', () {
    test('factory issues render in the presentation language', () {
      final issue = IveIssue.actionMutationFailed(actionTitle: 'Approve', technicalError: 'x');
      expectEnglish(issue.localizedMessage(_en));
      expectPortuguese(issue.localizedMessage(_pt));
      for (final a in issue.recommendedActions) {
        expectEnglish(a.localizedLabel(_en));
      }
      final dl = IveIssue.knowledgeDownloadFailed(itemId: 'k', itemName: 'Deck', technicalError: 'x');
      expectEnglish(dl.localizedMessage(_en));
      expect(dl.recommendedActions.map((a) => a.localizedLabel(_en)),
          everyElement(isNot(isEmpty)));
    });

    test('custom issue codes fall back to their own userMessage', () {
      final custom = IveIssue(
        errorCode:        'CUSTOM',
        stage:            IveIssueStage.unknown,
        severity:         IveIssueSeverity.info,
        recoverable:      true,
        userMessage:      'custom text',
        technicalMessage: '',
        occurredAt:       DateTime(2026),
      );
      expect(custom.localizedMessage(_en), 'custom text');
    });
  });

  group('R16 — decision validation labels', () {
    const v = DecisionValidation(
      entityName:       'Alpha',
      status:           DecisionValidationStatus.structuring,
      coverageScore:    40,
      learningScore:    70,
      profileComplete:  false,
      documentCount:    5,
      indexedDocuments: 3,
      assetCount:       0,
      opportunityCount: 0,
      blockReasons:     [],
    );

    test('EN labels are English', () {
      expectEnglish(v.blockMessage(_en));
      expectEnglish(v.indexingStatus(_en));
      expectEnglish(v.coverageLabel(_en));
      expectEnglish(v.learningLabel(_en));
      expectEnglish(v.profileLabel(_en));
    });

    test('PT labels are Portuguese', () {
      expectPortuguese(v.blockMessage(_pt));
      expectPortuguese(v.coverageLabel(_pt));
      expectPortuguese(v.profileLabel(_pt));
    });
  });

  group('R16 — project intelligence profile', () {
    final profiles = ProjectIntelligenceService().computeProfiles(
      projects:            [_project('p1')],
      analyses:            const [],
      actions:             const [],
      labItems:            const [],
      revenuePlans:        const [],
      totalKnowledgeItems: 0,
    );
    final p = profiles.single;

    test('unknown identity fields are empty (no PT sentinel), with a localized display label', () {
      expect(p.niche, isEmpty);
      expect(p.targetAudience, isEmpty);
      expect(p.monetizationModel, isEmpty);
      expect(p.hasNiche, isFalse);
      expect(ProjectIntelligenceProfile.displayOrNotDefined(p.niche, _en), _en.ctxProfileNotDefined);
      expectEnglish(ProjectIntelligenceProfile.displayOrNotDefined(p.niche, _en));
    });

    test('maturity stage stays canonical; label is localized', () {
      expect(p.maturityStage, 'ideia');
      expectEnglish(p.maturityLabel(_en));
      expectEnglish(p.dataWarning(_en)!);
      expectPortuguese(p.dataWarning(_pt)!);
    });

    test('coverage gaps are language-neutral codes rendered per locale', () {
      expect(p.missingKnowledge, contains(KnowledgeCoverage.kGapNoDocuments));
      for (final g in p.missingKnowledge) {
        expectEnglish(KnowledgeCoverage.gapLabel(g, _en), reason: g);
      }
      expectPortuguese(KnowledgeCoverage.gapLabel(KnowledgeCoverage.kGapNoActions, _pt));
      expectEnglish(p.coverage.coverageLabel(_en));
    });
  });
}
