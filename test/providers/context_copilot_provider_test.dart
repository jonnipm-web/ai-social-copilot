import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/models/copilot_turn.dart';
import 'package:ai_social_copilot/providers/context_copilot_provider.dart';

// IVE-COMMERCIAL-FOUNDATION-11 — covers the Codex Gate 2 (round 2, P1,
// ACCEPTED) finding: contextCopilotProvider was keyed by `screenName`
// alone (no autoDispose — the chat history persists deliberately while
// the app is open). The Project Context Contract correctly scopes the
// GROUNDING data (CopilotContextData.projectId) per project, but with
// the old key the CONVERSATION HISTORY itself was shared across
// different projects on the same screen: asking IVE about Project A in
// "Decisões", then about Project B on the same screen, resent Project
// A's prior questions/answers as `history` alongside Project B's
// (correctly scoped) context — a real cross-project leak of
// conversational content, not just grounding metadata.
//
// The fix widens the family key to a (screenName, projectId) record.
// This test proves that widening actually isolates state — it doesn't
// call the real `send()` (which hits Supabase.instance.functions.invoke,
// out of scope for a pure provider-identity test); it manipulates state
// directly via the notifier to prove two different keys never share it.
void main() {
  group('contextCopilotProvider — isolamento por (screenName, projectId)', () {
    test('a mesma tela com projetos diferentes tem estados de conversa independentes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifierA = container.read(contextCopilotProvider(('Decisões', 'project-a')).notifier);
      final notifierB = container.read(contextCopilotProvider(('Decisões', 'project-b')).notifier);

      // Simula uma conversa já ocorrida sobre o Projeto A.
      notifierA.state = notifierA.state.copyWith(turns: [
        CopilotTurn(role: 'user', content: 'Pergunta sobre o Projeto A', timestamp: DateTime(2026)),
      ]);

      final stateA = container.read(contextCopilotProvider(('Decisões', 'project-a')));
      final stateB = container.read(contextCopilotProvider(('Decisões', 'project-b')));

      expect(stateA.turns, hasLength(1));
      // Regressão central: o histórico do Projeto A NÃO aparece na
      // conversa do Projeto B, mesmo sendo a mesma tela ("Decisões").
      expect(stateB.turns, isEmpty);
      expect(notifierA, isNot(same(notifierB)));
    });

    test('a mesma tela e o mesmo projeto reutilizam a mesma instância (histórico contínuo)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final first = container.read(contextCopilotProvider(('Decisões', 'project-a')).notifier);
      final second = container.read(contextCopilotProvider(('Decisões', 'project-a')).notifier);

      // Mesma chave (screenName, projectId) → mesma instância — a
      // continuidade de conversa dentro do MESMO projeto não deve ser
      // perdida por esta correção.
      expect(first, same(second));
    });

    test('projectId null (overlay global) é uma chave própria, distinta de qualquer projeto', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final global = container.read(contextCopilotProvider(('Decisões', null)).notifier);
      final scoped = container.read(contextCopilotProvider(('Decisões', 'project-a')).notifier);

      expect(global, isNot(same(scoped)));
    });
  });
}
