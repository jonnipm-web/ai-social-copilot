import 'dart:math' as math;

import '../models/action_queue_item.dart';
import '../models/knowledge_coverage.dart';
import '../models/knowledge_graph.dart';
import '../models/market_analysis.dart';
import '../models/opportunity_lab_item.dart';
import '../models/persona.dart';
import '../models/persona_learning_profile.dart';
import '../models/persona_training.dart';
import '../models/project.dart';
import '../models/project_intelligence_profile.dart';
import '../models/revenue_plan.dart';

class ProjectIntelligenceService {
  // ── Public API ─────────────────────────────────────────────────────────────

  List<ProjectIntelligenceProfile> computeProfiles({
    required List<Project> projects,
    required List<MarketAnalysis> analyses,
    required List<ActionQueueItem> actions,
    required List<OpportunityLabItem> labItems,
    required List<RevenuePlan> revenuePlans,
    required int totalKnowledgeItems,
  }) {
    return projects.map((p) {
      final analysis = _findAnalysis(p, analyses);
      final plan     = _findRevenuePlan(p, analysis, revenuePlans);
      final pActions = actions.where((a) => a.projectId == p.id).toList();
      final pLab     = labItems.where((l) => l.projectId == p.id).toList();

      final coverage = KnowledgeCoverage.compute(
        project:            p,
        analysis:           analysis,
        knowledgeItemCount: totalKnowledgeItems,
        actions:            pActions,
        labItems:           pLab,
        revenuePlan:        plan,
      );

      return ProjectIntelligenceProfile(
        project:             p,
        analysis:            analysis,
        coverage:            coverage,
        maturityStage:       _maturityStage(p, analysis, pActions, pLab, plan),
        relatedProjectNames: _relatedProjects(p, analysis, projects, analyses),
        identifiedTopics:    _identifiedTopics(analysis, pLab),
        missingKnowledge:    coverage.gaps,
        niche:               analysis?.niche ?? 'Não definido',
        targetAudience:      analysis?.targetAudience ?? 'Não definido',
        monetizationModel:   analysis?.monetizationModel ?? 'Não definido',
        valueProposition:    analysis?.valueProposition ?? p.description,
        computedAt:          DateTime.now(),
      );
    }).toList();
  }

  List<PersonaLearningProfile> computeLearningProfiles({
    required List<Persona> personas,
    required List<PersonaTraining> allTrainings,
  }) {
    return personas.map((persona) {
      final pTrainings = allTrainings.where((t) => t.personaId == persona.id).toList();
      return PersonaLearningProfile.compute(persona: persona, trainings: pTrainings);
    }).toList()
      ..sort((a, b) => b.learningScore.compareTo(a.learningScore));
  }

  KnowledgeGraph buildGraph({
    required List<Project> projects,
    required List<MarketAnalysis> analyses,
    required List<Persona> personas,
    required List<OpportunityLabItem> labItems,
  }) {
    final edges = <GraphEdge>[];

    // Project ↔ Project via shared niche
    for (var i = 0; i < projects.length; i++) {
      for (var j = i + 1; j < projects.length; j++) {
        final pA = projects[i];
        final pB = projects[j];
        final aA = _findAnalysis(pA, analyses);
        final aB = _findAnalysis(pB, analyses);
        if (aA == null || aB == null) continue;

        final nicheA = (aA.niche ?? '').toLowerCase();
        final nicheB = (aB.niche ?? '').toLowerCase();
        if (nicheA.isEmpty || nicheB.isEmpty) continue;

        final overlap = _nicheOverlap(nicheA, nicheB);
        if (overlap > 0.2) {
          edges.add(GraphEdge(
            sourceType:   'project',
            sourceId:     pA.id,
            sourceName:   pA.name,
            targetType:   'project',
            targetId:     pB.id,
            targetName:   pB.name,
            relationship: 'compartilha_nicho',
            weight:       overlap,
          ));
        }
      }
    }

    // Project → Opportunity
    for (final lab in labItems) {
      final project = projects.where((p) => p.id == lab.projectId).toList();
      if (project.isEmpty) continue;
      edges.add(GraphEdge(
        sourceType:   'project',
        sourceId:     project.first.id,
        sourceName:   project.first.name,
        targetType:   'opportunity',
        targetId:     lab.id,
        targetName:   lab.title,
        relationship: 'oportunidade_de',
        weight:       lab.finalScore / 100,
      ));
    }

    // Persona → Project (niche match)
    for (final persona in personas) {
      final personaNiche = (persona.niche ?? '').toLowerCase();
      if (personaNiche.isEmpty) continue;
      for (final p in projects) {
        final a = _findAnalysis(p, analyses);
        if (a == null) continue;
        final overlap = _nicheOverlap(personaNiche, (a.niche ?? '').toLowerCase());
        if (overlap > 0.3) {
          edges.add(GraphEdge(
            sourceType:   'persona',
            sourceId:     persona.id,
            sourceName:   persona.name,
            targetType:   'project',
            targetId:     p.id,
            targetName:   p.name,
            relationship: 'persona_conhece',
            weight:       overlap,
          ));
        }
      }
    }

    final nodes = <String>{};
    for (final e in edges) {
      nodes.add(e.sourceId);
      nodes.add(e.targetId);
    }

    return KnowledgeGraph(
      edges:      edges,
      nodeCount:  nodes.length,
      computedAt: DateTime.now(),
    );
  }

