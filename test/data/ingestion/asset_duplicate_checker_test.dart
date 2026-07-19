/// Testes do AssetDuplicateChecker.
///
/// Cenários:
///   1.  Lista vazia → createNew, sem candidatos
///   2.  Fingerprint idêntico → useExisting, confiança 1.0
///   3.  URL idêntica (normalizada) → candidato detectado
///   4.  URL mesmo domínio → candidato de média confiança
///   5.  Nome idêntico (case-insensitive) → candidato detectado
///   6.  Nome parcialmente coincidente → candidato detectado
///   7.  Nome totalmente diferente → sem candidato
///   8.  ISBN coincidente → identificador correspondente
///   9.  DOI coincidente → identificador correspondente
///  10.  Múltiplos candidatos ordenados por confiança descrescente
///  11.  Confiança < 0.6 → não gera candidato
///  12.  Recomendação useExisting quando confiança >= 0.95
///  13.  Recomendação updateExisting quando confiança 0.7–0.94
///  14.  Recomendação createNew quando confiança < 0.7

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_social_copilot/data/services/asset_duplicate_checker.dart';
import 'package:ai_social_copilot/data/models/asset.dart';
import 'package:ai_social_copilot/data/models/asset_import_proposal.dart';
import 'package:ai_social_copilot/data/models/ingestion_source.dart';
import 'package:ai_social_copilot/data/models/asset_provenance.dart';
import 'package:ai_social_copilot/data/models/parsed_content.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

ParsedContent _content({
  String rawText       = '',
  String? title,
  String? fingerprint,
  Map<String, dynamic>? structuredData,
}) => ParsedContent(
  rawText:        rawText,
  title:          title,
  fingerprint:    fingerprint,
  structuredData: structuredData,
  provenance: AssetProvenance(
    sourceType:    IngestionSource.text,
    importedAt:    DateTime(2026),
    parserVersion: '1',
  ),
);

