import '../models/ingestion_source.dart';
import '../models/parsed_content.dart';

/// Resultado de classificação com confiança.
class ClassificationResult {
  const ClassificationResult({
    required this.classification,
    required this.confidence,
    this.reason       = '',
    this.suggestedType,
  });

  final IngestionClassification classification;
  final double                  confidence;
  final String                  reason;
  final String?                 suggestedType;
}

/// Classifica conteúdo parseado em Asset, Resource, Evidence ou Ignored.
///
/// A classificação é uma SUGESTÃO — o usuário sempre confirma antes da criação.
/// Nenhum dado é persistido durante a classificação.
class AssetClassifierService {
  const AssetClassifierService();

  ClassificationResult classify(
    ParsedContent content, {
    IngestionSource? source,
    String? fileName,
  }) {
    final src = source ?? content.provenance.sourceType;

    switch (src) {
      case IngestionSource.url:
        return _classifyUrl(content);
      case IngestionSource.text:
      case IngestionSource.txt:
        return _classifyText(content);
      case IngestionSource.zip:
        return const ClassificationResult(
          classification: IngestionClassification.asset,
          confidence:     0.5,
          reason:         'Pacote ZIP — cada item interno classificado individualmente',
          suggestedType:  'other',
        );
      case IngestionSource.googleDrive:
        return _classifyDrive(content, fileName);
      case IngestionSource.pdf:
      case IngestionSource.docx:
        return _classifyDocument(content, src);
      case IngestionSource.image:
        return const ClassificationResult(
          classification: IngestionClassification.resource,
          confidence:     0.75,
          reason:         'Imagens são tipicamente recursos vinculados a um ativo',
        );
      case IngestionSource.csv:
      case IngestionSource.xlsx:
        return const ClassificationResult(
          classification: IngestionClassification.resource,
          confidence:     0.7,
          reason:         'Dados tabulares são tipicamente recursos de análise',
          suggestedType:  'other',
        );
      case IngestionSource.manual:
      case IngestionSource.library:
      case IngestionSource.fileUpload:
        return const ClassificationResult(
          classification: IngestionClassification.asset,
          confidence:     0.6,
          reason:         'Entrada manual — classificação padrão como ativo',
        );
    }
  }

  List<ClassificationResult> classifyZipItems(List<DetectedItem> items) =>
      items.map((i) => classify(i.content, source: i.source, fileName: i.name)).toList();

  // ── Private ───────────────────────────────────────────────────────────────

  ClassificationResult _classifyUrl(ParsedContent content) {
    final structured = content.structuredData ?? {};
    final url        = (structured['url'] as String?) ?? content.rawText;
    final domain     = (structured['domain'] as String?) ?? '';

    const evidenceDomains = [
      'amazon.com', 'amazon.com.br', 'goodreads.com', 'scholar.google',
      'pubmed', 'arxiv.org', 'jstor.org', 'doi.org',
    ];
    if (evidenceDomains.any((d) => domain.contains(d))) {
      return ClassificationResult(
        classification: IngestionClassification.evidence,
        confidence:     0.85,
        reason:         'URL de fonte de referência ($domain)',
      );
    }
    if (domain.contains('play.google') || domain.contains('apps.apple.com')) {
      return const ClassificationResult(
        classification: IngestionClassification.asset,
        confidence:     0.9,
        reason:         'URL de aplicativo em loja de apps',
        suggestedType:  'app',
      );
    }
    if (domain.contains('github.com')) {
      return const ClassificationResult(
        classification: IngestionClassification.asset,
        confidence:     0.75,
        reason:         'Repositório GitHub — potencial ativo de tecnologia',
        suggestedType:  'technology',
      );
    }
    if (_hasKeyword(url + domain, ['product', 'produto', 'loja', 'shop', 'store', 'checkout'])) {
      return const ClassificationResult(
        classification: IngestionClassification.asset,
        confidence:     0.7,
        reason:         'URL parece ser de produto ou loja',
        suggestedType:  'website',
      );
    }
    return const ClassificationResult(
      classification: IngestionClassification.evidence,
      confidence:     0.6,
      reason:         'URL genérica — sugerida como referência/evidência',
    );
  }

  ClassificationResult _classifyText(ParsedContent content) {
    final wordCount = content.rawText.isEmpty
        ? 0
        : content.rawText.split(RegExp(r'\s+')).length;

    if (wordCount < 20) {
      return const ClassificationResult(
        classification: IngestionClassification.evidence,
        confidence:     0.65,
        reason:         'Texto curto — sugerido como nota/evidência',
      );
    }
    if (wordCount > 500) {
      return const ClassificationResult(
        classification: IngestionClassification.asset,
        confidence:     0.6,
        reason:         'Texto extenso — pode ser ativo de conteúdo',
        suggestedType:  'content_property',
      );
    }
    return const ClassificationResult(
      classification: IngestionClassification.resource,
      confidence:     0.65,
      reason:         'Texto de tamanho médio — sugerido como recurso',
    );
  }

  ClassificationResult _classifyDocument(ParsedContent content, IngestionSource src) {
    final title = (content.title ?? '').toLowerCase();
    if (_hasKeyword(title, ['análise', 'pesquisa', 'relatório', 'report', 'research'])) {
      return const ClassificationResult(
        classification: IngestionClassification.evidence,
        confidence:     0.8,
        reason:         'Documento de pesquisa — sugerido como evidência',
      );
    }
    if (_hasKeyword(title, ['livro', 'book', 'manual', 'guia', 'guide', 'ebook'])) {
      return const ClassificationResult(
        classification: IngestionClassification.asset,
        confidence:     0.8,
        reason:         'Documento parece ser livro ou guia — sugerido como ativo',
        suggestedType:  'book',
      );
    }
    return ClassificationResult(
      classification: IngestionClassification.resource,
      confidence:     0.7,
      reason:         'Documento ${src.label} — sugerido como recurso',
    );
  }

  ClassificationResult _classifyDrive(ParsedContent content, String? fileName) {
    final name = (fileName ?? content.title ?? '').toLowerCase();
    if (_hasKeyword(name, ['book', 'livro', 'ebook', 'course', 'curso'])) {
      return const ClassificationResult(
        classification: IngestionClassification.asset,
        confidence:     0.75,
        reason:         'Nome sugere ativo de conteúdo',
        suggestedType:  'book',
      );
    }
    return const ClassificationResult(
      classification: IngestionClassification.resource,
      confidence:     0.7,
      reason:         'Arquivo do Google Drive — sugerido como recurso',
    );
  }

  bool _hasKeyword(String text, List<String> keywords) {
    final lower = text.toLowerCase();
    return keywords.any((k) => lower.contains(k));
  }
}
