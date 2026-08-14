import 'dart:math';

import '../models/document_grounding.dart';
import '../models/knowledge_item.dart';

// Serviço de grounding: chunk → relevance → budget → source manifest.
// Não faz chamadas de rede. Determinístico e testável de forma isolada.
class DocumentContextBuilder {
  static const int maxChunkSize          = 800;
  static const int chunkOverlap          = 100;
  static const int maxDocumentContextChars = 8000;
  static const int maxExcerptChars       = 500;

  // Divide content em janelas sobrepostas de tamanho fixo.
  static List<String> chunk(
    String content, {
    int maxSize = maxChunkSize,
    int overlap = chunkOverlap,
  }) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return [];

    final chunks = <String>[];
    int start = 0;
    while (start < trimmed.length) {
      final end = min(start + maxSize, trimmed.length);
      final part = trimmed.substring(start, end).trim();
      if (part.isNotEmpty) chunks.add(part);
      if (end >= trimmed.length) break;
      start = end - overlap;
    }
    return chunks;
  }

  // Proporção de palavras do contexto encontradas no chunk (sem embeddings).
  static double relevanceScore(String chunkText, String context) {
    if (context.isEmpty || chunkText.isEmpty) return 0.0;

    final contextWords = context
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((w) => w.length > 3)
        .toSet();
    if (contextWords.isEmpty) return 0.0;

    final chunkWords = chunkText.toLowerCase().split(RegExp(r'\W+'));
    if (chunkWords.isEmpty) return 0.0;

    final hits = chunkWords.where(contextWords.contains).length;
    return hits / chunkWords.length;
  }

  // Constrói DocumentGrounding a partir de KnowledgeItems respeitando o budget de chars.
  // Garante: cada documento que entra tem seu trecho real no contexto (grounded).
  static DocumentGrounding buildGrounding(
    List<KnowledgeItem> items, {
    String projectContext = '',
    int maxChars = maxDocumentContextChars,
  }) {
    if (items.isEmpty) return DocumentGrounding.empty;

    int charBudget = maxChars;
    int processed  = 0;
    int usable     = 0;
    int used       = 0;
    final excerpts = <DocumentExcerpt>[];
    final warnings = <GroundingWarning>[];

    for (final item in items) {
      processed++;

      if (item.content.trim().isEmpty) {
        warnings.add(GroundingWarning(
          code:    'EMPTY_CONTENT',
          message: '"${item.title}": registrado mas sem conteúdo processável.',
        ));
        continue;
      }
      usable++;

      if (charBudget <= 0) continue;

      final chunks = chunk(item.content);
      if (chunks.isEmpty) continue;

      // Seleciona o chunk mais relevante; se sem contexto, usa o primeiro.
      String best;
      int bestIndex;
      if (projectContext.isEmpty) {
        best      = chunks.first;
        bestIndex = 0;
      } else {
        int topIdx     = 0;
        double topScore = -1;
        for (int i = 0; i < chunks.length; i++) {
          final s = relevanceScore(chunks[i], projectContext);
          if (s > topScore) { topScore = s; topIdx = i; }
        }
        best      = chunks[topIdx];
        bestIndex = topIdx;
      }

      final raw     = best.length > maxExcerptChars ? best.substring(0, maxExcerptChars) : best;
      final excerpt = raw.length > charBudget ? raw.substring(0, charBudget) : raw;

      excerpts.add(DocumentExcerpt(
        documentId:    item.id,
        documentTitle: item.title,
        chunkIndex:    bestIndex,
        text:          excerpt,
        charCount:     excerpt.length,
      ));
      used++;
      charBudget -= excerpt.length;

      if (charBudget <= 0) {
        warnings.add(GroundingWarning(
          code:    'BUDGET_EXCEEDED',
          message: 'Limite de ${maxChars} chars atingido. Documentos posteriores omitidos.',
        ));
        break;
      }
    }

    final total    = items.length;
    final coverage = GroundingCoverage(
      totalLinked:           total,
      processed:             processed,
      usable:                usable,
      used:                  used,
      documentUsageCoverage: total > 0 ? used / total : 0.0,
    );

    return DocumentGrounding(
      excerpts: excerpts,
      coverage: coverage,
      warnings: warnings,
    );
  }
}
