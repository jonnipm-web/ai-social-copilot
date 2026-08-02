import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/content_item.dart';
import '../models/context_coverage_details.dart';
import '../models/evidence_origin.dart';
import '../models/knowledge_analysis.dart';
import '../models/knowledge_item.dart';
import '../models/market_analysis.dart';
import '../models/project.dart';
import '../models/project_intelligence_context.dart';
import 'content_service.dart';
import 'knowledge_service.dart';
import 'market_analysis_service.dart';
import 'project_service.dart';

// Configurable limits — kept as named constants so tests can reason about them.
const int _kMaxKnowledgeFetch = 8;
const int _kMaxVaultFetch = 6;
const int _kMaxLibraryFetch = 5;
const int _kMaxPersonasFetch = 5;
const int _kMaxAnalysesFetch = 3;
const int _kMaxCharsKnowledge = 300;
const int _kMaxCharsVault = 250;
const int _kMaxCharsLibrary = 200;

class ProjectIntelligenceContextService {
  final _client = Supabase.instance.client;
  final _projectService = ProjectService();
  final _knowledgeService = KnowledgeService();
  final _contentService = ContentService();
  final _marketService = MarketAnalysisService();

  Future<ProjectIntelligenceContext> buildForProject(String projectId) async {
    final results = await Future.wait([
      _projectService.fetchById(projectId).catchError((_) => null as Project?),
      _knowledgeService
          .fetchAll(projectId: projectId)
          .catchError((_) => <KnowledgeItem>[]),
      _contentService
          .fetchAll(projectId: projectId)
          .catchError((_) => <ContentItem>[]),
      _marketService
          .fetchAll(projectId: projectId)
          .catchError((_) => <MarketAnalysis>[]),
      _knowledgeService
          .fetchAnalysisByProject(projectId)
          .catchError((_) => <KnowledgeAnalysis>[]),
    ]);

    final project = results[0] as Project?;
    final knowledgeItems = results[1] as List<KnowledgeItem>;
    final contentItems = results[2] as List<ContentItem>;
    final analyses = results[3] as List<MarketAnalysis>;
    final vaultAnalyses = results[4] as List<KnowledgeAnalysis>;
    final personaNames = await _fetchPersonaNames(projectId);
    final latestAnalysis = analyses.isNotEmpty ? analyses.first : null;
    final now = DateTime.now();

    // Build ranked, deduplicated source item lists
    final knowledgeCtxItems = _buildKnowledgeItems(knowledgeItems, projectId);
    final vaultCtxItems = _buildVaultItems(vaultAnalyses, projectId);
    final libraryCtxItems = _buildLibraryItems(contentItems, projectId);

    // Cross-list dedup: if an id appears in knowledge it won't appear in vault/library
    final seenIds = <String>{};
    final dedupKnowledge =
        knowledgeCtxItems.where((k) => seenIds.add(k.id)).toList();
    final dedupVault = vaultCtxItems.where((v) => seenIds.add(v.id)).toList();
    final dedupLibrary =
        libraryCtxItems.where((l) => seenIds.add(l.id)).toList();

    final coverageDetails = _computeCoverageDetails(
      project: project,
      knowledgeItems: knowledgeItems,
      contentItems: contentItems,
      analyses: analyses,
      vaultAnalyses: vaultAnalyses,
      personaNames: personaNames,
      latestAnalysis: latestAnalysis,
      calculatedAt: now,
    );

    return ProjectIntelligenceContext(
      project: project,
      inputText: _buildInputText(project, latestAnalysis),
      inputType: 'project',
      niche: latestAnalysis?.niche ?? project?.detailsJson['niche'] as String?,
      audience: latestAnalysis?.targetAudience ??
          project?.detailsJson['audience'] as String?,
      monetization: latestAnalysis?.monetizationModel,
      valueProposition:
          latestAnalysis?.valueProposition ?? project?.description,
      positioning: latestAnalysis?.positioning,
      stage: project?.status,
      knowledgeItems: dedupKnowledge,
      vaultItems: dedupVault,
      libraryItems: dedupLibrary,
      previousAnalyses: analyses
          .take(_kMaxAnalysesFetch)
          .map(ContextAnalysisSummary.fromAnalysis)
          .toList(),
      personaNames: personaNames,
      coverage: coverageDetails.overall,
      missingData: _computeMissingData(
        project: project,
        knowledgeCount: dedupKnowledge.length,
        contentCount: dedupLibrary.length,
        analysisCount: analyses.length,
        personaCount: personaNames.length,
      ),
      coverageDetails: coverageDetails,
      generatedAt: now,
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
        coverageDetails: ctx.coverageDetails,
        generatedAt: ctx.generatedAt,
      );
    }

