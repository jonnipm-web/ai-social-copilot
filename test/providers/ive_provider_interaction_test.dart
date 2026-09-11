import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/models/ive_state.dart';
import 'package:ai_social_copilot/features/ive/visual/ive_avatar_state.dart';
import 'package:ai_social_copilot/providers/ive_provider.dart';

// ── IVE-AVATAR-STATE-MACHINE-02 ────────────────────────────────────────────
// Covers the chat-lifecycle → visual-state bridge added to IveNotifier
// (beginThinking/completeInteraction). Exercises the notifier directly
// (not through ContextCopilotNotifier/Supabase) since the bridge itself is
// the single source of truth being tested — the copilot provider is a thin
// caller of this same API around its real network request.

void main() {
  group('IveNotifier — interaction bridge', () {
    test('beginThinking sets interaction=thinking without touching business state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(iveProvider.notifier);

      notifier.showMessage('Oportunidade detectada', expression: IveExpression.winking);
      expect(container.read(iveProvider).expression, IveExpression.winking);

      notifier.beginThinking();
      final state = container.read(iveProvider);

      expect(state.interaction, IveInteractionState.thinking);
      expect(state.expression, IveExpression.winking); // business state untouched
      expect(IveVisualStateMapper.fromIveState(state), IveVisualState.thinking);
    });

    test('completeInteraction(success: true) sets interaction=speaking', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(iveProvider.notifier);

      final token = notifier.beginThinking();
      notifier.completeInteraction(token, success: true);

      final state = container.read(iveProvider);
      expect(state.interaction, IveInteractionState.speaking);
      expect(IveVisualStateMapper.fromIveState(state), IveVisualState.speaking);
    });

    test('speaking recomputes the live contextual state after presentation (not a stale snapshot)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(iveProvider.notifier);

      // Business state before the chat interaction starts.
      notifier.showMessage('Oportunidade detectada', expression: IveExpression.winking);

      final token = notifier.beginThinking();
      notifier.completeInteraction(token, success: true);
      expect(container.read(iveProvider).interaction, IveInteractionState.speaking);

      // Business state changes WHILE the avatar is "speaking" — the bridge
      // must recompute against this, not restore a stale pre-chat snapshot.
      notifier.showMessage('Novo alerta de execução', expression: IveExpression.neutral);

      await Future<void>.delayed(const Duration(milliseconds: 1700));

      final state = container.read(iveProvider);
      expect(state.interaction, isNull);
      expect(state.expression, IveExpression.neutral);
      expect(IveVisualStateMapper.fromIveState(state), IveVisualState.attentive);
    });

    test('a failed request clears interaction immediately, preserving prior business state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(iveProvider.notifier);

      notifier.showMessage('Saúde do ecossistema estável', expression: IveExpression.neutral);
      final token = notifier.beginThinking();
      notifier.completeInteraction(token, success: false);

      final state = container.read(iveProvider);
      expect(state.interaction, isNull);
      expect(state.expression, IveExpression.neutral);
      expect(IveVisualStateMapper.fromIveState(state), IveVisualState.attentive);
    });

    test('a stale token cannot overwrite a newer request\'s visual state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(iveProvider.notifier);

      final tokenA = notifier.beginThinking(); // first request
      final tokenB = notifier.beginThinking(); // second request supersedes it
      expect(tokenB, isNot(tokenA));
      expect(container.read(iveProvider).interaction, IveInteractionState.thinking);

      // Stale first request settles late — must be ignored.
      notifier.completeInteraction(tokenA, success: true);
      expect(container.read(iveProvider).interaction, IveInteractionState.thinking);

      // Current request settles — must apply.
      notifier.completeInteraction(tokenB, success: true);
      expect(container.read(iveProvider).interaction, IveInteractionState.speaking);
    });

    test('a stale token cannot re-open thinking after the current request already failed', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(iveProvider.notifier);

      final tokenA = notifier.beginThinking();
      final tokenB = notifier.beginThinking();
      notifier.completeInteraction(tokenB, success: false);
      expect(container.read(iveProvider).interaction, isNull);

      // Stale first request settles after the second already cleared state.
      notifier.completeInteraction(tokenA, success: true);
      expect(container.read(iveProvider).interaction, isNull);
    });

    test('no state mutation from a pending speaking timer after dispose', () async {
      final container = ProviderContainer();
      final notifier = container.read(iveProvider.notifier);

      final token = notifier.beginThinking();
      notifier.completeInteraction(token, success: true); // schedules the auto-clear timer

      container.dispose();

      // The scheduled timer firing after dispose must not throw or mutate state.
      await Future<void>.delayed(const Duration(milliseconds: 1700));

      expect(() => notifier.completeInteraction(token, success: false), returnsNormally);
      expect(() => notifier.beginThinking(), returnsNormally);
    });
  });
}
