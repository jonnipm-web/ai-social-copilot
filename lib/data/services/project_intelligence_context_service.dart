import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/content_item.dart';
import '../models/knowledge_analysis.dart';
import '../models/knowledge_item.dart';
import '../models/market_analysis.dart';
import '../models/project.dart';
import '../models/project_intelligence_context.dart';
import 'content_service.dart';
import 'knowledge_service.dart';
import 'market_analysis_service.dart';
import 'project_service.dart';

// ── ProjectIntelligenceContextService ────────────────────────────────────────
//
// Único ponto de montagem de contexto de projeto para as Edge Functions de IA.
// Consulta Supabase em paralelo e retorna um snapshot compacto e rastreável.
// Nunca envia documentos completos — apenas resumos + sourceIds.

class ProjectIntelligenceContextService {
  final _client = Supabase.instance.client;
  final _projectService = ProjectService();
  final _knowledgeService = KnowledgeService();
  final _contentService = ContentService();
  final _marketService = MarketAnalysisService();

  // ── API principal ─────────────────────────────────────────────────────────

  Future<ProjectIntelligenceContext> buildForProject(String projectId) async {
    final results = await Future.wait([
      _projectService.fetchById(projectId).catchError((_) => null as Project?),
      _knowledgeService.fetchAll(projectId: projectId).catchError((_) => <KnowledgeItem>[]),
      _contentService.fetchAll(projectId: projectId).catchError((_) => <ContentItem>[]),
      _marketService.fetchAll(projectId: projectId).catchError((_) => <MarketAnalysis>[]),
      _knowledgeService.fetchAnalysisByProject(projectId).catchError((_) => <KnowledgeAnalysis>[]),
    ]);

    final project = results[0] as Project?;
    final knowledgeItems = results[1] as List<KnowledgeItem>;
    final contentItems = results[2] as List<ContentItem>;
    final analyses = results[3] as List<MarketAnalysis>;
    final vaultAnalyses = results[4] as List<KnowledgeAnalysis>;

    // Também busca personas (lightweight)
    final personaNames = await _fetchPersonaNames(projectId);

    final latestAnalysis = analyses.isNotEmpty ? analyses.first : null;

    final coverage = _computeCoverage(
      project: project,
      knowledgeCount: knowledgeItems.length,
      contentCount: contentItems.length,
      analysisCount: analyses.length,
      personaCount: personaNames.length,
    );

    return ProjectIntelligenceContext(
      project: project,
      inputText: _buildInputText(project, latestAnalysis),
      inputType: 'project',
      niche: latestAnalysis?.niche ?? project?.detailsJson['niche'] as String?,
      audience: latestAnalysis?.targetAudience ?? project?.detailsJson['audience'] as String?,
      monetization: latestAnalysis?.monetizationModel,
      valueProposition: latestAnalysis?.valueProposition ?? project?.description,
      positioning: latestAnalysis?.positioning,
      stage: project?.status,
      knowledgeItems: knowledgeItems
          .where((k) => k.status == 'analyzed' && k.content.isNotEmpty)
          .take(8)
          .map((k) => ContextSourceItem(
                id: k.id,
                title: k.title,
                summary: _truncate(k.content, 300),
                sourceType: 'knowledge',
              ))
          .toList(),
      vaultItems: vaultAnalyses
          .where((ka) => ka.summary != null && ka.summary!.isNotEmpty)
          .take(6)
          .map((ka) => ContextSourceItem(
                id: ka.id,
                title: 'Análise: ${ka.knowledgeItemId}',
                summary: _truncate(ka.summary!, 250),
                sourceType: 'vault',
              ))
          .toList(),
      libraryItems: contentItems
          .take(5)
          .map((c) => ContextSourceItem(
                id: c.id,
                title: c.title,
                summary: _truncate(c.baseText ?? c.description ?? c.title, 200),
                sourceType: 'content',
              ))
          .toList(),
      previousAnalyses: analyses
          .take(3)
          .map(ContextAnalysisSummary.fromAnalysis)
          .toList(),
      personaNames: personaNames,
      coverage: coverage,
      missingData: _computeMissingData(
        project: project,
        knowledgeCount: knowledgeItems.length,
        contentCount: contentItems.length,
        analysisCount: analyses.length,
        personaCount: personaNames.length,
      ),
      generatedAt: DateTime.now(),
    );
  }

  Future<ProjectIntelligenceContext> buildForInput(
    String inputText, {
    String inputType = 'text',
    String? projectId,
  }) async {
    if (projectId != null) {
      final ctx = await buildForProject(projectId);
      return ProjectIntelligenceContext(
        project: ctx.project,
        inputText: inputText,
        inputType: inputType,
        niche: ctx.niche,
        audience: ctx.audience,
        monetization: ctx.monetization,
        valueProposition: ctx.valueProposition,
        positioning: ctx.positioning,
        stage: ctx.stage,
        knowledgeItems: ctx.knowledgeItems,
        vaultItems: ctx.vaultItems,
        libraryItems: ctx.libraryItems,
        previousAnalyses: ctx.previousAnalyses,
        personaNames: ctx.personaNames,
        coverage: ctx.coverage,
        missingData: ctx.missingData,
        generatedAt: ctx.generatedAt,
      );
    }

    return ProjectIntelligenceContext(
      inputText: inputText,
      inputType: inputType,
      generatedAt: DateTime.now(),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<List<String>> _fetchPersonaNames(String projectId) async {
    try {
      final rows = await _client
          .from('personas')
          .select('name')
          .eq('user_id', _client.auth.currentUser?.id ?? '')
          .eq('project_id', projectId)
          .limit(5);
      return (rows as List).map((r) => r['name'] as String).toList();
    } catch (_) {
      return [];
    }
  }

  String _buildInputText(Project? project, MarketAnalysis? analysis) {
    if (project == null) return '';
    final parts = <String>[];
    parts.add('Projeto: ${project.name}');
    if (project.description.isNotEmpty) parts.add('Descrição: ${project.description}');
    if (analysis?.niche != null) parts.add('Nicho: ${analysis!.niche}');
    if (analysis?.targetAudience != null) parts.add('Público: ${analysis!.targetAudience}');
    return parts.join('\n');
  }

  double _computeCoverage({
    required Project? project,
    required int knowledgeCount,
    required int contentCount,
    required int analysisCount,
    required int personaCount,
  }) {
    double score = 0;
    if (project != null) score += 0.30;
    if (project?.description.isNotEmpty ?? false) score += 0.10;
    if (knowledgeCount > 0) score += 0.20;
    if (knowledgeCount >= 3) score += 0.10;
    if (contentCount > 0) score += 0.10;
    if (analysisCount > 0) score += 0.10;
    if (personaCount > 0) score += 0.10;
    return score.clamp(0.0, 1.0);
  }

  List<String> _computeMissingData({
    required Project? project,
    required int knowledgeCount,
    required int contentCount,
    required int analysisCount,
    required int personaCount,
  }) {
    final missing = <String>[];
    if (project == null) missing.add('Projeto não vinculado');
    if (project?.description.isEmpty ?? true) missing.add('Descrição do projeto');
    if (knowledgeCount == 0) missing.add('Itens no Cofre de Conhecimento');
    if (contentCount == 0) missing.add('Itens na Biblioteca de Conteúdo');
    if (analysisCount == 0) missing.add('Análise de mercado anterior');
    if (personaCount == 0) missing.add('Personas definidas');
    return missing;
  }

  static String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}…';
  }
}
