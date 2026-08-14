// Models para rastreamento de grounding de documentos no contexto do copilot.
// Princípio: DOCUMENT EXISTS ≠ DOCUMENT ANALYZED. METADATA ≠ KNOWLEDGE.

class DocumentExcerpt {
  final String documentId;
  final String documentTitle;
  final int chunkIndex;
  final String text;
  final int charCount;

  const DocumentExcerpt({
    required this.documentId,
    required this.documentTitle,
    required this.chunkIndex,
    required this.text,
    required this.charCount,
  });

  Map<String, dynamic> toMap() => {
    'doc_id':          documentId,
    'title':           documentTitle,
    'content_excerpt': text,
    'chunk_index':     chunkIndex,
    'chars':           charCount,
  };
}

class GroundingCoverage {
  final int totalLinked;
  final int processed;
  final int usable;
  final int used;
  final double documentUsageCoverage;
  // Chars efectivamente selecionados dos documentos (soma de excerpt.charCount).
  final int selectedCharacterCount;
  // Chars disponíveis em todos os documentos usáveis (content.trim().length).
  final int availableContentCharCount;

  const GroundingCoverage({
    required this.totalLinked,
    required this.processed,
    required this.usable,
    required this.used,
    required this.documentUsageCoverage,
    this.selectedCharacterCount    = 0,
    this.availableContentCharCount = 0,
  });

  Map<String, dynamic> toMap() => {
    'total_linked':              totalLinked,
    'processed':                 processed,
    'usable':                    usable,
    'used':                      used,
    'document_usage_coverage':   documentUsageCoverage,
    'selected_char_count':       selectedCharacterCount,
    'available_content_chars':   availableContentCharCount,
  };

  static const GroundingCoverage empty = GroundingCoverage(
    totalLinked:             0,
    processed:               0,
    usable:                  0,
    used:                    0,
    documentUsageCoverage:   0.0,
    selectedCharacterCount:  0,
    availableContentCharCount: 0,
  );
}

class GroundingWarning {
  final String code;
  final String message;

  const GroundingWarning({required this.code, required this.message});
}

class DocumentGrounding {
  final List<DocumentExcerpt> excerpts;
  final GroundingCoverage coverage;
  final List<GroundingWarning> warnings;

  const DocumentGrounding({
    required this.excerpts,
    required this.coverage,
    this.warnings = const [],
  });

  bool get hasContent => excerpts.isNotEmpty;

  static const DocumentGrounding empty = DocumentGrounding(
    excerpts: [],
    coverage: GroundingCoverage.empty,
    warnings: [],
  );
}