  // ── Portfolio coverage score (0-100) ────────────────────────────────────
  int portfolioCoverageScore(List<ProjectIntelligenceProfile> profiles) {
    if (profiles.isEmpty) return 0;
    return profiles.fold(0, (s, p) => s + p.coverage.score) ~/ profiles.length;
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  MarketAnalysis? _findAnalysis(Project p, List<MarketAnalysis> analyses) {
    if (analyses.isEmpty) return null;
    if (p.marketAnalysisId != null) {
      final direct = analyses.where((a) => a.id == p.marketAnalysisId).toList();
      if (direct.isNotEmpty) return direct.first;
    }
    if (p.url != null && p.url!.isNotEmpty) {
      final pUrl = _normalizeUrl(p.url!);
      for (final a in analyses) {
        if (_normalizeUrl(a.input) == pUrl) return a;
      }
    }
    return null;
  }

  RevenuePlan? _findRevenuePlan(Project p, MarketAnalysis? a, List<RevenuePlan> plans) {
    if (plans.isEmpty) return null;
    if (p.marketAnalysisId != null) {
      final d = plans.where((r) => r.marketAnalysisId == p.marketAnalysisId).toList();
      if (d.isNotEmpty) return d.first;
    }
    if (a != null) {
      final linked = plans.where((r) => r.marketAnalysisId == a.id).toList();
      if (linked.isNotEmpty) return linked.first;
    }
    return null;
  }

  String _normalizeUrl(String url) => url
      .toLowerCase()
      .replaceAll(RegExp(r'^https?://'), '')
      .replaceAll(RegExp(r'^www\.'), '')
      .replaceAll(RegExp(r'/$'), '')
      .split('?').first;

  String _maturityStage(
    Project p,
    MarketAnalysis? a,
    List<ActionQueueItem> actions,
    List<OpportunityLabItem> lab,
    RevenuePlan? plan,
  ) {
    if (a != null && actions.length >= 5 && lab.isNotEmpty && plan != null) return 'maduro';
    if (a != null && (actions.length >= 2 || lab.isNotEmpty)) return 'crescendo';
    if (a != null) return 'validando';
    return 'ideia';
  }

  List<String> _relatedProjects(
    Project current,
    MarketAnalysis? currentAnalysis,
    List<Project> allProjects,
    List<MarketAnalysis> allAnalyses,
  ) {
    if (currentAnalysis == null) return [];
    final cNiche = (currentAnalysis.niche ?? '').toLowerCase();
    if (cNiche.isEmpty) return [];

    return allProjects
        .where((p) => p.id != current.id)
        .where((p) {
          final a = _findAnalysis(p, allAnalyses);
          if (a == null) return false;
          return _nicheOverlap(cNiche, (a.niche ?? '').toLowerCase()) > 0;
        })
        .map((p) => p.name)
        .toList();
  }

  List<String> _identifiedTopics(MarketAnalysis? a, List<OpportunityLabItem> lab) {
    final topics = <String>{};
    if (a != null) {
      if (a.niche != null && a.niche!.isNotEmpty)              topics.add(a.niche!);
      if (a.businessType != null && a.businessType!.isNotEmpty) topics.add(a.businessType!);
      if (a.monetizationModel != null && a.monetizationModel!.isNotEmpty) topics.add(a.monetizationModel!);
    }
    for (final l in lab.take(3)) {
      if (l.opportunityType.isNotEmpty) topics.add(l.opportunityType);
    }
    return topics.toList();
  }

  double _nicheOverlap(String n1, String n2) {
    if (n1.isEmpty || n2.isEmpty) return 0;
    if (n1 == n2) return 1.0;
    final words1 = n1.split(RegExp(r'[\s,/]+')).where((w) => w.length > 3).toSet();
    final words2 = n2.split(RegExp(r'[\s,/]+')).where((w) => w.length > 3).toSet();
    final common = words1.intersection(words2).length;
    if (common == 0) return 0;
    return common / math.max(words1.length, words2.length);
  }
}
