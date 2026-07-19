/// Testes dos modelos do Asset Ingestion Hub.
///
/// Cenários:
///   1.  IngestionSource.dbValue mapeado corretamente
///   2.  IngestionSource.fromDb roundtrip
///   3.  IngestionClassification.label para todos os valores
///   4.  AssetProvenance.toMap inclui todos os campos
///   5.  AssetProvenance.fromMap reconstrói corretamente
///   6.  AssetProvenance.copyWith mantém campos não alterados
///   7.  ParsedContent.hasFingerprint false quando null
///   8.  ParsedContent.hasFingerprint true quando preenchido
///   9.  ParsedContent.copyWith substitui campos
///  10.  AssetImportProposal.hasDuplicates false quando lista vazia
///  11.  AssetImportProposal.hasDuplicates true com candidatos
///  12.  AssetImportProposal.copyWith clearTargetAsset remove ID
///  13.  DuplicateCandidate.confidenceLabel correto por faixa
///  14.  AssetImportResult.totalAssetsCreated soma recursiva
///  15.  AssetResource.toInsertMap inclui apenas campos não-null
///  16.  AssetResource.toInsertMap omite campos null
///  17.  IngestionSession.isLoading true nos estados de carregamento
///  18.  IngestionSession.needsConfirmation true apenas no estado certo
///  19.  IngestionSession.copyWith clearError remove erro

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_social_copilot/data/models/ingestion_source.dart';
import 'package:ai_social_copilot/data/models/asset_provenance.dart';
import 'package:ai_social_copilot/data/models/parsed_content.dart';
import 'package:ai_social_copilot/data/models/asset_import_proposal.dart';
import 'package:ai_social_copilot/data/models/asset_import_result.dart';
import 'package:ai_social_copilot/data/models/asset_resource.dart';