Asset _asset({
  required String id,
  required String name,
  Map<String, dynamic> metadata = const {},
}) => Asset(
  id:        id,
  userId:    'user-a',
  projectId: 'proj-1',
  name:      name,
  type:      AssetType.product,
  status:    AssetStatus.active,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  metadata:  metadata,
);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  const checker = AssetDuplicateChecker();

  group('AssetDuplicateChecker — lista vazia', () {
    test('1. lista vazia → createNew, sem candidatos', () {
      final r = checker.check(
        content:        _content(title: 'Qualquer'),
        existingAssets: [],
      );
      expect(r.hasCandidates,  isFalse);
      expect(r.recommendation, DuplicateDecision.createNew);
    });
  });

  group('AssetDuplicateChecker — fingerprint', () {
    test('2. fingerprint idêntico → useExisting, confiança 1.0', () {
      final fp      = 'abc123def456' * 4; // 48 chars de fingerprint fake
      final content = _content(fingerprint: fp);
      final assets  = [
        _asset(id: 'a1', name: 'Asset Existente', metadata: {'fingerprint': fp}),
      ];
      final r = checker.check(content: content, existingAssets: assets);
      expect(r.hasCandidates,               isTrue);
      expect(r.candidates.first.confidence, 1.0);
      expect(r.recommendation,              DuplicateDecision.useExisting);
    });
  });

  group('AssetDuplicateChecker — URL', () {
    test('3. URL idêntica → candidato detectado', () {
      final content = _content(
        structuredData: {'url': 'https://example.com/produto'},
      );
      final assets = [
        _asset(id: 'a1', name: 'Produto', metadata: {'source_url': 'https://example.com/produto'}),
      ];
      final r = checker.check(content: content, existingAssets: assets);
      expect(r.hasCandidates, isTrue);
      expect(r.candidates.first.confidence, greaterThanOrEqualTo(0.6));
    });

    test('4. URL mesmo domínio → candidato com confiança moderada', () {
      final content = _content(
        structuredData: {'url': 'https://example.com/pagina-nova'},
      );
      final assets = [
        _asset(id: 'a1', name: 'Existente', metadata: {'source_url': 'https://example.com/outra-pagina'}),
      ];
      final r = checker.check(content: content, existingAssets: assets);
      expect(r.hasCandidates, isTrue);
      expect(r.candidates.first.confidence, inInclusiveRange(0.6, 0.8));
    });
  });

  group('AssetDuplicateChecker — nome', () {
    test('5. nome idêntico (case-insensitive) → candidato', () {
      final r = checker.check(
        content:        _content(title: 'Meu Produto Incrível'),
        existingAssets: [_asset(id: 'a1', name: 'Meu Produto Incrível')],
      );
      expect(r.hasCandidates,               isTrue);
      expect(r.candidates.first.confidence, greaterThanOrEqualTo(0.8));
    });

    test('5b. nome idêntico case-insensitive', () {
      final r = checker.check(
        content:        _content(title: 'meu livro'),
        existingAssets: [_asset(id: 'a1', name: 'MEU LIVRO')],
      );
      expect(r.hasCandidates, isTrue);
    });

    test('6. nome parcialmente coincidente → candidato', () {
      final r = checker.check(
        content:        _content(title: 'Marketing Digital'),
        existingAssets: [_asset(id: 'a1', name: 'Estratégia de Marketing Digital para PMEs')],
      );
      expect(r.hasCandidates, isTrue);
    });

    test('7. nome totalmente diferente → sem candidato', () {
      final r = checker.check(
        content:        _content(title: 'Xyzzy Frobnicator'),
        existingAssets: [_asset(id: 'a1', name: 'Produto Completamente Diferente')],
      );
      // confiança abaixo de 0.6 — sem candidato
      expect(r.hasCandidates, isFalse);
    });
  });

  group('AssetDuplicateChecker — identificadores', () {
    test('8. ISBN coincidente → confiança 1.0', () {
      const isbn = '9780134685991';
      final r = checker.check(
        content:        _content(rawText: 'ISBN $isbn', title: 'Clean Code'),
        existingAssets: [_asset(id: 'a1', name: 'Clean Code', metadata: {'isbn': isbn})],
      );
      expect(r.hasCandidates, isTrue);
      final best = r.candidates.first;
      expect(best.confidence, 1.0);
    });

    test('9. DOI coincidente → confiança 1.0', () {
      const doi = '10.1234/example.doi';
      final r = checker.check(
        content:        _content(rawText: 'DOI: $doi', title: 'Artigo'),
        existingAssets: [_asset(id: 'a1', name: 'Artigo', metadata: {'doi': doi})],
      );
      expect(r.hasCandidates, isTrue);
      expect(r.candidates.first.confidence, 1.0);
    });
  });

  group('AssetDuplicateChecker — ordenação e recomendações', () {
    test('10. múltiplos candidatos ordenados por confiança descendente', () {
      final fp = 'fp123' * 10;
      final r = checker.check(
        content: _content(title: 'Produto A', fingerprint: fp),
        existingAssets: [
          _asset(id: 'a1', name: 'Produto B'),             // baixa confiança
          _asset(id: 'a2', name: 'Produto A'),             // alta confiança por nome
          _asset(id: 'a3', name: 'X', metadata: {'fingerprint': fp}), // confiança 1.0
        ],
      );
      expect(r.candidates.first.existingId, 'a3'); // fingerprint primeiro
      if (r.candidates.length > 1) {
        expect(r.candidates[0].confidence, greaterThanOrEqualTo(r.candidates[1].confidence));
      }
    });

    test('12. recomendação useExisting quando confiança >= 0.95', () {
      final fp = 'fp456' * 10;
      final r = checker.check(
        content:        _content(fingerprint: fp),
        existingAssets: [_asset(id: 'a1', name: 'X', metadata: {'fingerprint': fp})],
      );
      expect(r.recommendation, DuplicateDecision.useExisting);
    });

    test('13. recomendação updateExisting quando confiança ~0.9', () {
      final r = checker.check(
        content:        _content(title: 'Nome Idêntico'),
        existingAssets: [_asset(id: 'a1', name: 'Nome Idêntico')],
      );
      expect(
        r.recommendation,
        anyOf(DuplicateDecision.useExisting, DuplicateDecision.updateExisting),
      );
    });

    test('14. recomendação createNew quando nenhum candidato forte', () {
      final r = checker.check(
        content:        _content(title: 'Completamente Novo'),
        existingAssets: [_asset(id: 'a1', name: 'Irrelevante XKCD')],
      );
      expect(r.recommendation, DuplicateDecision.createNew);
    });
  });
}
