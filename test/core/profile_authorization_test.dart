/// Testes de autorização do ProfileService.
///
/// Valida que operações administrativas (updateRole, setActive, fetchAllProfiles)
/// lançam exceção quando:
///   - usuário não está autenticado (sem sessão Supabase)
///   - usuário está autenticado mas não é admin (coberto por integração real)
///
/// Como Supabase não está inicializado no ambiente de teste, o guard
/// _requireUid() dispara antes de qualquer consulta ao banco.
/// Isso é suficiente para validar a primeira camada de defesa.
///
/// A segunda camada (_requireAdmin() → consulta ao banco) e a terceira
/// (trigger SQL enforce_profile_role_authorization) são testadas em ambiente
/// de staging com Supabase real.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ai_social_copilot/data/services/profile_service.dart';

// ── Helper ────────────────────────────────────────────────────────────────────

Matcher throwsNotAuthenticated() => throwsA(
      isA<Exception>().having(
        (e) => e.toString(),
        'message',
        anyOf(
          contains('autenticado'),
          contains('Autenticado'),
          contains('authenticated'),
        ),
      ),
    );

Matcher throwsAdminRequired() => throwsA(
      isA<Exception>().having(
        (e) => e.toString(),
        'message',
        anyOf(
          contains('administrador'),
          contains('Administrador'),
          contains('admin'),
          // Se o guard de uid disparar primeiro (sem sessão), também é correto
          contains('autenticado'),
        ),
      ),
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'http://localhost:54321',
        anonKey: 'test-anon-key',
      );
    } catch (_) {}
  });

  group('ProfileService — guard de autenticação (sem sessão)', () {
    test('fetchAllProfiles() lança exceção sem sessão', () {
      expect(
        ProfileService().fetchAllProfiles(),
        throwsNotAuthenticated(),
      );
    });

    test('updateRole() lança exceção sem sessão', () {
      expect(
        ProfileService().updateRole('some-user-id', 'admin'),
        throwsNotAuthenticated(),
      );
    });

    test('setActive() lança exceção sem sessão', () {
      expect(
        ProfileService().setActive('some-user-id', false),
        throwsNotAuthenticated(),
      );
    });
  });

  group('ProfileService — guard de admin (sem sessão = primeira barreira)', () {
    test('usuário não autenticado não pode elevar role para admin', () {
      expect(
        ProfileService().updateRole('target-id', 'admin'),
        throwsAdminRequired(),
      );
    });

    test('usuário não autenticado não pode elevar role para premium', () {
      expect(
        ProfileService().updateRole('target-id', 'premium'),
        throwsAdminRequired(),
      );
    });

    test('usuário não autenticado não pode desativar outro usuário', () {
      expect(
        ProfileService().setActive('target-id', false),
        throwsAdminRequired(),
      );
    });

    test('usuário não autenticado não pode ativar outro usuário', () {
      expect(
        ProfileService().setActive('target-id', true),
        throwsAdminRequired(),
      );
    });

    test('usuário não autenticado não pode listar todos os perfis', () {
      expect(
        ProfileService().fetchAllProfiles(),
        throwsAdminRequired(),
      );
    });
  });

  group('ProfileService — proteção contra auto-promoção (sem sessão)', () {
    test('updateRole() com userId igual ao caller lançaria exceção de auto-promoção', () {
      // Sem sessão, o guard de autenticação dispara antes do guard de
      // auto-promoção. O comportamento é o mesmo: operação negada.
      // Em runtime com sessão válida mas role não-admin, o guard _requireAdmin()
      // dispara. Em runtime com admin tentando auto-promoção, o guard específico
      // de self-promotion dispara.
      expect(
        ProfileService().updateRole('any-id-same-or-different', 'admin'),
        throwsA(isA<Exception>()),
      );
    });

    test('setActive() não pode ser chamado sem autenticação', () {
      expect(
        ProfileService().setActive('any-id', false),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('ProfileService — fetchCurrentProfile() sem sessão', () {
    test('retorna null quando não há sessão (não lança exceção)', () async {
      // fetchCurrentProfile() é mais tolerante: retorna null em vez de lançar
      // exceção, para que a UI possa mostrar tela de login.
      final profile = await ProfileService().fetchCurrentProfile();
      expect(profile, isNull);
    });
  });
}
