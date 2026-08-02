import 'market_analysis.dart';
import 'project.dart';

// ── ProjectIntelligenceContext ────────────────────────────────────────────────
//
// Snapshot consolidado de um projeto para uso pelas Edge Functions de IA.
// Montado pelo ProjectIntelligenceContextService antes de cada chamada de análise.
// Nunca envia documentos completos — apenas resumos + sourceIds.

class ProjectIntelligenceContext {
  final Project? project;
  final String inputText;
  final String inputType;

  // Dados estruturados do projeto
  final String? niche;
  final String? audience;
  final String? monetization;
  final String? valueProposition;
  final String? positioning;
  final String? stage; // status do projeto

  // Conhecimento indexado (vault + knowledge items) — apenas resumos
  final List<ContextSourceItem> knowledgeItems;
  final List<ContextSourceItem> vaultItems;
  final List<ContextSourceItem> libraryItems;

  // Análises anteriores — apenas headline scores
  final List<ContextAnalysisSummary> previousAnalyses;

  // Personas
  final List<String> personaNames;

  // Cobertura
  final double coverage; // 0.0 – 1.0
  final List<String> missingData;

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
    required this.generatedAt,
  });

  // Snapshot compacto para injetar no prompt da IA (sem exceder tokens)
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
          .take(5)
          .map((k) => {'title': k.title, 'summary': k.summary})
          .toList();
    }

    if (vaultItems.isNotEmpty) {
      buf['vault_context'] = vaultItems
          .take(5)
          .map((v) => {'title': v.title, 'summary': v.summary})
          .toList();
    }

    if (previousAnalyses.isNotEmpty) {
      buf['previous_analyses'] = previousAnalyses
          .take(2)
          .map((a) => {
                'niche': a.niche,
                'score': a.opportunityScore,
                'date': a.date.toIso8601String().substring(0, 10),
              })
          .toList();
    }

    if (personaNames.isNotEmpty) {
      buf['personas'] = personaNames.take(3).toList();
    }

    if (missingData.isNotEmpty) {
      buf['missing_data'] = missingData;
    }

    buf['coverage'] = coverage;
    buf['generated_at'] = generatedAt.toIso8601String();

    return buf;
  }

  // IDs das fontes usadas (para rastreabilidade)
  List<String> get sourceIds => [
        ...knowledgeItems.map((k) => k.id),
        ...vaultItems.map((v) => v.id),
        ...libraryItems.map((l) => l.id),
      ];

  bool get hasProjectContext => project != null;

  bool get hasKnowledgeContext =>
      knowledgeItems.isNotEmpty || vaultItems.isNotEmpty;

  bool get isSufficientForAnalysis => hasProjectContext || inputText.length > 50;
}

// ── ContextSourceItem ─────────────────────────────────────────────────────────

class ContextSourceItem {
  final String id;
  final String title;
  final String summary;
  final String sourceType;

  const ContextSourceItem({
    required this.id,
    required this.title,
    required this.summary,
    this.sourceType = 'knowledge',
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
