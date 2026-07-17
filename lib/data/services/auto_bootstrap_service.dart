import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../models/action_queue_item.dart';
import '../models/bootstrap_result.dart';
import '../models/knowledge_analysis.dart';
import '../models/knowledge_item.dart';
import '../models/market_analysis.dart';
import '../models/opportunity_lab_item.dart';
import '../models/persona.dart';
import '../models/persona_training.dart';
import '../models/project.dart';
import 'action_queue_service.dart';
import 'opportunity_lab_service.dart';
import 'persona_training_service.dart';

class AutoBootstrapService {
  final _client  = Supabase.instance.client;
  final _oppSvc  = OpportunityLabService();
  final _actSvc  = ActionQueueService();
  final _trainSvc = PersonaTrainingService();

  // ── Detect which projects need bootstrapping ────────────────────────────

  List<Project> detectNeedingBootstrap({
    required List<Project> projects,
    required List<ActionQueueItem> actions,
    required List<OpportunityLabItem> labItems,
    required List<KnowledgeItem> knowledgeItems,
  }) {
    if (knowledgeItems.isEmpty) return [];
    return projects.where((p) {
      final hasActions = actions.any((a) => a.projectId == p.id);
      final hasOpps    = labItems.any((l) => l.projectId == p.id);
      return !hasActions && !hasOpps;
    }).toList();
  }

  // ── Bootstrap a single project ──────────────────────────────────────────

  Future<BootstrapProjectResult> bootstrapProject({
    required Project project,
    required List<KnowledgeItem> knowledgeItems,
    required List<KnowledgeAnalysis> analyses,
    required List<Persona> personas,
    required List<PersonaTraining> existingTrainings,
    required MarketAnalysis? linkedAnalysis,
    void Function(String step)? onStep,
  }) async {
    int oppsCreated = 0;
    int actionsCreated = 0;
    bool revenuePlanCreated = false;
    bool roadmapCreated = false;
    int personasTrained = 0;

    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) throw Exception('Não autenticado');

      // ── Step 1: Generate opportunities + roadmap ──────────────────────
      onStep?.call('Gerando oportunidades');
      final docSummaries = knowledgeItems.take(6).map((k) => {
        'title':   k.title,
        'content': k.content.substring(0, math.min(400, k.content.length)),
      }).toList();

      final oppResp = await _client.functions.invoke(
        AppConstants.edgeFunctionGenerateOpportunities,
        body: {
          'project_name':        project.name,
          'project_description': project.description ?? '',
          'project_type':        project.type ?? '',
          'documents':           docSummaries,
          'market_context':      linkedAnalysis?.niche ?? '',
        },
      );

      final oppData = oppResp.data as Map<String, dynamic>?;
      final savedOpps = <OpportunityLabItem>[];

      if (oppData != null && !oppData.containsKey('error')) {
        // Save opportunities
        final rawOpps = (oppData['opportunities'] as List? ?? []);
        for (final raw in rawOpps) {
          if (raw is! Map<String, dynamic>) continue;
          final rawRisks = raw['risks'];
          final rawSteps = raw['action_steps'];

          final item = OpportunityLabItem(
            id:               '',
            userId:           uid,
            projectId:        project.id,
            marketAnalysisId: null,
            opportunityType:  (raw['opportunity_type'] as String?) ?? 'expansão',
            title:            (raw['title'] as String?) ?? '',
            description:      (raw['description'] as String?) ?? '',
            marketScore:      _toInt(raw['market_score']),
            revenueScore:     _toInt(raw['revenue_score']),
            competitionScore: _toInt(raw['competition_score']),
            synergyScore:     _toInt(raw['synergy_score']),
            strategicFit:     _toInt(raw['strategic_fit']),
            finalScore:       _toInt(raw['final_score']),
            status:           'pending',
            createdAt:        DateTime.now(),
            origin:           'auto_bootstrap',
            sources:          [project.name],
            rationale:        raw['rationale'] as String?,
            confidence:       _toInt(raw['confidence']),
            risks: rawRisks is List
                ? rawRisks.map((e) => e.toString()).toList()
                : const [],
            actionSteps: rawSteps is List
                ? rawSteps.map((e) => e.toString()).toList()
                : const [],
          );
          if (item.title.isEmpty) continue;
          final saved = await _oppSvc.create(item);
          savedOpps.add(saved);
          oppsCreated++;
        }

        // Save roadmap to project.details_json
        final roadmap = oppData['roadmap'];
        if (roadmap is Map<String, dynamic>) {
          final hasItems = [
            ...((roadmap['short_term']  as List?) ?? []),
            ...((roadmap['medium_term'] as List?) ?? []),
            ...((roadmap['long_term']   as List?) ?? []),
          ].isNotEmpty;

          if (hasItems) {
            final currentDetails = Map<String, dynamic>.from(project.detailsJson);
            final updatedDetails = currentDetails..['roadmap'] = roadmap;
            await _client
                .from(AppConstants.tableProjects)
                .update({'details_json': updatedDetails})
                .eq('id', project.id);
            roadmapCreated = true;
          }
        }

        // ── Step 2: Generate actions ────────────────────────────────────
        if (savedOpps.isNotEmpty) {
          onStep?.call('Gerando ações');
          final oppList = savedOpps.take(3).map((o) => {
            'title':       o.title,
            'description': o.description,
          }).toList();

          final actResp = await _client.functions.invoke(
            AppConstants.edgeFunctionGenerateActions,
            body: {
              'project_name':  project.name,
              'opportunities': oppList,
            },
          );

          final actData = actResp.data as Map<String, dynamic>?;
          if (actData != null && !actData.containsKey('error')) {
            final rawActs = (actData['actions'] as List? ?? []);
            for (int i = 0; i < rawActs.length; i++) {
              final a = rawActs[i];
              if (a is! Map<String, dynamic>) continue;
              final oppId = i < savedOpps.length ? savedOpps[i].id : savedOpps.first.id;
              final item = ActionQueueItem(
                id:             '',
                userId:         uid,
                projectId:      project.id,
                opportunityLabId: oppId,
                actionType:     (a['action_type'] as String?) ?? 'tarefa',
                title:          (a['title'] as String?) ?? '',
                priority:       _toInt(a['priority']),
                impactScore:    _toInt(a['impact_score']),
                effortScore:    _toInt(a['effort_score']),
                roiScore:       _toInt(a['roi_score']),
                status:         'pending',
                createdAt:      DateTime.now(),
              );
              if (item.title.isEmpty) continue;
              await _actSvc.create(item);
              actionsCreated++;
            }
          }
        }
      }

