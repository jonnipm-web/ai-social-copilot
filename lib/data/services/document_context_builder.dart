import 'dart:math';

import '../models/document_grounding.dart';
import '../models/knowledge_item.dart';

// Private helpers for the 2-pass budget algorithm.
class _ScoredChunk {
  final int    chunkIndex;
  final String text;
  final double score;
  const _ScoredChunk({required this.chunkIndex, required this.text, required this.score});
}

class _ItemChunks {
  final KnowledgeItem    item;
  final List<_ScoredChunk> chunks; // sorted by score desc
  const _ItemChunks({required this.item, required this.chunks});
}

class _Pass2Candidate {
  final KnowledgeItem item;
  final _ScoredChunk  scored;
  _Pass2Candidate(this.item, this.scored);
}

// Serviço de grounding: chunk → relevance → 2-pass adaptive budget → source manifest.
// Não faz chamadas de rede. Determinístico e testável de forma isolada.
class DocumentContextBuilder {
  static const int maxChunkSize            = 800;
  static const int chunkOverlap            = 100;
  static const int maxDocumentContextChars = 8000;

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
      final end  = min(start + maxSize, trimmed.length);
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

  // Constrói DocumentGrounding com budget global adaptativo (2 passes).
  //
  // Pass 1 — Document Diversity:
  //   Para cada documento (ordenados por relevância desc):
  //     Seleciona o chunk de maior relevância.
  //     Aloca até o budget restante (sem cota fixa por documento).
  //     Para se o budget for esgotado.
  //
  // Pass 2 — Budget Fill:
  //   Se ainda há budget após o Pass 1:
  //     Coleta todos os chunks restantes globalmente.
  //     Ordena por relevância desc.
  //     Adiciona até o budget esgotar (permite múltiplos excerpts por documento).
  //
  // Invariante: SET(excerpts.documentId) ⊆ SET(items com content não-vazio).
  // coverage.used = número de documentos únicos com pelo menos um excerpt.
  static DocumentGrounding buildGrounding(
    List<KnowledgeItem> items, {
    String projectContext = '',
    int    maxChars       = maxDocumentContextChars,
  }) {
    if (items.isEmpty) return DocumentGrounding.empty;

    // ── Fase 0: chunking + scoring de todos os itens ──────────────────────────
    final warnings          = <GroundingWarning>[];
    final itemChunks        = <_ItemChunks>[];
    int   processed         = 0;
    int   usable            = 0;
    int   availableChars    = 0;

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
      availableChars += item.content.trim().length;

      final rawChunks = chunk(item.content);
      if (rawChunks.isEmpty) continue;

      final scored = rawChunks.asMap().entries.map((e) {
        final score = projectContext.isEmpty
            ? 0.0
            : relevanceScore(e.value, projectContext);
        return _ScoredChunk(chunkIndex: e.key, text: e.value, score: score);
      }).toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      itemChunks.add(_ItemChunks(item: item, chunks: scored));
    }

    // ── Pass 1: um melhor chunk por documento (diversidade) ───────────────────
    // Ordena por score do chunk mais relevante de cada documento.
    final sorted = [...itemChunks]
      ..sort((a, b) => b.chunks.first.score.compareTo(a.chunks.first.score));

    int   charBudget        = maxChars;
    final excerpts          = <DocumentExcerpt>[];
    final usedChunksByDocId = <String, Set<int>>{};

    for (final ic in sorted) {
      if (charBudget <= 0) {
        warnings.add(GroundingWarning(
          code:    'BUDGET_EXCEEDED',
          message: 'Limite de ${maxChars} chars atingido. Documentos posteriores omitidos.',
        ));
        break;
      }

      final best = ic.chunks.first;
      final text = best.text.length > charBudget
          ? best.text.substring(0, charBudget)
          : best.text;
      if (text.isEmpty) continue;

      excerpts.add(DocumentExcerpt(
        documentId:    ic.item.id,
        documentTitle: ic.item.title,
        chunkIndex:    best.chunkIndex,
        text:          text,
        charCount:     text.length,
      ));
      usedChunksByDocId.putIfAbsent(ic.item.id, () => {}).add(best.chunkIndex);
      charBudget -= text.length;
    }

    // ── Pass 2: preenche budget restante com chunks globalmente rankeados ─────
    if (charBudget > 0) {
      final candidates = <_Pass2Candidate>[];
      for (final ic in sorted) {
        final usedIdx = usedChunksByDocId[ic.item.id] ?? {};
        for (final sc in ic.chunks) {
          if (!usedIdx.contains(sc.chunkIndex)) {
            candidates.add(_Pass2Candidate(ic.item, sc));
          }
        }
      }
      candidates.sort((a, b) => b.scored.score.compareTo(a.scored.score));

      for (final c in candidates) {
        if (charBudget <= 0) break;
        final text = c.scored.text.length > charBudget
            ? c.scored.text.substring(0, charBudget)
            : c.scored.text;
        if (text.isEmpty) continue;

        excerpts.add(DocumentExcerpt(
          documentId:    c.item.id,
          documentTitle: c.item.title,
          chunkIndex:    c.scored.chunkIndex,
          text:          text,
          charCount:     text.length,
        ));
        usedChunksByDocId
            .putIfAbsent(c.item.id, () => {})
            .add(c.scored.chunkIndex);
        charBudget -= text.length;
      }
    }

    // ── Coverage ──────────────────────────────────────────────────────────────
    final usedDocIds       = excerpts.map((e) => e.documentId).toSet();
    final used             = usedDocIds.length;
    final selectedChars    = maxChars - charBudget;
    final total            = items.length;

    final coverage = GroundingCoverage(
      totalLinked:              total,
      processed:                processed,
      usable:                   usable,
      used:                     used,
      documentUsageCoverage:    total > 0 ? used / total : 0.0,
      selectedCharacterCount:   selectedChars,
      availableContentCharCount: availableChars,
    );

    return DocumentGrounding(
      excerpts: excerpts,
      coverage: coverage,
      warnings: warnings,
    );
  }
}
