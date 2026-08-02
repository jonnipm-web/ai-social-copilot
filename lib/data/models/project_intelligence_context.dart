import 'context_coverage_details.dart';
import 'evidence_origin.dart';
import 'market_analysis.dart';
import 'project.dart';

// Limits (configurable constants, not magic numbers)
const int kCtxMaxKnowledgeInSnapshot = 5;
const int kCtxMaxVaultInSnapshot = 5;
const int kCtxMaxLibraryInSnapshot = 5;
const int kCtxMaxAnalysesInSnapshot = 2;
const int kCtxMaxPersonasInSnapshot = 3;

class ProjectIntelligenceContext {
  final Project? project;
  final String inputText;
  final String inputType;

  final String? niche;
  final String? audience;
  final String? monetization;
  final String? valueProposition;
  final String? positioning;
  final String? stage;

  final List<ContextSourceItem> knowledgeItems;
  final List<ContextSourceItem> vaultItems;
  final List<ContextSourceItem> libraryItems;

  final List<ContextAnalysisSummary> previousAnalyses;
  final List<String> personaNames;

  final double coverage;
  final List<String> missingData;

  // Detailed breakdown of coverage by dimension (nullable: absent for input-only contexts)
  final ContextCoverageDetails? coverageDetails;

  final DateTime generatedAt;

  const ProjectIntelligenceContext({
    this.project,
    required this.inputText,
    this.inputType = 'text',
    this.niche,
    this.audience,
    this.monetization,
    this.valueProposition,
    this.positioning,
    this.stage,
    this.knowledgeItems = const [],
    this.vaultItems = const [],
    this.libraryItems = const [],
    this.previousAnalyses = const [],
    this.personaNames = const [],
    this.coverage = 0.0,
    this.missingData = const [],
    this.coverageDetails,
    required this.generatedAt,
  });

  // Compact snapshot injected into AI prompt — includes source IDs for traceability
  Map<String, dynamic> toPromptSnapshot() {
    final buf = <String, dynamic>{
      'input': inputText,
      'input_type': inputType,
    };

    if (project != null) {
      buf['project'] = {
        'name': project!.name,
        'description': project!.description,
        'status': project!.status,
        if (niche != null) 'niche': niche,
        if (audience != null) 'audience': audience,
        if (monetization != null) 'monetization': monetization,
        if (valueProposition != null) 'value_proposition': valueProposition,
        if (stage != null) 'stage': stage,
      };
    }

    if (knowledgeItems.isNotEmpty) {
      buf['knowledge_context'] = knowledgeItems
          .take(kCtxMaxKnowledgeInSnapshot)
          .map((k) => {
                'id': k.id,
                'title': _sanitize(k.title),
                'summary': _sanitize(k.summary),
                'type': k.sourceType,
              })
          .toList();
    }

    if (vaultItems.isNotEmpty) {
      buf['vault_context'] = vaultItems
          .take(kCtxMaxVaultInSnapshot)
          .map((v) => {
                'id': v.id,
                'title': _sanitize(v.title),
                'summary': _sanitize(v.summary),
              })
          .toList();
    }

    if (libraryItems.isNotEmpty) {
      buf['library_context'] = libraryItems
          .take(kCtxMaxLibraryInSnapshot)
          .map((l) => {
                'id': l.id,
                'title': _sanitize(l.title),
                'summary': _sanitize(l.summary),
              })
          .toList();
    }

    if (previousAnalyses.isNotEmpty) {
      buf['previous_analyses'] = previousAnalyses
          .take(kCtxMaxAnalysesInSnapshot)
          .map((a) => {
                'id': a.id,
                'niche': a.niche,
                'score': a.opportunityScore,
                'date': a.date.toIso8601String().substring(0, 10),
              })
          .toList();
    }

    if (personaNames.isNotEmpty) {
      buf['personas'] = personaNames.take(kCtxMaxPersonasInSnapshot).toList();
    }

    if (missingData.isNotEmpty) {
      buf['missing_data'] = missingData;
    }

    buf['coverage'] = coverage;
    buf['generated_at'] = generatedAt.toIso8601String();

    return buf;
  }

  List<String> get sourceIds => [
        ...knowledgeItems.map((k) => k.id),
        ...vaultItems.map((v) => v.id),
        ...libraryItems.map((l) => l.id),
      ];

  bool get hasProjectContext => project != null;

  bool get hasKnowledgeContext =>
      knowledgeItems.isNotEmpty || vaultItems.isNotEmpty;

  bool get isSufficientForAnalysis =>
      hasProjectContext || inputText.length > 50;

  // Minimal sanitizer: removes LLM-specific token patterns that could act as
  // prompt delimiters inside external content (documents, summaries).
  static String _sanitize(String text) {
    if (text.isEmpty) return text;
    return text
        .replaceAll(RegExp(r'<\|.*?\|>'), '')
        .replaceAll(RegExp(r'\[/?INST\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'<</?SYS>>', caseSensitive: false), '');
  }
}

// ── ContextSourceItem ─────────────────────────────────────────────────────────

class ContextSourceItem {
  final String id;
  final String title;
  final String summary;
  final String sourceType;
  final String? projectId;
  final double relevanceScore;
  final double confidenceScore;
  final double freshnessScore;
  final EvidenceOrigin evidenceOrigin;
  final DateTime? createdAt;

  const ContextSourceItem({
    required this.id,
    required this.title,
    required this.summary,
    this.sourceType = 'knowledge',
    this.projectId,
    this.relevanceScore = 0.5,
    this.confidenceScore = 0.5,
    this.freshnessScore = 0.5,
    this.evidenceOrigin = EvidenceOrigin.documentExtracted,
    this.createdAt,
  });
}

// ── ContextAnalysisSummary ────────────────────────────────────────────────────

class ContextAnalysisSummary {
  final String id;
  final String? niche;
  final int opportunityScore;
  final DateTime date;

  const ContextAnalysisSummary({
    required this.id,
    this.niche,
    required this.opportunityScore,
    required this.date,
  });

  factory ContextAnalysisSummary.fromAnalysis(MarketAnalysis a) =>
      ContextAnalysisSummary(
        id: a.id,
        niche: a.niche,
        opportunityScore: a.opportunityScore,
        date: a.createdAt,
      );
}
