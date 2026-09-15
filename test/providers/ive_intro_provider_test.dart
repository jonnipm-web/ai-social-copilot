import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_social_copilot/providers/ive_intro_provider.dart';

// IVE-EXPERIENCE-V1-06 (Section 31) — proves the persistence contract
// mission Section 15 asks for: first-use display, skip, completion, no
// repeat after either, and the version hook for re-showing a materially
// changed intro without resetting unrelated onboarding state.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<IveIntroState> restored(ProviderContainer container) async {
    // O construtor do notifier dispara _restore() de forma assíncrona —
    // SharedPreferences.getInstance() atravessa mais de um turno do event
    // loop mesmo mockado, então um único microtask (Duration.zero) não é
    // suficiente. Faz polling curto até loading virar false, com um teto
    // que falha alto (e não trava) se algo real quebrar.
    for (var i = 0; i < 20; i++) {
      if (!container.read(iveIntroProvider).loading) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return container.read(iveIntroProvider);
  }

  group('IveIntroState.shouldShow — primeira exibição', () {
    test('mostra a introdução quando nunca houve interação (seenVersion null)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final state = await restored(container);

      expect(state.loading, isFalse);
      expect(state.shouldShow, isTrue);
      expect(state.seen, isFalse);
    });

    test('não decide exibir enquanto loading (restauração ainda em andamento)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final state = container.read(iveIntroProvider);

      // Estado inicial síncrono, antes do microtask de restauração.
      expect(state.loading, isTrue);
      expect(state.shouldShow, isFalse);
    });
  });

  group('IveIntroNotifier.skip', () {
    test('skip() marca skipped=true e impede nova exibição na versão atual', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await restored(container);

      await container.read(iveIntroProvider.notifier).skip();
      final state = container.read(iveIntroProvider);

      expect(state.skipped, isTrue);
      expect(state.completed, isFalse);
      expect(state.seen, isTrue);
      expect(state.shouldShow, isFalse);
      expect(state.seenVersion, kIveIntroCurrentVersion);
    });

    test('skip() persiste — uma nova instância do notifier não mostra a introdução de novo', () async {
      final first = ProviderContainer();
      await restored(first);
      await first.read(iveIntroProvider.notifier).skip();
      first.dispose();

      final second = ProviderContainer();
      addTearDown(second.dispose);
      final state = await restored(second);

      expect(state.shouldShow, isFalse);
      expect(state.skipped, isTrue);
    });
  });

  group('IveIntroNotifier.complete', () {
    test('complete() marca completed=true e impede nova exibição na versão atual', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await restored(container);

      await container.read(iveIntroProvider.notifier).complete();
      final state = container.read(iveIntroProvider);

      expect(state.completed, isTrue);
      expect(state.skipped, isFalse);
      expect(state.seen, isTrue);
      expect(state.shouldShow, isFalse);
    });

    test('complete() persiste — uma nova instância do notifier não mostra a introdução de novo', () async {
      final first = ProviderContainer();
      await restored(first);
      await first.read(iveIntroProvider.notifier).complete();
      first.dispose();

      final second = ProviderContainer();
      addTearDown(second.dispose);
      final state = await restored(second);

      expect(state.shouldShow, isFalse);
      expect(state.completed, isTrue);
    });
  });

  group('Versionamento (mission Section 06/15)', () {
    test('uma versão de introdução mais nova que a já vista volta a ser exibida', () async {
      SharedPreferences.setMockInitialValues({
        'ive_intro_completed': true,
        'ive_intro_skipped': false,
        'ive_intro_version': kIveIntroCurrentVersion - 1,
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final state = await restored(container);

      // O usuário já completou uma versão ANTERIOR — isso não deve ser
      // confundido com ter completado a versão atual.
      expect(state.shouldShow, isTrue);
    });

    test('a mesma versão já completada não é exibida de novo', () async {
      SharedPreferences.setMockInitialValues({
        'ive_intro_completed': true,
        'ive_intro_skipped': false,
        'ive_intro_version': kIveIntroCurrentVersion,
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final state = await restored(container);

      expect(state.shouldShow, isFalse);
    });

    // IVE-EXPERIENCE-V1-06 (Codex Class B review, P2) — regressão exata do
    // achado: completar uma versão ANTIGA e depois pular uma versão NOVA
    // não pode deixar completed=true e skipped=true persistidos ao mesmo
    // tempo (estado internamente contraditório), mesmo que shouldShow em si
    // já estivesse correto (só olha seenVersion).
    test('skip() após complete() de uma versão anterior nunca deixa completed=true persistido', () async {
      SharedPreferences.setMockInitialValues({
        'ive_intro_completed': true,
        'ive_intro_skipped': false,
        'ive_intro_version': kIveIntroCurrentVersion - 1,
      });
      final first = ProviderContainer();
      await restored(first);
      await first.read(iveIntroProvider.notifier).skip();
      first.dispose();

      final second = ProviderContainer();
      addTearDown(second.dispose);
      final state = await restored(second);

      expect(state.skipped, isTrue);
      expect(state.completed, isFalse);
      expect(state.shouldShow, isFalse);
    });
  });

  group('Corrida entre _restore() e ação explícita (bug real encontrado)', () {
    // O notifier é criado sob demanda (primeiro `ref.read(...notifier)`) —
    // no sheet "Meet IVE" isso acontece no exato instante em que o botão é
    // tocado, não antes. Se skip()/complete() forem chamados IMEDIATAMENTE
    // após a criação, sem aguardar o _restore() do construtor terminar,
    // _restore() (que sobrescreve `state` inteiro, não faz merge) podia
    // vencer a corrida e reverter a ação explícita do usuário de volta para
    // os valores (então vazios) do SharedPreferences. skip()/complete()
    // agora marcam loading:false, e _restore() nunca sobrescreve depois
    // que loading já é false.
    test('skip() chamado antes do restore terminar não é revertido por ele', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Sem aguardar nada — dispara a criação do notifier e chama skip()
      // no mesmo microtask, exatamente como o sheet faz ao tocar "Pular"
      // antes do _restore() do construtor sequer começar a resolver.
      await container.read(iveIntroProvider.notifier).skip();

      // Dá tempo de sobra para um _restore() antigo (se não fosse
      // guardado) também terminar e potencialmente sobrescrever o estado.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(iveIntroProvider);
      expect(state.skipped, isTrue);
      expect(state.completed, isFalse);
      expect(state.loading, isFalse);
    });

    test('complete() chamado antes do restore terminar não é revertido por ele', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(iveIntroProvider.notifier).complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(iveIntroProvider);
      expect(state.completed, isTrue);
      expect(state.skipped, isFalse);
      expect(state.loading, isFalse);
    });
  });
}
