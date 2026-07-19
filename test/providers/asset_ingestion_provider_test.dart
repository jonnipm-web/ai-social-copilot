/// Testes do AssetIngestionProvider.
///
/// Cenários:
///   1.  estado inicial é null
///   2.  startWithText → status awaitingConfirmation após ingestão
///   3.  startWithText → proposal preenchida com título
///   4.  cancel → status cancelled
///   5.  reset → estado volta a null
///   6.  updateProposal → proposal substituída
///   7.  startWithUrl com URL inválida → status failed
///   8.  serviço lança exceção → status failed com mensagem de erro
///   9.  nenhum dado criado antes de confirm
///  10.  session ID diferente a cada startWithText

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ai_social_copilot/data/models/asset_import_proposal.dart';
import 'package:ai_social_copilot/data/models/asset_import_result.dart';
import 'package:ai_social_copilot/data/models/ingestion_source.dart';
import 'package:ai_social_copilot/data/models/asset_provenance.dart';
import 'package:ai_social_copilot/data/models/parsed_content.dart';
import 'package:ai_social_copilot/data/services/asset_ingestion_service.dart';
import 'package:ai_social_copilot/providers/asset_ingestion_provider.dart';

// ── Mock ─────────────────────────────────────────────────────────────────────

class MockIngestionService extends Mock implements AssetIngestionServiceInterface {}

// ── Helpers ───────────────────────────────────────────────────────────────────