void main() {
  // ── 1. IngestionSource.dbValue ──────────────────────────────────────────
  group('IngestionSource', () {
    test('1. dbValue mapeado corretamente para casos especiais', () {
      expect(IngestionSource.fileUpload.dbValue,  'file_upload');
      expect(IngestionSource.googleDrive.dbValue, 'google_drive');
      expect(IngestionSource.manual.dbValue,      'manual');
      expect(IngestionSource.zip.dbValue,         'zip');
    });

    test('2. fromDb roundtrip para todos os valores', () {
      for (final src in IngestionSource.values) {
        expect(IngestionSource.fromDb(src.dbValue), src,
            reason: 'roundtrip falhou para ${src.dbValue}');
      }
    });

    test('fromDb valor desconhecido retorna fileUpload', () {
      expect(IngestionSource.fromDb('unknown'), IngestionSource.fileUpload);
      expect(IngestionSource.fromDb(null),      IngestionSource.fileUpload);
    });
  });

  // ── 3. IngestionClassification ───────────────────────────────────────────
  group('IngestionClassification', () {
    test('3. label não vazio para todos os valores', () {
      for (final c in IngestionClassification.values) {
        expect(c.label, isNotEmpty, reason: 'label vazio para $c');
        expect(c.description, isNotEmpty, reason: 'description vazio para $c');
      }
    });
  });

  // ── 4–6. AssetProvenance ─────────────────────────────────────────────────
  group('AssetProvenance', () {
    final ts = DateTime(2026, 1, 1);

    test('4. toMap inclui todos os campos obrigatórios', () {
      final prov = AssetProvenance(
        sourceType:    IngestionSource.url,
        sourceId:      'sid',
        sourceName:    'Test',
        sourceUrl:     'https://example.com',
        importedAt:    ts,
        parserVersion: '1.0.0',
        confidence:    0.9,
      );
      final map = prov.toMap();
      expect(map['source_type'],    'url');
      expect(map['imported_at'],    ts.toIso8601String());
      expect(map['parser_version'], '1.0.0');
      expect(map['confidence'],     0.9);
      expect(map['source_id'],      'sid');
      expect(map['source_name'],    'Test');
      expect(map['source_url'],     'https://example.com');
    });

    test('4b. toMap omite campos null', () {
      final prov = AssetProvenance(
        sourceType:    IngestionSource.text,
        importedAt:    ts,
        parserVersion: '1.0.0',
      );
      final map = prov.toMap();
      expect(map.containsKey('source_id'),   isFalse);
      expect(map.containsKey('source_name'), isFalse);
      expect(map.containsKey('source_url'),  isFalse);
    });

    test('5. fromMap reconstrói corretamente', () {
      final prov = AssetProvenance(
        sourceType:    IngestionSource.pdf,
        importedAt:    ts,
        parserVersion: '2.0.0',
        confidence:    0.75,
        sourceName:    'Doc',
      );
      final map      = prov.toMap();
      final restored = AssetProvenance.fromMap(map);
      expect(restored.sourceType,    IngestionSource.pdf);
      expect(restored.parserVersion, '2.0.0');
      expect(restored.confidence,    0.75);
      expect(restored.sourceName,    'Doc');
    });

    test('6. copyWith mantém campos não alterados', () {
      final prov = AssetProvenance(
        sourceType:    IngestionSource.text,
        importedAt:    ts,
        parserVersion: '1.0.0',
        confidence:    0.5,
      );
      final copy = prov.copyWith(confidence: 0.9);
      expect(copy.confidence,    0.9);
      expect(copy.sourceType,    IngestionSource.text);
      expect(copy.parserVersion, '1.0.0');
    });
  });

  // ── 7–9. ParsedContent ───────────────────────────────────────────────────
  group('ParsedContent', () {
    AssetProvenance _prov() => AssetProvenance(
      sourceType: IngestionSource.text, importedAt: DateTime.now(), parserVersion: '1',
    );

    test('7. hasFingerprint false quando null', () {
      final c = ParsedContent(rawText: 'hi', provenance: _prov());
      expect(c.hasFingerprint, isFalse);
    });

    test('8. hasFingerprint true quando preenchido', () {
      final c = ParsedContent(
        rawText:     'hi',
        fingerprint: 'abc123',
        provenance:  _prov(),
      );
      expect(c.hasFingerprint, isTrue);
    });

    test('9. copyWith substitui campos e mantém outros', () {
      final c = ParsedContent(
        rawText:     'original',
        title:       'Título',
        fingerprint: 'fp',
        provenance:  _prov(),
      );
      final copy = c.copyWith(title: 'Novo Título');
      expect(copy.title,       'Novo Título');
      expect(copy.rawText,     'original');
      expect(copy.fingerprint, 'fp');
    });
  });

  // ── 10–12. AssetImportProposal ───────────────────────────────────────────
  group('AssetImportProposal', () {
    AssetProvenance _prov() => AssetProvenance(
      sourceType: IngestionSource.manual, importedAt: DateTime.now(), parserVersion: '1',
    );

    ParsedContent _content() =>
        ParsedContent(rawText: 'test', provenance: _prov());

    AssetImportProposal _base({
      List<DuplicateCandidate> dupes = const [],
      String? targetAssetId,
    }) => AssetImportProposal(
      sessionId:      'sess-1',
      source:         IngestionSource.manual,
      classification: IngestionClassification.asset,
      parsedContent:  _content(),
      suggestedTitle: 'Título',
      duplicateCandidates: dupes,
      targetAssetId:  targetAssetId,
    );

    test('10. hasDuplicates false quando lista vazia', () {
      expect(_base().hasDuplicates, isFalse);
    });

    test('11. hasDuplicates true com candidatos', () {
      final dupes = [
        DuplicateCandidate(
          existingId:    'x',
          existingTitle: 'Existente',
          matchReason:   'nome',
          confidence:    0.8,
        ),
      ];
      expect(_base(dupes: dupes).hasDuplicates, isTrue);
    });

    test('12. copyWith clearTargetAsset remove ID', () {
      final p    = _base(targetAssetId: 'asset-123');
      final copy = p.copyWith(clearTargetAsset: true);
      expect(copy.targetAssetId, isNull);
      expect(p.targetAssetId,    'asset-123'); // original inalterado
    });
  });

  // ── 13. DuplicateCandidate ───────────────────────────────────────────────
  group('DuplicateCandidate', () {
    test('13. confidenceLabel correto por faixa', () {
      final high = DuplicateCandidate(
        existingId: 'a', existingTitle: 'A', matchReason: 'x', confidence: 0.95,
      );
      final med  = DuplicateCandidate(
        existingId: 'b', existingTitle: 'B', matchReason: 'y', confidence: 0.75,
      );
      final low  = DuplicateCandidate(
        existingId: 'c', existingTitle: 'C', matchReason: 'z', confidence: 0.5,
      );
      expect(high.confidenceLabel, 'Alta');
      expect(med.confidenceLabel,  'Média');
      expect(low.confidenceLabel,  'Baixa');
    });
  });

  // ── 14. AssetImportResult ────────────────────────────────────────────────
  group('AssetImportResult', () {
    test('14. totalAssetsCreated soma recursiva de filhos', () {
      final child1 = AssetImportResult(
        sessionId:      'c1',
        source:         IngestionSource.txt,
        classification: IngestionClassification.asset,
        createdAt:      DateTime.now(),
        createdAssetId: 'asset-child-1',
      );
      final child2 = AssetImportResult(
        sessionId:      'c2',
        source:         IngestionSource.txt,
        classification: IngestionClassification.resource,
        createdAt:      DateTime.now(),
        createdResourceId: 'res-1',
      );
      final parent = AssetImportResult(
        sessionId:      'parent',
        source:         IngestionSource.zip,
        classification: IngestionClassification.asset,
        createdAt:      DateTime.now(),
        createdAssetId: 'asset-parent',
        childResults:   [child1, child2],
      );
      expect(parent.totalAssetsCreated,    2); // parent + child1
      expect(parent.totalResourcesCreated, 1); // child2
    });
  });

  // ── 15–16. AssetResource.toInsertMap ─────────────────────────────────────
  group('AssetResource', () {
    AssetResource _resource({String? sourceUrl}) => AssetResource(
      id:           '',
      assetId:      'asset-1',
      userId:       'user-1',
      resourceType: 'document',
      title:        'Documento Teste',
      sourceUrl:    sourceUrl,
      createdAt:    DateTime(2026),
    );

    test('15. toInsertMap inclui sourceUrl quando presente', () {
      final map = _resource(sourceUrl: 'https://example.com').toInsertMap();
      expect(map['source_url'], 'https://example.com');
      expect(map['asset_id'],   'asset-1');
      expect(map['user_id'],    'user-1');
      expect(map['title'],      'Documento Teste');
    });

    test('16. toInsertMap omite sourceUrl quando null', () {
      final map = _resource().toInsertMap();
      expect(map.containsKey('source_url'), isFalse);
    });
  });

  // ── 17–19. IngestionSession ──────────────────────────────────────────────
  group('IngestionSession', () {
    IngestionSession _session(IngestionStatus status) => IngestionSession(
      sessionId: 'sess',
      source:    IngestionSource.text,
      status:    status,
    );

    test('17. isLoading true nos estados de carregamento', () {
      expect(_session(IngestionStatus.parsing).isLoading,   isTrue);
      expect(_session(IngestionStatus.importing).isLoading, isTrue);
      expect(_session(IngestionStatus.creating).isLoading,  isTrue);
      expect(_session(IngestionStatus.completed).isLoading, isFalse);
    });

    test('18. needsConfirmation true apenas em awaitingConfirmation', () {
      expect(_session(IngestionStatus.awaitingConfirmation).needsConfirmation, isTrue);
      expect(_session(IngestionStatus.parsing).needsConfirmation,              isFalse);
      expect(_session(IngestionStatus.completed).needsConfirmation,            isFalse);
    });

    test('19. copyWith clearError remove erro', () {
      final s    = _session(IngestionStatus.failed).copyWith(error: 'falhou');
      final copy = s.copyWith(clearError: true, status: IngestionStatus.parsing);
      expect(copy.error,  isNull);
      expect(s.error,     'falhou'); // original inalterado
    });
  });
}