    return ProjectIntelligenceContext(
      inputText: inputText,
      inputType: inputType,
      generatedAt: DateTime.now(),
    );
  }

  // ── Source item builders ──────────────────────────────────────────────────

  List<ContextSourceItem> _buildKnowledgeItems(
    List<KnowledgeItem> items,
    String projectId,
  ) {
    final analyzed = items
        .where((k) => k.status == 'analyzed' && k.content.isNotEmpty)
        .toList()
      // Rank by content richness (longer analyzed content → higher relevance)
      ..sort((a, b) => b.content.length.compareTo(a.content.length));

    return analyzed.take(_kMaxKnowledgeFetch).map((k) {
      final freshness = _freshnessScore(k.createdAt);
      return ContextSourceItem(
        id: k.id,
        title: k.title,
        summary: _truncate(k.content, _kMaxCharsKnowledge),
        sourceType: 'knowledge',
        projectId: projectId,
        relevanceScore: 0.8,
        confidenceScore: 0.7,
        freshnessScore: freshness,
        evidenceOrigin: EvidenceOrigin.documentExtracted,
        createdAt: k.createdAt,
      );
    }).toList();
  }

  List<ContextSourceItem> _buildVaultItems(
    List<KnowledgeAnalysis> analyses,
    String projectId,
  ) {
    final valid = analyses
        .where((ka) => ka.summary != null && ka.summary!.isNotEmpty)
        .toList()
      ..sort((a, b) {
        final aLen = a.summary?.length ?? 0;
        final bLen = b.summary?.length ?? 0;
        return bLen.compareTo(aLen);
      });

    return valid
        .take(_kMaxVaultFetch)
        .map((ka) => ContextSourceItem(
              id: ka.id,
              title: 'Análise: ${ka.knowledgeItemId}',
              summary: _truncate(ka.summary!, _kMaxCharsVault),
              sourceType: 'vault',
              projectId: projectId,
              relevanceScore: 0.9,
              confidenceScore: 0.8,
              freshnessScore: 0.6,
              evidenceOrigin: EvidenceOrigin.analysisDerived,
            ))
        .toList();
  }

  List<ContextSourceItem> _buildLibraryItems(
    List<ContentItem> items,
    String projectId,
  ) {
    final scored = items.toList()
      ..sort((a, b) {
        final aLen = (a.baseText ?? a.description ?? '').length;
        final bLen = (b.baseText ?? b.description ?? '').length;
        return bLen.compareTo(aLen);
      });

    return scored
        .take(_kMaxLibraryFetch)
        .map((c) => ContextSourceItem(
              id: c.id,
              title: c.title,
              summary: _truncate(
                  c.baseText ?? c.description ?? c.title, _kMaxCharsLibrary),
              sourceType: 'content',
              projectId: projectId,
              relevanceScore: 0.6,
              confidenceScore: 0.5,
              freshnessScore: 0.5,
              evidenceOrigin: EvidenceOrigin.userProvided,
            ))
        .toList();
  }

  // ── Coverage (dimensional methodology v2.0) ───────────────────────────────

  ContextCoverageDetails _computeCoverageDetails({
    required Project? project,
    required List<KnowledgeItem> knowledgeItems,
    required List<ContentItem> contentItems,
    required List<MarketAnalysis> analyses,
    required List<KnowledgeAnalysis> vaultAnalyses,
    required List<String> personaNames,
    required MarketAnalysis? latestAnalysis,
    required DateTime calculatedAt,
  }) {
    final dims = <ContextCoverageDimension>[];

    // 1. Project Identity — weight 0.20
    dims.add(_dim(
      id: 'project_identity',
      label: 'Identidade do Projeto',
      weight: 0.20,
      present: [
        if (project != null) 'id',
        if (project?.name.isNotEmpty ?? false) 'name',
        if (project?.description.isNotEmpty ?? false) 'description',
        if (project?.type.isNotEmpty ?? false) 'type',
        if (project?.status.isNotEmpty ?? false) 'status',
      ],
      missing: [
        if (project == null) 'project',
        if (!(project?.name.isNotEmpty ?? false)) 'name',
        if (!(project?.description.isNotEmpty ?? false)) 'description',
      ],
      total: 4,
    ));

    // 2. Problem & Value — weight 0.10
    final vp = latestAnalysis?.valueProposition ?? project?.description;
    dims.add(_dim(
      id: 'problem_and_value',
      label: 'Problema e Proposta de Valor',
      weight: 0.10,
      present: [
        if (vp != null && vp.isNotEmpty) 'value_proposition',
        if (latestAnalysis?.positioning != null) 'positioning',
      ],
      missing: [
        if (!(vp != null && vp.isNotEmpty)) 'value_proposition',
        if (latestAnalysis?.positioning == null) 'positioning',
      ],
      total: 2,
    ));

    // 3. Target Audience — weight 0.15
    dims.add(_dim(
      id: 'target_audience',
      label: 'Público-Alvo',
      weight: 0.15,
      present: [
        if (latestAnalysis?.targetAudience != null) 'target_audience',
        if (personaNames.isNotEmpty) 'personas',
      ],
      missing: [
        if (latestAnalysis?.targetAudience == null) 'target_audience',
        if (personaNames.isEmpty) 'personas',
      ],
      total: 2,
    ));

    // 4. Market & Niche — weight 0.10
    final niche =
        latestAnalysis?.niche ?? project?.detailsJson['niche'] as String?;
    dims.add(_dim(
      id: 'market_and_niche',
      label: 'Mercado e Nicho',
      weight: 0.10,
      present: [
        if (niche != null && niche.isNotEmpty) 'niche',
        if (latestAnalysis?.subNiche != null) 'sub_niche',
      ],
      missing: [
        if (!(niche != null && niche.isNotEmpty)) 'niche',
        if (latestAnalysis?.subNiche == null) 'sub_niche',
      ],
      total: 2,
    ));

    // 5. Monetization — weight 0.10
    dims.add(_dim(
      id: 'monetization',
      label: 'Modelo de Monetização',
      weight: 0.10,
      present: [
        if (latestAnalysis?.monetizationModel != null) 'monetization_model',
      ],
      missing: [
        if (latestAnalysis?.monetizationModel == null) 'monetization_model',
      ],
      total: 1,
    ));

    // 6. Knowledge Base — weight 0.15
    final analyzedCount = knowledgeItems
        .where((k) => k.status == 'analyzed' && k.content.isNotEmpty)
        .length;
    final vaultCount = vaultAnalyses
        .where((v) => v.summary != null && v.summary!.isNotEmpty)
        .length;
    dims.add(_dimRaw(
      id: 'knowledge_base',
      label: 'Base de Conhecimento',
      weight: 0.15,
      score: ((analyzedCount + vaultCount) / 5.0).clamp(0.0, 1.0),
      present: [
        if (analyzedCount > 0) 'knowledge_items ($analyzedCount)',
        if (vaultCount > 0) 'vault_analyses ($vaultCount)',
      ],
      missing: [
        if (analyzedCount == 0) 'knowledge_items',
        if (vaultCount == 0) 'vault_analyses',
      ],
    ));

    // 7. Market Evidence — weight 0.10
    dims.add(_dimRaw(
      id: 'market_evidence',
      label: 'Evidências de Mercado',
      weight: 0.10,
      score: (analyses.length / 2.0).clamp(0.0, 1.0),
      present: [
        if (analyses.isNotEmpty) 'market_analyses (${analyses.length})'
      ],
      missing: [if (analyses.isEmpty) 'market_analyses'],
    ));

    // 8. Competitor Evidence — weight 0.05 (proxy via analyses)
    dims.add(_dimRaw(
      id: 'competitor_evidence',
      label: 'Evidências Competitivas',
      weight: 0.05,
      score: analyses.isNotEmpty ? 0.5 : 0.0,
      present: [if (analyses.isNotEmpty) 'via_analyses'],
      missing: [if (analyses.isEmpty) 'competitor_analysis'],
    ));

    // 9. Execution Evidence — weight 0.03
    dims.add(_dimRaw(
      id: 'execution_evidence',
      label: 'Evidências de Execução',
      weight: 0.03,
      score: (contentItems.length / 3.0).clamp(0.0, 1.0),
      present: [
        if (contentItems.isNotEmpty) 'content_items (${contentItems.length})'
      ],
      missing: [if (contentItems.isEmpty) 'content_items'],
    ));

    // 10. Financial Evidence — weight 0.02
    final hasRevenue =
        latestAnalysis != null && latestAnalysis.revenueMonthlyMax > 0;
    dims.add(_dimRaw(
      id: 'financial_evidence',
      label: 'Evidências Financeiras',
      weight: 0.02,
      score: hasRevenue ? 1.0 : 0.0,
      present: [if (hasRevenue) 'revenue_estimates'],
      missing: [if (!hasRevenue) 'revenue_estimates'],
    ));

    final overall =
        dims.fold(0.0, (sum, d) => sum + d.score * d.weight).clamp(0.0, 1.0);
    final missingRequired = dims
        .where((d) =>
            d.weight >= 0.10 && d.status == CoverageDimensionStatus.missing)
        .map((d) => d.id)
        .toList();

    return ContextCoverageDetails(
      overall: overall,
      dimensions: dims,
      missingRequiredDimensions: missingRequired,
      calculatedAt: calculatedAt,
    );
  }

  ContextCoverageDimension _dim({
    required String id,
    required String label,
    required double weight,
    required List<String> present,
    required List<String> missing,
    required int total,
  }) {
    final score = total == 0 ? 0.0 : present.length / total;
    return _dimRaw(
        id: id,
        label: label,
        weight: weight,
        score: score,
        present: present,
        missing: missing);
  }

  ContextCoverageDimension _dimRaw({
    required String id,
    required String label,
    required double weight,
    required double score,
    required List<String> present,
    required List<String> missing,
  }) {
    final s = score.clamp(0.0, 1.0);
    final status = s >= 0.8
        ? CoverageDimensionStatus.sufficient
        : s > 0
            ? CoverageDimensionStatus.partial
            : CoverageDimensionStatus.missing;
    return ContextCoverageDimension(
      id: id,
      label: label,
      score: s,
      weight: weight,
      status: status,
      fieldsPresent: present,
      fieldsMissing: missing,
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
          .limit(_kMaxPersonasFetch);
      return (rows as List).map((r) => r['name'] as String).toList();
    } catch (_) {
      return [];
    }
  }

  String _buildInputText(Project? project, MarketAnalysis? analysis) {
    if (project == null) return '';
    final parts = <String>[];
    parts.add('Projeto: ${project.name}');
    if (project.description.isNotEmpty)
      parts.add('Descrição: ${project.description}');
    if (analysis?.niche != null) parts.add('Nicho: ${analysis!.niche}');
    if (analysis?.targetAudience != null)
      parts.add('Público: ${analysis!.targetAudience}');
    return parts.join('\n');
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
    if (project?.description.isEmpty ?? true)
      missing.add('Descrição do projeto');
    if (knowledgeCount == 0) missing.add('Itens no Cofre de Conhecimento');
    if (contentCount == 0) missing.add('Itens na Biblioteca de Conteúdo');
    if (analysisCount == 0) missing.add('Análise de mercado anterior');
    if (personaCount == 0) missing.add('Personas definidas');
    return missing;
  }

  static double _freshnessScore(DateTime? createdAt) {
    if (createdAt == null) return 0.5;
    final ageDays = DateTime.now().difference(createdAt).inDays;
    if (ageDays <= 30) return 1.0;
    if (ageDays <= 90) return 0.8;
    if (ageDays <= 180) return 0.6;
    if (ageDays <= 365) return 0.4;
    return 0.2;
  }

  static String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}…';
  }
}