      // ── Step 3: Revenue plan ──────────────────────────────────────────
      onStep?.call('Gerando plano de receita');
      try {
        final docContext = knowledgeItems.take(3).map((k) => k.title).join(', ');
        final revenueInput =
            '${project.name}: ${project.description ?? ""}. Documentos: $docContext.';

        final revResp = await _client.functions.invoke(
          AppConstants.edgeFunctionRevenue,
          body: {
            'input':        revenueInput,
            'project_name': project.name,
          },
        );

        final revData = revResp.data as Map<String, dynamic>?;
        if (revData != null && !revData.containsKey('error')) {
          await _client.from(AppConstants.tableRevenuePlans).insert({
            'user_id':              uid,
            'project_name':         project.name,
            'market_analysis_id':   null,
            'monthly_conservative': _toDouble(revData['monthly_conservative']),
            'monthly_moderate':     _toDouble(revData['monthly_moderate']),
            'monthly_aggressive':   _toDouble(revData['monthly_aggressive']),
            'annual_conservative':  _toDouble(revData['annual_conservative']),
            'annual_moderate':      _toDouble(revData['annual_moderate']),
            'annual_aggressive':    _toDouble(revData['annual_aggressive']),
            'plan_json':            revData,
          });
          revenuePlanCreated = true;
        }
      } catch (_) {
        // Non-fatal — revenue plan failure doesn't block bootstrap
      }

      // ── Step 4: Train untrained personas ─────────────────────────────
      onStep?.call('Treinando personas');
      final trainedIds   = existingTrainings.map((t) => t.personaId).toSet();
      final untrained    = personas.where((p) => !trainedIds.contains(p.id)).toList();
      final withAnalysis = analyses.isNotEmpty;

      if (untrained.isNotEmpty && withAnalysis && knowledgeItems.isNotEmpty) {
        // Find the best analysis (highest opportunity score)
        final bestAnalysis = analyses.reduce(
            (a, b) => a.scoreOpportunity >= b.scoreOpportunity ? a : b);
        // Find the matching knowledge item
        final matchedItems = knowledgeItems
            .where((k) => k.id == bestAnalysis.knowledgeItemId)
            .toList();
        final item = matchedItems.isNotEmpty ? matchedItems.first : knowledgeItems.first;

        for (final persona in untrained.take(4)) {
          try {
            await _trainSvc.trainFromAnalysis(
              personaId: persona.id,
              item:      item,
              analysis:  bestAnalysis,
            );
            personasTrained++;
          } catch (_) {
            // Non-fatal
          }
        }
      }

      return BootstrapProjectResult(
        projectId:           project.id,
        projectName:         project.name,
        success:             true,
        opportunitiesCreated: oppsCreated,
        actionsCreated:      actionsCreated,
        revenuePlanCreated:  revenuePlanCreated,
        roadmapCreated:      roadmapCreated,
        personasTrained:     personasTrained,
      );
    } catch (e) {
      return BootstrapProjectResult(
        projectId:   project.id,
        projectName: project.name,
        success:     false,
        error:       e.toString(),
      );
    }
  }

  // ── Fetch data needed for bootstrap ────────────────────────────────────

  Future<List<KnowledgeAnalysis>> fetchAnalysesWithTraining() async {
    final rows = await _client
        .from(AppConstants.tableKnowledgeAnalysis)
        .select()
        .not('persona_training', 'is', null)
        .order('score_opportunity', ascending: false)
        .limit(20);
    return rows.map((r) => KnowledgeAnalysis.fromMap(r)).toList();
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v.clamp(0, 100);
    if (v is double) return v.round().clamp(0, 100);
    return int.tryParse(v.toString()) ?? 0;
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
