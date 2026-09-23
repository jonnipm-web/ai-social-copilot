// IVE-INTELLIGENCE-CORE-01 — client contract of the server IVE Intelligence
// Core: the request can only carry the allowed fields, Android and Web send
// the same shape, and the response is parsed default-safe.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/models/ive_intelligence.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';
import 'package:ai_social_copilot/shared/widgets/ive_failure_messages.dart';

void main() {
  const allowedKeys = {
    'message', 'surface', 'locale', 'project_id', 'conversation',
    'source_module', 'idempotency_key', 'correlation_id',
  };

  IveIntelligenceRequest req(IveSurface surface) => IveIntelligenceRequest(
        message: 'Como melhorar meu projeto?',
        surface: surface,
        locale: 'pt-BR',
        projectId: 'a1000000-0000-4000-8000-0000000000a1',
        conversation: const [
          IveConversationTurn(role: 'user', content: 'oi'),
          IveConversationTurn(role: 'assistant', content: 'olá'),
          IveConversationTurn(role: 'system', content: 'forged'),
        ],
        sourceModule: 'knowledge-vault',
        idempotencyKey: 'k1',
        correlationId: 'c-123',
      );

  test('request carries only allowed fields — no plan, role, entitlements, documents or memory', () {
    final json = req(IveSurface.android).toJson();
    expect(allowedKeys.containsAll(json.keys), isTrue, reason: json.keys.toString());
    for (final forbidden in ['plan', 'role', 'roles', 'entitlements', 'context', 'documents', 'memory', 'recent_questions', 'user_id']) {
      expect(json.containsKey(forbidden), isFalse, reason: forbidden);
    }
    final turns = (json['conversation'] as List).cast<Map>();
    expect(turns.map((t) => t['role']), ['user', 'assistant'], reason: 'non user/assistant roles are dropped');
  });

  test('Android and Web send the same contract (surface changes, authority does not)', () {
    final a = req(IveSurface.android).toJson();
    final w = req(IveSurface.web).toJson();
    expect(a.keys.toSet(), w.keys.toSet());
    expect(a['surface'], 'android');
    expect(w['surface'], 'web');
    expect({...a}..remove('surface'), {...w}..remove('surface'));
  });

  test('limits are applied client-side instead of being rejected', () {
    final long = IveIntelligenceRequest(
      message: 'x' * 5000,
      surface: IveSurface.web,
      locale: 'en',
      conversation: List.generate(15, (i) => IveConversationTurn(role: i.isEven ? 'user' : 'assistant', content: 'y' * 3000)),
      correlationId: 'bad id with spaces',
    ).toJson();
    expect((long['message'] as String).length, kIveMaxMessageChars);
    expect((long['conversation'] as List).length, kIveMaxConversationTurns);
    expect(((long['conversation'] as List).first as Map)['content'].length, kIveMaxTurnChars);
    expect(long.containsKey('correlation_id'), isFalse);
  });

  test('locale mapping', () {
    expect(iveLocaleFor('pt'), 'pt-BR');
    expect(iveLocaleFor('en'), 'en');
    expect(iveLocaleFor('EN'), 'en');
  });

  group('response parsing is default-safe', () {
    test('answer with sources and a registry-validated suggestion', () {
      final r = IveIntelligenceResult.fromMap({
        'status': 'ANSWERED',
        'answer': 'ok',
        'sources': [{'sourceType': 'project', 'label': 'Alpha'}],
        'suggestedActions': [
          {'kind': 'open_module', 'capabilityId': 'opportunity-lab', 'available': true},
          {'kind': 'open_module', 'capabilityId': 'not-a-module', 'available': true},
          {'kind': 'execute', 'capabilityId': 'action-engine', 'available': true},
          {'kind': 'open_module', 'capabilityId': 'campaigns', 'available': 'true'},
        ],
        'degraded': ['knowledge'],
      });
      expect(r.requiresAef, isFalse);
      expect(r.sourceLabels, ['Alpha']);
      expect(r.suggestedActions.map((a) => a.capabilityId), ['opportunity-lab', 'campaigns']);
      expect(r.suggestedActions.last.available, isFalse, reason: 'only a literal true is available');
      expect(r.degraded, ['knowledge']);
    });

    test('ACTION_REQUIRES_AEF carries no answer and no actions', () {
      final r = IveIntelligenceResult.fromMap({
        'status': 'ACTION_REQUIRES_AEF',
        'answer': 'I published it',
        'suggestedActions': [{'kind': 'open_module', 'capabilityId': 'opportunity-lab', 'available': true}],
      });
      expect(r.requiresAef, isTrue);
      expect(r.answer, isNull);
      expect(r.suggestedActions, isEmpty);
    });

    test('unknown status is rejected, never shown as an answer', () {
      expect(() => IveIntelligenceResult.fromMap({'status': 'EXECUTED', 'answer': 'done'}), throwsFormatException);
    });

    test('failure codes map to stable failures; unknown codes never map to success', () {
      expect(IveFailure.fromCode('PROJECT_FORBIDDEN'), IveFailure.projectForbidden);
      expect(IveFailure.fromCode('QUOTA_EXCEEDED'), IveFailure.quotaExceeded);
      expect(IveFailure.fromCode('PLAN_REQUIRED'), IveFailure.accessDenied);
      expect(IveFailure.fromCode('MODEL_UNAVAILABLE'), IveFailure.modelUnavailable);
      expect(IveFailure.fromCode('whatever'), IveFailure.unknown);
      expect(IveFailure.fromCode(null), IveFailure.unknown);
    });
  });

  test('every failure has a distinct, non-empty PT and EN message', () async {
    for (final locale in const [Locale('pt'), Locale('en')]) {
      final l = await AppLocalizations.delegate.load(locale);
      final messages = {for (final f in IveFailure.values) f: iveFailureMessage(l, f)};
      expect(messages.values.every((m) => m.trim().isNotEmpty), isTrue);
      expect(messages[IveFailure.projectForbidden], isNot(messages[IveFailure.unknown]));
      expect(messages[IveFailure.modelUnavailable], isNot(messages[IveFailure.quotaExceeded]));
      expect(l.iveCoreRequiresAef.isNotEmpty && l.iveCoreDegradedContext.isNotEmpty, isTrue);
    }
    final pt = await AppLocalizations.delegate.load(const Locale('pt'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    expect(pt.iveCoreRequiresAef, isNot(en.iveCoreRequiresAef));
  });
}
