/// Testes do AssetClassifierService.
///
/// Cenários:
///   1.  URL de app store → asset (app)
///   2.  URL de Amazon → evidence
///   3.  URL de GitHub → asset (technology)
///   4.  URL genérica → evidence
///   5.  Texto curto (< 20 palavras) → evidence
///   6.  Texto longo (> 500 palavras) → asset (content_property)
///   7.  Texto médio → resource
///   8.  PDF com "livro" no título → asset (book)
///   9.  PDF com "relatório" no título → evidence
///  10.  ZIP → asset (0.5 confiança)
///  11.  Imagem → resource
///  12.  CSV → resource
///  13.  Google Drive com "livro" → asset (book)
///  14.  Manual → asset (0.6 confiança)
///  15.  classificationConfidence reflete o valor retornado

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_social_copilot/data/services/asset_classifier_service.dart';
import 'package:ai_social_copilot/data/models/ingestion_source.dart';
import 'package:ai_social_copilot/data/models/asset_provenance.dart';
import 'package:ai_social_copilot/data/models/parsed_content.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

ParsedContent _content({
  String rawText       = '',
  String? title,
  Map<String, dynamic>? structuredData,
  IngestionSource source = IngestionSource.text,
}) => ParsedContent(
  rawText:        rawText,
  title:          title,
  structuredData: structuredData,
  provenance: AssetProvenance(
    sourceType:    source,
    importedAt:    DateTime(2026),
    parserVersion: '1',
  ),
);

ParsedContent _url(String url) => _content(
  rawText:        url,
  source:         IngestionSource.url,
  structuredData: {
    'url':    url,
    'domain': Uri.tryParse(url)?.host ?? '',
  },
);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  const classifier = AssetClassifierService();

  group('AssetClassifierService — URLs', () {
    test('1. URL de Play Store → asset (app)', () {
      final r = classifier.classify(_url('https://play.google.com/store/apps/details?id=com.example'));
      expect(r.classification, IngestionClassification.asset);
      expect(r.suggestedType,  'app');
      expect(r.confidence,     greaterThanOrEqualTo(0.8));
    });

    test('2. URL de Amazon → evidence', () {
      final r = classifier.classify(_url('https://www.amazon.com.br/produto/123'));
      expect(r.classification, IngestionClassification.evidence);
      expect(r.confidence,     greaterThan(0.7));
    });

    test('3. URL de GitHub → asset (technology)', () {
      final r = classifier.classify(_url('https://github.com/user/repo'));
      expect(r.classification, IngestionClassification.asset);
      expect(r.suggestedType,  'technology');
    });

    test('4. URL genérica → evidence', () {
      final r = classifier.classify(_url('https://example.com/page'));
      expect(r.classification, IngestionClassification.evidence);
    });
  });

  group('AssetClassifierService — Texto', () {
    test('5. Texto curto (< 20 palavras) → evidence', () {
      final r = classifier.classify(_content(rawText: 'Nota breve.'));
      expect(r.classification, IngestionClassification.evidence);
    });

    test('6. Texto longo (> 500 palavras) → asset', () {
      final longText = List.generate(600, (i) => 'palavra$i').join(' ');
      final r = classifier.classify(_content(rawText: longText));
      expect(r.classification, IngestionClassification.asset);
      expect(r.suggestedType,  'content_property');
    });

    test('7. Texto médio (20–500 palavras) → resource', () {
      final medText = List.generate(100, (i) => 'palavra$i').join(' ');
      final r = classifier.classify(_content(rawText: medText));
      expect(r.classification, IngestionClassification.resource);
    });
  });

  group('AssetClassifierService — Documentos', () {
    test('8. PDF com "livro" no título → asset (book)', () {
      final c = _content(title: 'Meu Livro de Flutter', source: IngestionSource.pdf);
      final r = classifier.classify(c, source: IngestionSource.pdf);
      expect(r.classification, IngestionClassification.asset);
      expect(r.suggestedType,  'book');
    });

    test('9. PDF com "relatório" no título → evidence', () {
      final c = _content(title: 'Relatório de Mercado Q1', source: IngestionSource.pdf);
      final r = classifier.classify(c, source: IngestionSource.pdf);
      expect(r.classification, IngestionClassification.evidence);
    });

    test('PDF genérico → resource', () {
      final c = _content(title: 'Documento sem categoria', source: IngestionSource.pdf);
      final r = classifier.classify(c, source: IngestionSource.pdf);
      expect(r.classification, IngestionClassification.resource);
    });
  });

  group('AssetClassifierService — outros formatos', () {
    test('10. ZIP → asset com confiança 0.5', () {
      final c = _content(source: IngestionSource.zip);
      final r = classifier.classify(c, source: IngestionSource.zip);
      expect(r.classification, IngestionClassification.asset);
      expect(r.confidence,     0.5);
    });

    test('11. Imagem → resource', () {
      final c = _content(source: IngestionSource.image);
      final r = classifier.classify(c, source: IngestionSource.image);
      expect(r.classification, IngestionClassification.resource);
    });

    test('12. CSV → resource', () {
      final c = _content(source: IngestionSource.csv);
      final r = classifier.classify(c, source: IngestionSource.csv);
      expect(r.classification, IngestionClassification.resource);
    });

    test('13. Google Drive com "ebook" no nome → asset (book)', () {
      final c = _content(title: 'meu_ebook.pdf', source: IngestionSource.googleDrive);
      final r = classifier.classify(c, source: IngestionSource.googleDrive, fileName: 'meu_ebook.pdf');
      expect(r.classification, IngestionClassification.asset);
      expect(r.suggestedType,  'book');
    });

    test('14. Manual → asset (0.6 confiança)', () {
      final c = _content(source: IngestionSource.manual);
      final r = classifier.classify(c, source: IngestionSource.manual);
      expect(r.classification, IngestionClassification.asset);
      expect(r.confidence,     0.6);
    });
  });

  group('AssetClassifierService — confiança', () {
    test('15. confidence está entre 0.0 e 1.0 para todos os resultados', () {
      final testCases = [
        _url('https://play.google.com/app'),
        _url('https://amazon.com.br/livro'),
        _content(rawText: 'curto'),
        _content(rawText: List.generate(600, (i) => 'x').join(' ')),
        _content(source: IngestionSource.image),
      ];
      for (final c in testCases) {
        final r = classifier.classify(c);
        expect(r.confidence, inInclusiveRange(0.0, 1.0),
            reason: 'Confiança fora do range para ${c.provenance.sourceType}');
      }
    });
  });
}