AssetImportProposal _fakeProposal({String title = 'Ativo Teste'}) => AssetImportProposal(
  sessionId:      'sess-fake',
  source:         IngestionSource.text,
  classification: IngestionClassification.asset,
  parsedContent: ParsedContent(
    rawText: 'conteúdo',
    provenance: AssetProvenance(
      sourceType:    IngestionSource.text,
      importedAt:    DateTime(2026),
      parserVersion: '1',
    ),
  ),
  suggestedTitle: title,
);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockIngestionService mockSvc;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url:     'http://localhost:54321',
        anonKey: 'test-anon-key',
      );
    } catch (_) {}
    registerFallbackValue(_fakeProposal());
    registerFallbackValue(IngestionClassification.asset);
    registerFallbackValue(DuplicateDecision.createNew);
    registerFallbackValue(IngestionSource.text);
  });

  setUp(() {
    mockSvc = MockIngestionService();
  });

  ProviderContainer _container() => ProviderContainer(
    overrides: [
      assetIngestionServiceProvider.overrideWithValue(mockSvc),
    ],
  );

  group('AssetIngestionProvider — estado inicial', () {
    test('1. estado inicial é null', () {
      final c = _container();
      addTearDown(c.dispose);
      expect(c.read(assetIngestionProvider), isNull);
    });
  });

  group('AssetIngestionProvider — ingestão de texto', () {
    test('2. startWithText → status awaitingConfirmation após sucesso', () async {
      when(() => mockSvc.ingestText(
        text: any(named: 'text'),
        projectId: any(named: 'projectId'),
        source: any(named: 'source'),
        title: any(named: 'title'),
      )).thenAnswer((_) async => _fakeProposal());

      final c   = _container();
      addTearDown(c.dispose);

      await c.read(assetIngestionProvider.notifier).startWithText(
        text:      'Texto de teste',
        projectId: 'proj-1',
      );

      final session = c.read(assetIngestionProvider);
      expect(session?.status, IngestionStatus.awaitingConfirmation);
    });

    test('3. proposal preenchida com título correto', () async {
      when(() => mockSvc.ingestText(
        text: any(named: 'text'),
        projectId: any(named: 'projectId'),
        source: any(named: 'source'),
        title: any(named: 'title'),
      )).thenAnswer((_) async => _fakeProposal(title: 'Meu Produto'));

      final c = _container();
      addTearDown(c.dispose);

      await c.read(assetIngestionProvider.notifier).startWithText(
        text:      'Texto',
        projectId: 'proj-1',
      );

      final session = c.read(assetIngestionProvider);
      expect(session?.proposal?.suggestedTitle, 'Meu Produto');
    });
  });

  group('AssetIngestionProvider — cancelamento', () {
    test('4. cancel → status cancelled', () async {
      when(() => mockSvc.ingestText(
        text: any(named: 'text'),
        projectId: any(named: 'projectId'),
        source: any(named: 'source'),
        title: any(named: 'title'),
      )).thenAnswer((_) async => _fakeProposal());
      when(() => mockSvc.cancelSession(any())).thenAnswer((_) async {});

      final c = _container();
      addTearDown(c.dispose);

      await c.read(assetIngestionProvider.notifier).startWithText(
        text:      'Texto',
        projectId: 'proj-1',
      );
      await c.read(assetIngestionProvider.notifier).cancel();

      final session = c.read(assetIngestionProvider);
      expect(session?.status, IngestionStatus.cancelled);
    });

    test('9. nenhum dado criado antes de confirm — confirmProposal não chamado', () async {
      when(() => mockSvc.ingestText(
        text: any(named: 'text'),
        projectId: any(named: 'projectId'),
        source: any(named: 'source'),
        title: any(named: 'title'),
      )).thenAnswer((_) async => _fakeProposal());
      when(() => mockSvc.cancelSession(any())).thenAnswer((_) async {});

      final c = _container();
      addTearDown(c.dispose);

      await c.read(assetIngestionProvider.notifier).startWithText(
        text: 'Texto', projectId: 'p1',
      );
      await c.read(assetIngestionProvider.notifier).cancel();

      // confirmProposal NUNCA deve ter sido chamado
      verifyNever(() => mockSvc.confirmProposal(
        proposal:                any(named: 'proposal'),
        confirmedTitle:          any(named: 'confirmedTitle'),
        confirmedClassification: any(named: 'confirmedClassification'),
        confirmedType:           any(named: 'confirmedType'),
        targetAssetId:           any(named: 'targetAssetId'),
        duplicateDecision:       any(named: 'duplicateDecision'),
      ));
    });
  });

  group('AssetIngestionProvider — reset', () {
    test('5. reset → estado volta a null', () async {
      when(() => mockSvc.ingestText(
        text: any(named: 'text'),
        projectId: any(named: 'projectId'),
        source: any(named: 'source'),
        title: any(named: 'title'),
      )).thenAnswer((_) async => _fakeProposal());

      final c = _container();
      addTearDown(c.dispose);

      await c.read(assetIngestionProvider.notifier).startWithText(
        text: 'x', projectId: 'p',
      );
      expect(c.read(assetIngestionProvider), isNotNull);

      c.read(assetIngestionProvider.notifier).reset();
      expect(c.read(assetIngestionProvider), isNull);
    });
  });

  group('AssetIngestionProvider — updateProposal', () {
    test('6. updateProposal substitui a proposal sem alterar outros campos', () async {
      when(() => mockSvc.ingestText(
        text: any(named: 'text'),
        projectId: any(named: 'projectId'),
        source: any(named: 'source'),
        title: any(named: 'title'),
      )).thenAnswer((_) async => _fakeProposal(title: 'Original'));

      final c = _container();
      addTearDown(c.dispose);

      await c.read(assetIngestionProvider.notifier).startWithText(
        text: 'x', projectId: 'p',
      );

      final updatedProposal = _fakeProposal(title: 'Atualizado');
      c.read(assetIngestionProvider.notifier).updateProposal(updatedProposal);

      final session = c.read(assetIngestionProvider);
      expect(session?.proposal?.suggestedTitle, 'Atualizado');
      expect(session?.status, IngestionStatus.awaitingConfirmation); // status preservado
    });
  });

  group('AssetIngestionProvider — erros', () {
    test('8. serviço lança exceção → status failed com mensagem', () async {
      when(() => mockSvc.ingestText(
        text: any(named: 'text'),
        projectId: any(named: 'projectId'),
        source: any(named: 'source'),
        title: any(named: 'title'),
      )).thenThrow(Exception('Erro de parsing'));

      final c = _container();
      addTearDown(c.dispose);

      await c.read(assetIngestionProvider.notifier).startWithText(
        text: 'x', projectId: 'p',
      );

      final session = c.read(assetIngestionProvider);
      expect(session?.status, IngestionStatus.failed);
      expect(session?.error,  isNotNull);
      expect(session?.error,  contains('Erro de parsing'));
    });

    test('7. startWithUrl com URL inválida → status failed', () async {
      when(() => mockSvc.ingestUrl(
        url:       any(named: 'url'),
        projectId: any(named: 'projectId'),
      )).thenThrow(Exception('URL inválida'));

      final c = _container();
      addTearDown(c.dispose);

      await c.read(assetIngestionProvider.notifier).startWithUrl(
        url: 'nao_e_uma_url', projectId: 'proj-1',
      );

      final session = c.read(assetIngestionProvider);
      expect(session?.status, IngestionStatus.failed);
    });
  });

  group('AssetIngestionProvider — session ID', () {
    test('10. session ID diferente a cada startWithText', () async {
      when(() => mockSvc.ingestText(
        text: any(named: 'text'),
        projectId: any(named: 'projectId'),
        source: any(named: 'source'),
        title: any(named: 'title'),
      )).thenAnswer((_) async => _fakeProposal());

      final c = _container();
      addTearDown(c.dispose);

      await c.read(assetIngestionProvider.notifier).startWithText(
        text: 'primeiro', projectId: 'p',
      );
      final id1 = c.read(assetIngestionProvider)?.sessionId;

      c.read(assetIngestionProvider.notifier).reset();
      await Future.delayed(const Duration(milliseconds: 5));

      await c.read(assetIngestionProvider.notifier).startWithText(
        text: 'segundo', projectId: 'p',
      );
      final id2 = c.read(assetIngestionProvider)?.sessionId;

      expect(id1, isNotNull);
      expect(id2, isNotNull);
      expect(id1, isNot(id2));
    });
  });
}
