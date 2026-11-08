import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/ecosystem_labels.dart';
import '../../../core/utils/language_utils.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../data/models/copilot_context_data.dart';
import '../../../data/models/ive_interaction_request.dart';
import '../../../data/models/ecosystem_score.dart';
import '../../../data/models/knowledge_coverage.dart';
import '../../../data/models/opportunity_lab_item.dart';
import '../../../data/models/project.dart';
import '../../../data/models/project_intelligence_profile.dart';
import '../../../data/models/project_resource_allocation.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auto_bootstrap_provider.dart';
import '../../../providers/ecosystem_intelligence_provider.dart';
import '../../../providers/ive_context_provider.dart';
import '../../../providers/knowledge_provider.dart';
import '../../../providers/opportunity_lab_provider.dart';
import '../../../providers/project_intelligence_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/project_resource_allocation_provider.dart';
import '../../../shared/widgets/ai_execution_confirmation.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/context_copilot_widget.dart'
    show showCopilotChat;
import '../../../shared/widgets/translated_content_notice.dart';
import 'package:ai_social_copilot/core/theme/app_motion.dart';
import 'package:ai_social_copilot/core/theme/app_tokens.dart';
import 'package:ai_social_copilot/shared/ui/iv_charts.dart';
import 'package:ai_social_copilot/shared/ui/iv_kit.dart';

class ProjectCommandCenterScreen extends ConsumerStatefulWidget {
  const ProjectCommandCenterScreen({super.key});

  @override
  ConsumerState<ProjectCommandCenterScreen> createState() =>
      _ProjectCommandCenterScreenState();
}

class _ProjectCommandCenterScreenState
    extends ConsumerState<ProjectCommandCenterScreen> {
  bool _showForm = false;
  bool _refreshing = false;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  String _type = 'website';
  bool _saving = false;

  // IVE-COMMERCIAL-QUOTA-HARDENING-13 — gates the auto-bootstrap flow
  // (previously an unconditional, silent ive_provider.dart side effect
  // firing up to 3 quota-consuming Edge Function calls per project — see
  // AutoBootstrapService.bootstrapProject) behind one explicit
  // confirmation, right after a successful project creation.
  final _bootstrapExec = AiExecutionController();

  // IVE-COMMERCIAL-QUOTA-HARDENING-13 — gates _analyzeWithKnowledge's own
  // direct generate-project-opportunities call ("Analisar com
  // Conhecimento"), a separate silent quota-consuming path from both the
  // resource-analysis button (already fixed in mission 12) and the
  // auto-bootstrap flow above. A dedicated controller, not reused from
  // _bootstrapExec, so the two independent actions' busy-guards never
  // interfere with each other.
  final _knowledgeAnalysisExec = AiExecutionController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _urlCtrl.dispose();
    _bootstrapExec.dispose();
    _knowledgeAnalysisExec.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    ref.invalidate(projectsNotifierProvider);
    ref.invalidate(ecosystemScoresProvider);
    // Aguarda nova leitura para completar o indicador
    await Future.wait([
      ref.read(projectsNotifierProvider.future).catchError((_) => <Project>[]),
      ref
          .read(ecosystemScoresProvider.future)
          .catchError((_) => <EcosystemScore>[]),
    ]);
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final project = await ref.read(projectsNotifierProvider.notifier).create({
        'name': name,
        'description': _descCtrl.text.trim(),
        'url': _urlCtrl.text.trim().isNotEmpty ? _urlCtrl.text.trim() : null,
        'type': _type,
        'status': 'idea',
      });
      _nameCtrl.clear();
      _descCtrl.clear();
      _urlCtrl.clear();
      setState(() {
        _showForm = false;
        _type = 'website';
      });
      if (mounted) {
        final t = AppLocalizations.of(context)!;
        final pid = project.id;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.projectCommandCreatedSuccess),
            backgroundColor: AppColors.positive,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: t.projectCommandAddSources,
              textColor: AppColors.ink,
              onPressed: () => context.push(
                AppConstants.routeKnowledgeNew,
                extra: {'projectId': pid},
              ),
            ),
          ),
        );
      }
      if (mounted) _maybeOfferAutoBootstrap(project);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(extractErrorMessage(e, AppLocalizations.of(context))),
              backgroundColor: AppColors.negative),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// IVE-COMMERCIAL-QUOTA-HARDENING-13 — the ONLY remaining trigger for
  /// AutoBootstrapService's auto-enrichment flow (previously an
  /// unconditional ive_provider.dart side effect on every project
  /// creation — mission Section 12). `runAll()` bootstraps EVERY project
  /// currently needing it (not just the one just created — it re-detects
  /// from scratch), so the quota estimate shown here is `3 * that count`,
  /// not a hardcoded 3, to never UNDERSTATE the real cost (mission
  /// Section 12's own confirm() doc: "must never understate"). Runs
  /// AFTER `_save()`'s own try/finally completes (not awaited from
  /// there) so the Save button's spinner doesn't linger through this
  /// separate, possibly-multi-call confirmation + bootstrap.
  Future<void> _maybeOfferAutoBootstrap(Project justCreated) async {
    final List<Project> toBootstrap;
    try {
      toBootstrap = await ref.read(projectsNeedingBootstrapProvider.future);
    } catch (_) {
      return; // best-effort — a detection failure must not block anything
    }
    if (toBootstrap.isEmpty || !mounted) return;

    final confirmed = await _bootstrapExec.confirm(
      context: context,
      ref: ref,
      analysisLabel:
          AppLocalizations.of(context)!.projectCommandAutoBootstrapLabel,
      request: IveInteractionRequest(
        projectId: justCreated.id,
        sourceModule: 'project_command_center',
        sourceEntityType: 'project',
        sourceEntityId: justCreated.id,
        operationType: IveOperationType.analyze,
      ),
      estimatedUnits: toBootstrap.length * 3,
    );
    if (!confirmed || !mounted) return;
    ref.read(autoBootstrapNotifierProvider.notifier).runAll();
  }

  Future<void> _confirmDelete(Project project) async {
    final t = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(t.projectCommandDeleteConfirmTitle,
            style: const TextStyle(color: AppColors.ink)),
        content: Text(
          t.projectCommandDeleteConfirmBody(project.name),
          style: const TextStyle(color: AppColors.inkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.commonCancel,
                style: const TextStyle(color: AppColors.inkMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style:
                TextButton.styleFrom(foregroundColor: AppColors.negative),
            child: Text(t.projectCommandDelete),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await ref.read(projectsNotifierProvider.notifier).delete(project.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    t.projectCommandDeleteError(extractErrorMessage(e, t))),
                backgroundColor: AppColors.negative),
          );
        }
      }
    }
  }

  Future<void> _analyzeWithKnowledge(Project project) async {
    final t = AppLocalizations.of(context)!;
    // R16 — AI output language = presentation language (captured before
    // any await so BuildContext is not used across async gaps).
    final language = backendLanguageCode(context);
    Navigator.of(context).pop();

    // Busca knowledge items do projeto
    final items = await ref
        .read(knowledgeServiceProvider)
        .fetchAll(projectId: project.id);

    if (!mounted) return;

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t.projectCommandNoKnowledgeWarning,
          ),
          backgroundColor: AppColors.warning,
          action: SnackBarAction(
            label: t.oppAdd,
            textColor: AppColors.ink,
            onPressed: () => context.push(
              AppConstants.routeKnowledgeNew,
              extra: {'projectId': project.id},
            ),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    // Codex Gate 2 round-2 finding — this request's own idempotencyKey
    // (generated once, right here) MUST be the one actually sent below.
    // The previous version constructed the IveInteractionRequest inline
    // inside the confirm() call, so its key had no reference left to
    // reuse afterward — the network call then minted a completely
    // separate, disposable newUuidV4() of its own. That key was never
    // reused by anything, so this confirmed operation had no real
    // retry-safe idempotency: a retry (network failure, re-tap after
    // error) would mint yet another new key and be charged again.
    final request = IveInteractionRequest(
      projectId: project.id,
      sourceModule: 'project_command_center',
      sourceEntityType: 'project',
      sourceEntityId: project.id,
      operationType: IveOperationType.analyze,
    );
    final confirmed = await _knowledgeAnalysisExec.confirm(
      context: context,
      ref: ref,
      analysisLabel: t.projectCommandAnalyzeWithKnowledgeLabel,
      request: request,
    );
    if (!confirmed || !mounted) return;

    // Mostra progresso
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(t.projectCommandAnalyzingSnackbar(project.name, items.length)),
        backgroundColor: AppColors.accent,
        duration: const Duration(seconds: 30),
      ),
    );

    try {
      final docs = items
          .where((i) => i.content.trim().length >= 20)
          .take(6)
          .map((i) => {
                'title': i.title,
                'content':
                    i.content.substring(0, i.content.length.clamp(0, 400)),
              })
          .toList();

      final response = await Supabase.instance.client.functions.invoke(
        AppConstants.edgeFunctionGenerateOpportunities,
        body: {
          'project_name': project.name,
          'project_description': project.description,
          'project_type': project.type,
          'documents': docs,
          'idempotency_key': request.idempotencyKey,
          'language': language,
        },
      );

      if (response.data == null) throw Exception(t.ctxEmptyServerResponse);
      final data = response.data as Map<String, dynamic>;
      if (data.containsKey('error')) throw Exception(data['error']);

      final opportunities = (data['opportunities'] as List? ?? []);
      final notifier = ref.read(opportunityLabNotifierProvider.notifier);

      for (final opp in opportunities) {
        final item = OpportunityLabItem(
          id: '',
          userId: '',
          projectId: project.id,
          opportunityType: opp['opportunity_type'] as String? ?? 'expansão',
          title: opp['title'] as String? ?? '',
          description: opp['description'] as String? ?? '',
          marketScore: (opp['market_score'] as num?)?.toInt() ?? 0,
          revenueScore: (opp['revenue_score'] as num?)?.toInt() ?? 0,
          competitionScore: (opp['competition_score'] as num?)?.toInt() ?? 0,
          synergyScore: (opp['synergy_score'] as num?)?.toInt() ?? 0,
          strategicFit: (opp['strategic_fit'] as num?)?.toInt() ?? 0,
          finalScore: (opp['final_score'] as num?)?.toInt() ?? 0,
          origin: 'knowledge_engine',
          sources: items.map((i) => i.title).toList(),
          createdAt: DateTime.now(),
        );
        await notifier.add(item);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.projectCommandOpportunitiesGenerated(
              opportunities.length, project.name)),
          backgroundColor: AppColors.positive,
          action: SnackBarAction(
            label: t.projectCommandView,
            textColor: AppColors.ink,
            onPressed: () => context.go(AppConstants.routeOpportunityLab),
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(t.projectCommandAnalyzeError(extractErrorMessage(e, t))),
          backgroundColor: AppColors.negative,
        ),
      );
    }
  }

  void _openDetail(Project project, EcosystemScore? score) {
    final profile = ref
        .read(projectIntelligenceProfilesProvider)
        .valueOrNull
        ?.where((p) => p.project.id == project.id)
        .firstOrNull;

    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _ProjectDetailSheet(
        project: project,
        ecosystemScore: score,
        intelligenceProfile: profile,
        onStatusChange: (s) {
          Navigator.of(context).pop();
          ref
              .read(projectsNotifierProvider.notifier)
              .updateStatus(project.id, s);
        },
        onDelete: () {
          Navigator.of(context).pop();
          _confirmDelete(project);
        },
        onAnalyze: project.marketAnalysisId != null
            ? () {
                Navigator.of(context).pop();
                context.go(AppConstants.routeMarketIntelligenceHub
                    .replaceFirst(':id', project.marketAnalysisId!));
              }
            : null,
        onAnalyzeKnowledge: () => _analyzeWithKnowledge(project),
        onIveAnalysis: () {
          Navigator.of(context).pop();
          context.push(
            AppConstants.routeProjectAnalysis.replaceFirst(':id', project.id),
          );
        },
        onViewKnowledge: () {
          Navigator.of(context).pop();
          context.push(
            AppConstants.routeKnowledge,
            extra: {'projectId': project.id},
          );
        },
        onAnalyzeIdea: () {
          Navigator.of(context).pop();
          context.push(
            AppConstants.routeMarketIntelligence,
            extra: {
              'projectId': project.id,
              'initialInput': project.description.isNotEmpty
                  ? project.description
                  : project.name,
            },
          );
        },
        onOpenConfig: () {
          Navigator.of(context).pop();
          _openConfig(project);
        },
      ),
    ));
  }

  // IVE-COMMERCIAL-EXPERIENCE-14, Phase B Section 08/09 — Project
  // Configuration. Exposes ONLY fields the real, current Project model
  // persists (lib/data/models/project.dart: name, description, type,
  // url, status — verified from source before writing this; opportunity/
  // revenue/complexity/priority scores are AI-computed, not user
  // configuration, and are correctly left out). Reuses
  // ProjectsNotifier.updateFields(), the existing safe update path
  // (Section 09: "If existing service already has safe update semantics:
  // reuse it") — no new persistence logic.
  void _openConfig(Project project) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProjectConfigSheet(project: project),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final asyncProjects = ref.watch(projectsNotifierProvider);
    final asyncScores = ref.watch(ecosystemScoresProvider);

    // Mapa projectId → EcosystemScore para lookup O(1)
    final scoresMap = asyncScores.valueOrNull != null
        ? {for (final s in asyncScores.valueOrNull!) s.project.id: s}
        : <String, EcosystemScore>{};

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(tooltip: MaterialLocalizations.of(context).backButtonTooltip, 
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppConstants.routeHome);
            }
          },
        ),
        backgroundColor: Colors.transparent,
        title: Text(t.projectCommandTitle),
        actions: [
          IconButton(
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: t.projectCommandRefreshTooltip,
            onPressed: _refreshing ? null : _refresh,
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.s2),
            child: AnimatedSwitcher(
              duration: AppMotion.short,
              transitionBuilder: (c, a) =>
                  RotationTransition(turns: Tween(begin: 0.75, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: c)),
              child: IconButton.filledTonal(
                key: ValueKey(_showForm),
                tooltip: _showForm ? t.commonCancel : t.projectCommandNewProject,
                icon: Icon(_showForm ? Icons.close_rounded : Icons.add_rounded),
                onPressed: () => setState(() => _showForm = !_showForm),
              ),
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          AnimatedSize(
            duration: AppMotion.medium,
            curve: AppMotion.emphasized,
            alignment: Alignment.topCenter,
            child: _showForm ? _buildForm() : const SizedBox(width: double.infinity),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppMotion.medium,
              child: asyncProjects.when(
                loading: () => const _ListSkeleton(),
                error: (e, _) => Center(
                    child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s6),
                  child: Text(
                      t.projectCommandLoadError(extractErrorMessage(e, t)),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.negative)),
                )),
                data: (projects) => projects.isEmpty
                    ? _buildEmpty(t)
                    : RefreshIndicator(
                        backgroundColor: AppColors.surface,
                        onRefresh: _refresh,
                        child: _buildProjectList(projects, scoresMap),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(AppLocalizations t) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.s6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: IvStagger(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Center(
                  child: IvIconTile(Icons.rocket_launch_rounded, size: 72),
                ),
                Text(t.projectCommandEmptyTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: AppType.heading,
                        fontWeight: FontWeight.w600)),
                Text(t.projectCommandEmptySubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 14,
                        height: 1.5)),
                IvPrimaryAction(
                  icon: Icons.add_rounded,
                  label: t.projectCommandNewProject,
                  onTap: () => setState(() => _showForm = true),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildForm() {
    final t = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.s4, AppSpace.s2, AppSpace.s4, AppSpace.s2),
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: AppConstants.maxBodyWidth),
          child: IvCard(
            highlight: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IvSectionHeader(
                  title: t.projectCommandNewProject,
                  icon: Icons.add_business_rounded,
                ),
                const SizedBox(height: AppSpace.s4),
                _Field(
                    controller: _nameCtrl,
                    label: t.projectCommandFieldNameLabel,
                    hint: t.projectCommandFieldNameHint),
                const SizedBox(height: AppSpace.s3),
                _Field(
                    controller: _descCtrl,
                    label: t.projectCommandFieldDescLabel,
                    hint: t.projectCommandFieldDescHint),
                const SizedBox(height: AppSpace.s3),
                _Field(
                    controller: _urlCtrl,
                    label: t.projectCommandFieldUrlLabel,
                    hint: t.projectCommandFieldUrlHint),
                const SizedBox(height: AppSpace.s4),
                IvEyebrow(t.projectCommandFieldTypeLabel),
                const SizedBox(height: AppSpace.s2),
                Wrap(
                  spacing: AppSpace.s2,
                  runSpacing: AppSpace.s2,
                  children: ['website', 'app', 'product', 'service', 'content']
                      .map(
                        (type) => ChoiceChip(
                          label: Text(_projectTypeLabel(type, t)),
                          selected: _type == type,
                          showCheckmark: false,
                          avatar: Icon(_projectTypeIcon(type),
                              size: 16,
                              color: _type == type
                                  ? AppColors.accent
                                  : AppColors.inkMuted),
                          onSelected: (_) => setState(() => _type = type),
                          selectedColor: AppColors.accentSoft,
                          labelStyle: TextStyle(
                              color: _type == type
                                  ? AppColors.accent
                                  : AppColors.inkMuted,
                              fontWeight: FontWeight.w500,
                              fontSize: AppType.label),
                          backgroundColor: AppColors.surfaceRaised,
                          side: BorderSide(
                              color: _type == type
                                  ? AppColors.accent.withOpacity(0.5)
                                  : AppColors.line),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: AppSpace.s4),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _showForm = false),
                        child: Text(t.commonCancel),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s3),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    color: AppColors.onAccent,
                                    strokeWidth: 2))
                            : Text(t.commonSave),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProjectList(
    List<Project> projects,
    Map<String, EcosystemScore> scoresMap,
  ) {
    final t = AppLocalizations.of(context)!;
    // Ordena por ecosystemScore quando disponível, fallback para priorityScore
    final sorted = [...projects]..sort((a, b) {
        final sa = scoresMap[a.id]?.ecosystemScore ?? a.priorityScore;
        final sb = scoresMap[b.id]?.ecosystemScore ?? b.priorityScore;
        return sb.compareTo(sa);
      });

    final active = projects
        .where((p) => p.status == 'active' || p.status == 'executing')
        .length;
    final opp = projects
        .map((p) => scoresMap[p.id]?.opportunityScore ?? p.opportunityScore)
        .where((v) => v > 0)
        .toList();
    final avgOpp =
        opp.isEmpty ? 0 : (opp.reduce((a, b) => a + b) / opp.length).round();

    Widget card(Project p, int rank, {bool fill = false}) {
      final score = scoresMap[p.id];
      return _ProjectCard(
        project: p,
        rank: rank,
        fillHeight: fill,
        ecosystemScore: score,
        onTap: () => _openDetail(p, score),
        onStatusChange: (st) =>
            ref.read(projectsNotifierProvider.notifier).updateStatus(p.id, st),
        onDelete: () => _confirmDelete(p),
        onAnalyze: p.marketAnalysisId != null
            ? () => context.go(AppConstants.routeMarketIntelligenceHub
                .replaceFirst(':id', p.marketAnalysisId!))
            : null,
        onIveAnalysis: () => context.push(
          AppConstants.routeProjectAnalysis.replaceFirst(':id', p.id),
        ),
      );
    }

    final kpis = IvGrid(
      minTileWidth: 180,
      maxColumns: 3,
      children: [
        IvStatCard(
          label: t.navProjects,
          value: projects.length,
          icon: Icons.folder_copy_rounded,
          color: AppColors.info,
        ),
        IvStatCard(
          label: t.projectCommandStatusActive,
          value: active,
          icon: Icons.play_circle_outline_rounded,
          color: AppColors.accent,
        ),
        IvStatCard(
          label: t.projectCommandStatOpportunity,
          value: avgOpp,
          valueText: avgOpp > 0 ? null : '—',
          icon: Icons.speed_rounded,
          color: avgOpp > 0 ? ivScoreColor(avgOpp) : AppColors.inkSubtle,
          trailing: avgOpp > 0
              ? IvRingGauge(
                  value: avgOpp.toDouble(),
                  size: 44,
                  stroke: 5,
                  center: const SizedBox.shrink())
              : null,
        ),
      ],
    );

    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final pad = w >= 960 ? AppSpace.s8 : AppSpace.s4;
      final inner = (w - pad * 2).clamp(0.0, 1240.0);
      final cols = inner >= 1080
          ? 3
          : inner >= 680
              ? 2
              : 1;
      final rows = <List<Project>>[];
      for (var i = 0; i < sorted.length; i += cols) {
        rows.add(sorted.sublist(i, (i + cols).clamp(0, sorted.length)));
      }
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(pad, AppSpace.s2, pad, AppSpace.s12),
        itemCount: rows.length + 1,
        itemBuilder: (_, i) {
          final Widget child;
          if (i == 0) {
            child = Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s4),
              child: kpis,
            );
          } else if (cols == 1) {
            child = card(rows[i - 1].first, i);
          } else {
            final row = rows[i - 1];
            child = Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s4),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var k = 0; k < cols; k++) ...[
                      if (k > 0) const SizedBox(width: AppSpace.s4),
                      Expanded(
                        child: k < row.length
                            ? card(row[k], (i - 1) * cols + k + 1, fill: true)
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: FadeSlideIn(index: i, child: child),
            ),
          );
        },
      );
    });
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpace.s4),
      children: const [
        IvSkeleton(height: 84),
        SizedBox(height: AppSpace.s4),
        IvSkeleton(height: 180),
        SizedBox(height: AppSpace.s3),
        IvSkeleton(height: 180),
      ],
    );
  }
}

IconData _projectTypeIcon(String type) {
  switch (type) {
    case 'website':
      return Icons.language_rounded;
    case 'app':
      return Icons.smartphone_rounded;
    case 'product':
      return Icons.inventory_2_rounded;
    case 'service':
      return Icons.handshake_rounded;
    case 'content':
      return Icons.article_rounded;
    default:
      return Icons.category_rounded;
  }
}

/// Icon for an ecosystem verdict (replaces the old emoji glyphs).
IconData _verdictIcon(String recommendation) {
  switch (recommendation) {
    case 'ESCALAR':
      return Icons.bolt_rounded;
    case 'ACELERAR':
      return Icons.rocket_launch_rounded;
    case 'MANTER':
      return Icons.check_circle_rounded;
    case 'VALIDAR':
      return Icons.manage_search_rounded;
    case 'ANÁLISE INCOMPLETA':
      return Icons.query_stats_rounded;
    default:
      return Icons.lightbulb_rounded;
  }
}

// ── Field helper ──────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  const _Field(
      {required this.controller, required this.label, required this.hint});
  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppColors.ink, fontSize: 14),
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}

// ── Project Card ──────────────────────────────────────────────────────────────

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.rank,
    required this.onTap,
    required this.onStatusChange,
    required this.onDelete,
    this.ecosystemScore,
    this.onAnalyze,
    this.onIveAnalysis,
    this.fillHeight = false,
  });

  /// In the grid every card in a row stretches to the tallest one, with
  /// the action bar pinned to the bottom.
  final bool fillHeight;
  final Project project;
  final int rank;
  final EcosystemScore? ecosystemScore;
  final VoidCallback onTap;
  final void Function(String) onStatusChange;
  final VoidCallback onDelete;
  final VoidCallback? onAnalyze;
  final VoidCallback? onIveAnalysis;

  Color get _statusColor {
    switch (project.status) {
      case 'active':
        return AppColors.positive;
      case 'completed':
        return AppColors.info;
      case 'paused':
        return AppColors.warning;
      default:
        return AppColors.inkSubtle;
    }
  }

  String _statusLabel(AppLocalizations t) {
    switch (project.status) {
      case 'active':
        return t.projectCommandStatusActive;
      case 'completed':
        return t.projectCommandStatusCompleted;
      case 'paused':
        return t.projectCommandStatusPaused;
      default:
        return t.projectCommandStatusIdea;
    }
  }

  String _fmtRevenue(double v, AppLocalizations t) {
    if (v <= 0) return t.projectCommandRevenueNotEstimated;
    if (v >= 1000000) return 'R\$ ${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return 'R\$ ${(v / 1000).toStringAsFixed(0)}K';
    return 'R\$ ${v.toStringAsFixed(0)}';
  }

  String _fmtPrazo(int days, AppLocalizations t) {
    if (days <= 0) return '—';
    if (days >= 365) return t.ctxDurationYears((days / 365).round());
    if (days >= 30) return t.ctxDurationMonths((days / 30).round());
    return t.ctxDurationDays(days);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final s = ecosystemScore;
    final oppScore = s?.opportunityScore ?? project.opportunityScore;
    final revenue = s?.totalRoi != null && s!.totalRoi > 0
        ? _fmtRevenue(s.totalRoi, t)
        : _fmtRevenue(project.revenuePotential, t);
    final ecoScore = s?.ecosystemScore;
    final gaugeValue = (ecoScore ?? oppScore).toDouble();

    final body = Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.s4, AppSpace.s4, AppSpace.s4, AppSpace.s3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IvRingGauge(
                        value: gaugeValue,
                        size: 52,
                        stroke: 5,
                        semanticsLabel: '${gaugeValue.round()} / 100',
                      ),
                      const SizedBox(width: AppSpace.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('#$rank',
                                    style: const TextStyle(
                                        color: AppColors.inkSubtle,
                                        fontSize: AppType.caption,
                                        fontWeight: FontWeight.w600,
                                        fontFeatures: AppType.tabular)),
                                const SizedBox(width: AppSpace.s2),
                                IvBadge(_statusLabel(t), color: _statusColor),
                              ],
                            ),
                            const SizedBox(height: AppSpace.s1),
                            Text(project.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    letterSpacing: -0.1)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (project.presentedDescription.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.s3),
                    Text(project.presentedDescription,
                        style: const TextStyle(
                            color: AppColors.inkMuted,
                            fontSize: AppType.label,
                            height: 1.45),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                  // Recomendação da IA quando disponível
                  if (s != null && s.recommendation.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.s3),
                    IvBadge(
                      ecosystemVerdictLabel(s.recommendation, t),
                      color: AppColors.accent,
                      icon: _verdictIcon(s.recommendation),
                    ),
                  ],
                  const SizedBox(height: AppSpace.s4),
                  Row(
                    children: [
                      _StatChip(
                          label: t.projectCommandStatOpportunity,
                          value: '$oppScore',
                          color: ivScoreColor(oppScore)),
                      const SizedBox(width: AppSpace.s2),
                      _StatChip(
                          label: t.projectCommandStatPotential,
                          value: revenue,
                          color: AppColors.gold),
                      const SizedBox(width: AppSpace.s2),
                      _StatChip(
                          label: t.projectCommandStatDeadline,
                          value: _fmtPrazo(project.timeToRevenueDays, t),
                          color: AppColors.info),
                    ],
                  ),
                ],
              ),
            );

    return Padding(
      padding: EdgeInsets.only(bottom: fillHeight ? 0 : AppSpace.s3),
      child: IvCard(
        onTap: onTap,
        accent: _statusColor,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (fillHeight) Expanded(child: body) else body,
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s2, vertical: AppSpace.s1),
              child: Row(
                children: [
                  _ActionBtn(
                    icon: Icons.open_in_full_rounded,
                    label: t.projectCommandActionDetail,
                    color: AppColors.inkMuted,
                    onTap: onTap,
                  ),
                  if (onAnalyze != null)
                    _ActionBtn(
                        icon: Icons.analytics_rounded,
                        label: t.projectCommandActionAnalysis,
                        color: AppColors.info,
                        onTap: onAnalyze!),
                  if (onIveAnalysis != null)
                    _ActionBtn(
                        icon: Icons.psychology_rounded,
                        label: 'IVE',
                        color: AppColors.accent,
                        onTap: onIveAnalysis!),
                  _ActionBtn(
                    icon: Icons.play_arrow_rounded,
                    label: t.projectCommandActionActivate,
                    color: AppColors.positive,
                    onTap: () => onStatusChange('active'),
                  ),
                  _ActionBtn(
                    icon: Icons.delete_outline_rounded,
                    label: t.projectCommandDelete,
                    color: AppColors.negative,
                    onTap: onDelete,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}

// ── Project Detail Bottom Sheet ───────────────────────────────────────────────

class _ProjectDetailSheet extends ConsumerWidget {
  const _ProjectDetailSheet({
    required this.project,
    required this.onStatusChange,
    required this.onDelete,
    this.ecosystemScore,
    this.intelligenceProfile,
    this.onAnalyze,
    this.onAnalyzeKnowledge,
    this.onViewKnowledge,
    this.onIveAnalysis,
    required this.onAnalyzeIdea,
    required this.onOpenConfig,
  });

  final Project project;
  final EcosystemScore? ecosystemScore;
  final ProjectIntelligenceProfile? intelligenceProfile;
  final void Function(String) onStatusChange;
  final VoidCallback onDelete;
  final VoidCallback? onAnalyze;
  final VoidCallback? onAnalyzeKnowledge;
  final VoidCallback? onViewKnowledge;
  final VoidCallback? onIveAnalysis;

  /// IVE-COMMERCIAL-EXPERIENCE-14, Phase B Section 07 — opens Market
  /// Intelligence pre-bound to this project (the "Idea Analysis" entry
  /// point). Always available, unlike [onAnalyze] (which only shows an
  /// EXISTING linked analysis) — this always lets the user run a NEW one.
  final VoidCallback onAnalyzeIdea;

  /// IVE-COMMERCIAL-EXPERIENCE-14, Phase B Section 08 — opens the Project
  /// Configuration sheet for this project.
  final VoidCallback onOpenConfig;

  String _fmtRevenue(double v, AppLocalizations t) {
    if (v <= 0) return t.projectCommandRevenueNotEstimatedYet;
    if (v >= 1000000) return 'R\$ ${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return 'R\$ ${(v / 1000).toStringAsFixed(0)}K';
    return 'R\$ ${v.toStringAsFixed(0)}';
  }

  /// Data often arrives with its line breaks stripped ("residualEm um
  /// único"); restore a break where a sentence visibly runs into the next.
  static String _readable(String text) {
    if (text.contains('\n') || text.length < 240) return text;
    return text.replaceAllMapped(
        RegExp(r'([a-zà-ú0-9\.\)])([A-ZÀ-Ú][a-zà-ú])'),
        (m) => '${m.group(1)}\n${m.group(2)}');
  }

  Widget _panel({required String title, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s4),
      child: IvCard(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IvEyebrow(title),
            const SizedBox(height: AppSpace.s3),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ecosystemScore;
    final t = AppLocalizations.of(context)!;
    final eco = s?.ecosystemScore ?? project.opportunityScore;

    // ── Header (full width) ────────────────────────────────────────────────
    final header = IvCard(
      highlight: true,
      padding: const EdgeInsets.all(AppSpace.s6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IvRingGauge(
            value: eco.toDouble(),
            size: 76,
            stroke: 7,
            semanticsLabel: '${t.projectCommandEcoScoreLabel}: $eco / 100',
          ),
          const SizedBox(width: AppSpace.s6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IvEyebrow(t.projectCommandEcoScoreLabel),
                const SizedBox(height: AppSpace.s1),
                Text(project.name,
                    style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 24,
                        letterSpacing: -0.3,
                        height: 1.2)),
                const SizedBox(height: AppSpace.s2),
                Wrap(
                  spacing: AppSpace.s2,
                  runSpacing: AppSpace.s2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (s != null && s.recommendation.isNotEmpty)
                      IvBadge(ecosystemVerdictLabel(s.recommendation, t),
                          color: AppColors.accent,
                          icon: _verdictIcon(s.recommendation)),
                    if (project.url != null)
                      Text(project.url!,
                          style: const TextStyle(
                              color: AppColors.accent, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          if (MediaQuery.sizeOf(context).width >= 1100) ...[
            const SizedBox(width: AppSpace.s6),
            SizedBox(
              width: 420,
              child: Row(children: [
                Expanded(
                    child: _MetricTile(
                        label: t.projectCommandStatOpportunity,
                        value: '${s?.opportunityScore ?? project.opportunityScore}',
                        color: AppColors.info)),
                const SizedBox(width: AppSpace.s2),
                Expanded(
                    child: _MetricTile(
                        label: t.projectCommandStatPotential,
                        value: _fmtRevenue(
                            s?.totalRoi ?? project.revenuePotential, t),
                        color: AppColors.positive)),
                const SizedBox(width: AppSpace.s2),
                Expanded(
                    child: _MetricTile(
                        label: t.projectCommandMetricComplexity,
                        value: '${project.complexityScore}',
                        color: AppColors.warning)),
              ]),
            ),
          ],
        ],
      ),
    );

    // ── Main column: what the project is and what the analysis says ───────
    final main = <Widget>[
      if (project.presentedDescription.isNotEmpty)
        _panel(title: t.projectCommandFieldDescLabel, children: [
          TranslatedContentNotice(localizedFrom: project.localizedFrom),
          _CollapsibleText(_readable(project.presentedDescription)),
        ]),
      _briefingSection(context, ref),
      if (s != null && (s.strengths.isNotEmpty || s.risks.isNotEmpty))
        LayoutBuilder(builder: (context, c) {
          final strengths = _panel(
              title: t.projectCommandSectionStrengths,
              children: _bullets(s.strengths, AppColors.positive, '✓ '));
          final risks = _panel(
              title: t.opportunityDetailRisksTitle,
              children: _bullets(s.risks, AppColors.negative, '• '));
          if (c.maxWidth < 560 || s.strengths.isEmpty || s.risks.isEmpty) {
            return Column(children: [
              if (s.strengths.isNotEmpty) strengths,
              if (s.risks.isNotEmpty) risks,
            ]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: strengths),
              const SizedBox(width: AppSpace.s4),
              Expanded(child: risks),
            ],
          );
        }),
      if (s != null && s.quickWins.isNotEmpty)
        _panel(
            title: t.projectCommandSectionQuickWins,
            children: _bullets(s.quickWins, AppColors.warning, '• ')),
      if (project.nextActions.isNotEmpty)
        _panel(
            title: t.projectCommandSectionNextActions,
            children: _bullets(project.nextActions, AppColors.accent, '→ ')),
      if (intelligenceProfile != null)
        _panel(
            title: t.projectCommandSectionIntelligenceProfile,
            children: [_intelligenceSection(context, ref, intelligenceProfile!)]),
    ];

    // ── Side column: scores, resources and every action ───────────────────
    final side = <Widget>[
      _panel(title: t.projectDetailActionsTitle, children: [
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: _SheetButton(
                    icon: Icons.lightbulb_outline_rounded,
                    label: t.projectAnalyzeIdea,
                    color: AppColors.info,
                    onTap: onAnalyzeIdea,
                  ),
                ),
                if (onAnalyze != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SheetButton(
                      icon: Icons.analytics_rounded,
                      label: t.projectCommandViewMarketAnalysis,
                      color: AppColors.info,
                      onTap: onAnalyze!,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (onViewKnowledge != null)
                  Expanded(
                    child: _SheetButton(
                      icon: Icons.menu_book_rounded,
                      label: t.projectCommandViewKnowledge,
                      color: AppColors.info,
                      onTap: onViewKnowledge!,
                    ),
                  ),
                if (onViewKnowledge != null && onAnalyzeKnowledge != null)
                  const SizedBox(width: 8),
                if (onAnalyzeKnowledge != null)
                  Expanded(
                    child: _SheetButton(
                      icon: Icons.psychology_rounded,
                      label: t.projectCommandAnalyzeWithAi,
                      color: AppColors.accent,
                      onTap: onAnalyzeKnowledge!,
                    ),
                  ),
              ],
            ),
            if (onIveAnalysis != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _SheetButton(
                      icon: Icons.auto_awesome_rounded,
                      label: t.insightTitle,
                      color: AppColors.accent,
                      onTap: onIveAnalysis!,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _SheetButton(
                    icon: Icons.play_arrow_rounded,
                    label: t.projectCommandActionActivate,
                    color: AppColors.positive,
                    onTap: () => onStatusChange('active'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SheetButton(
                    icon: Icons.pause_rounded,
                    label: t.projectCommandActionPause,
                    color: AppColors.warning,
                    onTap: () => onStatusChange('paused'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SheetButton(
                    icon: Icons.check_circle_outline_rounded,
                    label: t.projectCommandActionComplete,
                    color: AppColors.info,
                    onTap: () => onStatusChange('completed'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _SheetButton(
                    icon: Icons.settings_outlined,
                    label: t.projectOpenConfig,
                    color: AppColors.inkMuted,
                    onTap: onOpenConfig,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SheetButton(
                    icon: Icons.delete_outline_rounded,
                    label: t.projectCommandDeleteProject,
                    color: AppColors.negative,
                    onTap: onDelete,
                  ),
                ),
              ],
            ),
      ]),
      if (s != null)
        _panel(title: t.projectCommandSectionEcosystemScores, children: [
          _ScoreRow(t.projectCommandStatOpportunity, s.opportunityScore),
          _ScoreRow(t.projectCommandScoreStrategicFit, s.strategicFit),
          _ScoreRow(t.projectCommandScoreSynergy, s.synergyScore),
          _ScoreRow(t.projectCommandScoreRoi, s.roiScore),
          _ScoreRow(t.projectCommandScoreMomentum, s.momentumScore),
          _ScoreRow(t.opportunityDetailScoreMarket, s.marketScore),
          _ScoreRow(t.projectCommandScoreExecution, s.executionScore),
          const SizedBox(height: AppSpace.s2),
          Text(
            t.projectCommandActionsStats(
                s.completedActions, s.actionCount, s.completionRate),
            style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
          ),
          const SizedBox(height: AppSpace.s1),
          Text(
            t.projectCommandTotalRoi(_fmtRevenue(s.totalRoi, t)),
            style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
          ),
        ])
      else
        _panel(title: t.projectCommandSectionProjectMetrics, children: [
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                    label: t.projectCommandStatOpportunity,
                    value: '${project.opportunityScore}',
                    color: AppColors.info),
              ),
              const SizedBox(width: AppSpace.s2),
              Expanded(
                child: _MetricTile(
                    label: t.projectCommandMetricComplexity,
                    value: '${project.complexityScore}',
                    color: AppColors.warning),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s2),
          _MetricTile(
              label: t.projectCommandStatPotential,
              value: _fmtRevenue(project.revenuePotential, t),
              color: AppColors.positive),
        ]),
      _panel(title: t.projectCommandSectionResourceAllocation, children: [
        _ResourceAllocationSection(
          projectId: project.id,
          projectName: project.name,
        ),
      ]),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(project.name, overflow: TextOverflow.ellipsis),
      ),
      body: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 960;
        final pad = wide ? AppSpace.s8 : AppSpace.s4;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pad, AppSpace.s2, pad, AppSpace.s12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeSlideIn(child: header),
                  const SizedBox(height: AppSpace.s4),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: FadeSlideIn(
                            index: 1,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: main),
                          ),
                        ),
                        const SizedBox(width: AppSpace.s6),
                        SizedBox(
                          width: 400,
                          child: FadeSlideIn(
                            index: 2,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: side),
                          ),
                        ),
                      ],
                    )
                  else
                    FadeSlideIn(
                      index: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [...side.take(1), ...main, ...side.skip(1)],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _intelligenceSection(
      BuildContext context, WidgetRef ref, ProjectIntelligenceProfile p) {
    final t = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Maturity card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.07),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border:
                Border.all(color: AppColors.accent.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              IvEmojiIcon(p.maturityEmoji, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.projectCommandMaturityLabel(p.maturityLabel(t)),
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (p.dataWarning(t) != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          p.dataWarning(t)!,
                          style: const TextStyle(
                              color: AppColors.warning, fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Identity: niche, audience, monetization
        if (p.hasNiche) ...[
          _infoRow('${t.projectCommandNiche}', p.niche),
        ],
        if (p.hasTargetAudience) ...[
          _infoRow('${t.projectCommandAudience}', p.targetAudience),
        ],
        if (p.hasMonetizationModel) ...[
          _infoRow('${t.projectCommandMonetization}', p.monetizationModel),
        ],
        if (p.valueProposition.isNotEmpty) ...[
          _infoRow('${t.projectCommandValueProposition}', p.valueProposition),
        ],

        // Identified topics
        if (p.identifiedTopics.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(t.projectCommandIdentifiedTopics,
              style: const TextStyle(
                  color: AppColors.inkSubtle,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: p.identifiedTopics
                .map((t) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                            color: AppColors.info.withOpacity(0.3)),
                      ),
                      child: Text(t,
                          style: const TextStyle(
                              color: AppColors.info, fontSize: 11)),
                    ))
                .toList(),
          ),
        ],

        // Missing knowledge gaps
        if (p.missingKnowledge.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(t.projectCommandKnowledgeGaps,
              style: const TextStyle(
                  color: AppColors.inkSubtle,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          ...p.missingKnowledge.take(3).map((gap) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 0, right: 4),
                      child: Icon(Icons.warning_amber_rounded,
                          size: 13, color: AppColors.warning),
                    ),
                    Expanded(
                        child: Text(KnowledgeCoverage.gapLabel(gap, t),
                            style: const TextStyle(
                                color: AppColors.inkMuted, fontSize: 11))),
                  ],
                ),
              )),
        ],

        // Related projects
        if (p.relatedProjectNames.isNotEmpty) ...[
          const SizedBox(height: 8),
          _infoRow('${t.projectCommandRelatedProjects}',
              p.relatedProjectNames.take(3).join(', ')),
        ],

        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent),
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            icon: const Icon(Icons.psychology_rounded, size: 16),
            label: Text(t.projectCommandAskIveAboutProfile,
                style: const TextStyle(fontSize: 13)),
            onPressed: () {
              Navigator.of(context).pop();
              // IVE-COMMERCIAL-FOUNDATION-11: este é o Project Command
              // Center de UM projeto específico (p.project.id) — antes,
              // "Perguntar à IVE sobre este perfil" ainda assim recebia
              // o grounding do projeto de maior score do sistema todo,
              // não necessariamente ESTE projeto. Esta é a referência de
              // implementação do Project Context Contract (docs/
              // commercial/PROJECT_CONTEXT_CONTRACT.md §6).
              final ctx =
                  ref.read(iveContextDataProvider(p.project.id)).valueOrNull;
              final contextData = ctx != null
                  ? CopilotContextData.fromIveContext(ctx)
                  : const CopilotContextData();
              showCopilotChat(
                context,
                screenName: 'Projetos',
                contextData: contextData,
                initialMessage: t.projectCommandAskProfilePrompt(
                  p.project.name,
                  ProjectIntelligenceProfile.displayOrNotDefined(p.niche, t),
                  ProjectIntelligenceProfile.displayOrNotDefined(
                      p.targetAudience, t),
                  p.maturityLabel(t),
                  p.missingKnowledge.isNotEmpty
                      ? t.projectCommandAskProfileGaps(p.missingKnowledge
                          .map((g) => KnowledgeCoverage.gapLabel(g, t))
                          .join(', '))
                      : '',
                ),
                request: IveInteractionRequest(
                  projectId: p.project.id,
                  sourceModule: 'project_command_center',
                  sourceEntityType: 'project',
                  sourceEntityId: p.project.id,
                  operationType: IveOperationType.ask,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(label,
                  style: const TextStyle(color: AppColors.inkSubtle, fontSize: 11)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(color: AppColors.inkMuted, fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );

  Widget _briefingSection(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final briefingAsync = ref.watch(projectBriefingProvider(project.id));
    final knowledgeAsync =
        ref.watch(knowledgeItemsByProjectProvider(project.id));
    final knowledgeCount = knowledgeAsync.valueOrNull?.length;

    return briefingAsync.when(
      // Loading/error must never block the rest of the sheet — the
      // briefing is a convenience summary, not the source of truth for
      // anything below it.
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          height: 16,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (briefing) {
        // whatChanged/whatGrew/whatDeclined are already project-filtered
        // by projectBriefingProvider — no further scoping needed here.
        final recent = [
          ...briefing.whatChanged,
          ...briefing.whatGrew,
          ...briefing.whatDeclined
        ].take(3).toList();
        return _panel(
          title: t.projectBriefingSectionTitle,
          children: [
            SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (briefing.executiveSummary.isNotEmpty)
                    Text(briefing.executiveSummary,
                        style: const TextStyle(
                            color: AppColors.inkMuted, fontSize: 14, height: 1.5)),
                  if (knowledgeCount != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.menu_book_rounded,
                            size: 13, color: AppColors.inkSubtle),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            t.projectBriefingKnowledgeCount(knowledgeCount),
                            style: const TextStyle(
                                color: AppColors.inkMuted, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (recent.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(t.projectBriefingRecentChanges,
                        style: const TextStyle(
                            color: AppColors.inkSubtle,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    ...recent.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text('• ${item.title}',
                              style: const TextStyle(
                                  color: AppColors.inkMuted, fontSize: 11)),
                        )),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _bullets(List<String> items, Color color, String prefix) => items
      .map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(prefix, style: TextStyle(color: color, fontSize: 12)),
                Expanded(
                    child: Text(item,
                        style: const TextStyle(
                            color: AppColors.inkMuted, fontSize: 12))),
              ],
            ),
          ))
      .toList();
}

// ── Resource Allocation section (persistent, SAVED vs EDIT/PREVIEW) ─────────
//
// IVE-COMMERCIAL-EXPERIENCE-12, Phase B, mission Sections 09-15:
//   - Edits only ever touch `preview` (never implicit-save on keystroke).
//   - The SAVED banner always shows the last value actually persisted,
//     visually distinct from the edit fields below it.
//   - "Analisar recursos com a IVE" reuses the existing chat pipeline
//     (showCopilotChat) and explains the CURRENT SAVED allocation only —
//     it does not consume quota and does not describe unsaved preview
//     edits as if they were committed (Section 15).
class _ResourceAllocationSection extends ConsumerStatefulWidget {
  const _ResourceAllocationSection({
    required this.projectId,
    required this.projectName,
  });

  final String projectId;
  final String projectName;

  @override
  ConsumerState<_ResourceAllocationSection> createState() =>
      _ResourceAllocationSectionState();
}

class _ResourceAllocationSectionState
    extends ConsumerState<_ResourceAllocationSection> {
  final _hoursController = TextEditingController();
  final _budgetController = TextEditingController();
  bool _controllersInitialized = false;
  String? _budgetParseError;

  // Codex Gate 1 (mission 12, Phase B) P1 — this section's own comment
  // used to (incorrectly) claim "Analisar recursos com a IVE" doesn't
  // consume quota. It does: showCopilotChat's auto-sent initialMessage
  // goes through supabase/functions/context-copilot, which calls
  // reserveQuota() before every message like every other IVE chat entry
  // point in the app. Mission 12 gated this button locally with its own
  // AiExecutionController; mission 13 (Codex Gate 1, Section 13: "no
  // double confirmation") moved that gate into
  // context_copilot_widget.dart's `_CopilotSheet` itself — the single
  // choke point for EVERY auto-sending showCopilotChat call, not just
  // this one — so a local controller here would now show a SECOND
  // redundant confirmation dialog. Removed.

  static const List<int> _hourPresets = [10, 20, 40, 80];

  @override
  void dispose() {
    _hoursController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _syncControllers(ProjectResourceAllocation preview) {
    _hoursController.text = preview.hoursAllocated.toString();
    _budgetController.text = preview.budgetAllocatedDisplay.toStringAsFixed(2);
    _budgetParseError = null;
  }

  void _onBudgetChanged(String text, ProjectResourceAllocationNotifier notifier,
      AppLocalizations t) {
    final cents = parseMoneyInputToCents(text);
    if (cents == null) {
      setState(() => _budgetParseError = t.projectCommandInvalidBudgetValue);
      return;
    }
    if (_budgetParseError != null) setState(() => _budgetParseError = null);
    notifier.updateBudgetPreviewCents(cents);
  }

  // Stored amounts are BRL (R\$ kept); only the decimal separator follows
  // the presentation language (R16).
  String _fmtCents(int cents) {
    final isPt = Localizations.localeOf(context).languageCode != 'en';
    final v = (cents / 100).toStringAsFixed(2);
    return 'R\$ ${isPt ? v.replaceAll('.', ',') : v}';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final provider = projectResourceAllocationProvider(widget.projectId);
    final asyncState = ref.watch(provider);
    final notifier = ref.read(provider.notifier);

    ref.listen(provider, (previous, next) {
      final nextValue = next.valueOrNull;
      if (nextValue == null) return;
      if (nextValue.status == AllocationEditStatus.saved) {
        _syncControllers(nextValue.preview);
      }
    });

    return asyncState.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Text(
        t.projectCommandResourceLoadError,
        style: const TextStyle(color: AppColors.inkSubtle, fontSize: 12),
      ),
      data: (editState) {
        if (!_controllersInitialized) {
          _syncControllers(editState.preview);
          _controllersInitialized = true;
        }

        final hoursError =
            validateHoursAllocated(editState.preview.hoursAllocated, t);
        final budgetError = _budgetParseError ??
            validateBudgetAllocatedCents(
                editState.preview.budgetAllocatedCents, t);
        final canSave = editState.isDirty &&
            hoursError == null &&
            budgetError == null &&
            editState.status != AllocationEditStatus.saving;
        final isSaving = editState.status == AllocationEditStatus.saving;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Estado SALVO — sempre reflete o último valor persistido,
            // nunca o preview em edição (Section 11).
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                    color: AppColors.info.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 14, color: AppColors.info),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t.projectCommandSavedAllocation(
                        editState.saved.hoursAllocated,
                        _fmtCents(editState.saved.budgetAllocatedCents),
                        editState.saved.currency,
                      ),
                      style: const TextStyle(
                          color: AppColors.info, fontSize: 12),
                    ),
                  ),
                  if (editState.isDirty)
                    Text(t.projectCommandEditingBadge,
                        style: const TextStyle(
                            color: AppColors.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5)),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Campos de edição — só afetam o preview local.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _hoursController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.ink, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: t.projectCommandHoursLabel,
                      labelStyle:
                          const TextStyle(color: AppColors.inkSubtle, fontSize: 12),
                      errorText: hoursError,
                      isDense: true,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: const BorderSide(color: AppColors.inkSubtle),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: const BorderSide(color: AppColors.accent),
                      ),
                    ),
                    onChanged: (text) {
                      final parsed = int.tryParse(text.trim());
                      if (parsed != null) notifier.updateHoursPreview(parsed);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _budgetController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AppColors.ink, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: t.projectCommandBudgetLabel(
                          editState.preview.currency),
                      labelStyle:
                          const TextStyle(color: AppColors.inkSubtle, fontSize: 12),
                      errorText: budgetError,
                      isDense: true,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: const BorderSide(color: AppColors.inkSubtle),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: const BorderSide(color: AppColors.accent),
                      ),
                    ),
                    onChanged: (text) => _onBudgetChanged(text, notifier, t),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Presets opcionais de horas (Section 11: "manual input +
            // optional presets").
            Wrap(
              spacing: 6,
              children: _hourPresets
                  .map((h) => ActionChip(
                        label:
                            Text('${h}h', style: const TextStyle(fontSize: 11)),
                        backgroundColor:
                            AppColors.accent.withOpacity(0.12),
                        labelStyle: const TextStyle(color: AppColors.accent),
                        side: BorderSide.none,
                        onPressed: () {
                          notifier.updateHoursPreview(h);
                          _hoursController.text = h.toString();
                        },
                      ))
                  .toList(),
            ),
            const SizedBox(height: 10),

            // Ciclo explícito: SAVED → EDITING/PREVIEW → SAVE → SAVING →
            // SAVED/ERROR (Section 12). Cancelar restaura o valor salvo
            // exatamente; nunca há salvamento implícito.
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: editState.isDirty && !isSaving
                        ? () {
                            notifier.cancel();
                          }
                        : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.inkMuted,
                      side: const BorderSide(color: AppColors.inkSubtle),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Text(t.commonCancel,
                        style: const TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: canSave ? () => notifier.save() : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      disabledBackgroundColor:
                          AppColors.accent.withOpacity(0.25),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.ink),
                          )
                        : Text(t.commonSave,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.ink)),
                  ),
                ),
              ],
            ),
            if (editState.status == AllocationEditStatus.error &&
                editState.error != null) ...[
              const SizedBox(height: 6),
              Text(
                  t.projectCommandSaveAllocationError(
                      extractErrorMessage(editState.error, t)),
                  style:
                      const TextStyle(color: AppColors.negative, fontSize: 11)),
            ],
            const SizedBox(height: 10),

            // IVE Resource Analysis — explica o estado SALVO atual.
            // Reaproveita o chat existente (showCopilotChat), que NÃO é
            // gratuito: seu envio automático consome 1 unidade de quota
            // via context-copilot, como qualquer outro "Perguntar à IVE"
            // do app. IVE-COMMERCIAL-QUOTA-HARDENING-13 — a confirmação
            // NÃO é mais feita aqui: context_copilot_widget.dart's
            // `_CopilotSheet` agora é o único ponto de confirmação para
            // TODO envio automático de mensagem (mission 13, Seção 13:
            // "no double confirmation" — confirmar aqui E dentro do
            // sheet mostraria dois diálogos em sequência para a mesma
            // ação). O botão só monta o request e abre o chat; o sheet
            // decide se precisa confirmar.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.info,
                  side: const BorderSide(color: AppColors.info),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                icon: const Icon(Icons.psychology_rounded, size: 16),
                label: Text(t.projectCommandAnalyzeResourcesWithIve,
                    style: const TextStyle(fontSize: 13)),
                onPressed: () {
                  final request = IveInteractionRequest(
                    projectId: widget.projectId,
                    sourceModule: 'project_command_center',
                    sourceEntityType: 'project',
                    sourceEntityId: widget.projectId,
                    operationType: IveOperationType.ask,
                  );
                  final saved = editState.saved;
                  final ctx = ref
                      .read(iveContextDataProvider(widget.projectId))
                      .valueOrNull;
                  final contextData = ctx != null
                      ? CopilotContextData.fromIveContext(ctx)
                      : const CopilotContextData();
                  final dirtyNote = editState.isDirty
                      ? t.projectCommandAskAllocationDirtyNote
                      : '';
                  Navigator.of(context).pop();
                  showCopilotChat(
                    context,
                    screenName: 'Projetos',
                    contextData: contextData,
                    initialMessage: t.projectCommandAskAllocationPrompt(
                      widget.projectName,
                      saved.hoursAllocated,
                      '${_fmtCents(saved.budgetAllocatedCents)} ${saved.currency}',
                      dirtyNote,
                    ),
                    request: request,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Project Configuration sheet ──────────────────────────────────────────────
// IVE-COMMERCIAL-EXPERIENCE-14, Phase B Section 08/09. Explicit
// EDIT → SAVE/CANCEL semantics (fields start read-only; tapping "Editar"
// unlocks them; "Cancelar" discards local edits and re-locks; "Salvar"
// persists via ProjectsNotifier.updateFields() and re-locks on success).
// Only real, currently-persisted Project fields are exposed — see the
// verification comment on _openConfig() above.
class _ProjectConfigSheet extends ConsumerStatefulWidget {
  const _ProjectConfigSheet({required this.project});
  final Project project;

  @override
  ConsumerState<_ProjectConfigSheet> createState() =>
      _ProjectConfigSheetState();
}

class _ProjectConfigSheetState extends ConsumerState<_ProjectConfigSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _urlCtrl;
  late String _type;
  late String _status;

  bool _editing = false;
  bool _saving = false;
  String? _error;

  static const _types = ['website', 'app', 'product', 'service', 'content'];
  static const _statuses = ['idea', 'active', 'paused', 'completed'];

  @override
  void initState() {
    super.initState();
    _resetFromProject();
  }

  void _resetFromProject() {
    _nameCtrl = TextEditingController(text: widget.project.name);
    _descCtrl = TextEditingController(text: widget.project.description);
    _urlCtrl = TextEditingController(text: widget.project.url);
    _type = widget.project.type;
    _status = widget.project.status;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  void _startEdit() => setState(() => _editing = true);

  void _cancelEdit() {
    setState(() {
      _nameCtrl.text = widget.project.name;
      _descCtrl.text = widget.project.description;
      _urlCtrl.text = widget.project.url ?? '';
      _type = widget.project.type;
      _status = widget.project.status;
      _editing = false;
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() =>
          _error = AppLocalizations.of(context)!.projectConfigNameRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(projectsNotifierProvider.notifier).updateFields(
        widget.project.id,
        {
          'name': name,
          'description': _descCtrl.text.trim(),
          'type': _type,
          'url': _urlCtrl.text.trim(),
          'status': _status,
        },
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _editing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        final t = AppLocalizations.of(context)!;
        _error = t.projectConfigSaveError(extractErrorMessage(e, t));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface, gradient: kIvSurfaceGradient,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(t.projectConfigTitle,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                ),
                IconButton(tooltip: MaterialLocalizations.of(context).closeButtonTooltip, 
                  icon: const Icon(Icons.close_rounded, color: AppColors.inkMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _configField(
              label: t.projectConfigNameLabel,
              controller: _nameCtrl,
              enabled: _editing,
            ),
            const SizedBox(height: 12),
            _configField(
              label: t.projectConfigDescriptionLabel,
              controller: _descCtrl,
              enabled: _editing,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            _configField(
              label: t.projectConfigUrlLabel,
              controller: _urlCtrl,
              enabled: _editing,
            ),
            const SizedBox(height: 16),
            Text(t.projectConfigTypeLabel,
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _types.map((type) {
                return ChoiceChip(
                  label: Text(_projectTypeLabel(type, t)),
                  selected: _type == type,
                  onSelected:
                      _editing ? (_) => setState(() => _type = type) : null,
                  backgroundColor: AppColors.line,
                  selectedColor: AppColors.accent,
                  labelStyle: TextStyle(
                    color: _type == type ? AppColors.ink : AppColors.inkMuted,
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(t.projectConfigStatusLabel,
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _statuses.map((status) {
                return ChoiceChip(
                  label: Text(_projectStatusLabel(status, t)),
                  selected: _status == status,
                  onSelected:
                      _editing ? (_) => setState(() => _status = status) : null,
                  backgroundColor: AppColors.line,
                  selectedColor: AppColors.accent,
                  labelStyle: TextStyle(
                    color: _status == status ? AppColors.ink : AppColors.inkMuted,
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!,
                  style:
                      const TextStyle(color: AppColors.negative, fontSize: 13)),
            ],
            const SizedBox(height: 24),
            if (!_editing)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(t.projectConfigEdit),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : _cancelEdit,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.inkMuted,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(t.commonCancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.ink),
                            )
                          : Text(t.commonSave),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _configField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          style: const TextStyle(color: AppColors.ink),
          decoration: InputDecoration(
            filled: true,
            fillColor:
                enabled ? AppColors.line : AppColors.surfaceRaised,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }
}

// ── Score row com barra de progresso ─────────────────────────────────────────

class _ScoreRow extends StatelessWidget {
  const _ScoreRow(this.label, this.value);
  final String label;
  final int value;

  Color get _color {
    if (value >= 70) return AppColors.positive;
    if (value >= 40) return AppColors.warning;
    return AppColors.negative;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 132,
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 13)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: LinearProgressIndicator(
                value: value / 100,
                backgroundColor: AppColors.line,
                valueColor: AlwaysStoppedAnimation(_color),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 30,
            child: Text('$value',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: _color, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Metric tile ───────────────────────────────────────────────────────────────

class _MetricTile extends StatelessWidget {
  const _MetricTile(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: AppColors.inkSubtle, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Sheet action button ───────────────────────────────────────────────────────

class _SheetButton extends StatelessWidget {
  const _SheetButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      // OutlinedButton.icon already wraps the label in a Flexible.
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label,
            maxLines: 1, style: TextStyle(color: color, fontSize: 13)),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        side: BorderSide(color: color.withOpacity(0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    );
  }
}

// ── Stat chip (card summary) ──────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s2 + 2, vertical: AppSpace.s2 + 2),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised.withOpacity(0.7),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(label,
                  maxLines: 1,
                  style: const TextStyle(
                      color: AppColors.inkSubtle,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value,
                        maxLines: 1,
                        style: const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            fontFeatures: AppType.tabular)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Action button (card footer) ───────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          hoverColor: color.withOpacity(0.08),
          splashColor: color.withOpacity(0.12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(height: 3),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// R16 — display labels for canonical project type/status codes (the codes
// themselves are stored in the DB and must not change).
String _projectTypeLabel(String type, AppLocalizations t) {
  switch (type) {
    case 'website':
      return t.ctxProjectTypeWebsite;
    case 'app':
      return t.ctxProjectTypeApp;
    case 'product':
      return t.ctxProjectTypeProduct;
    case 'service':
      return t.ctxProjectTypeService;
    case 'content':
      return t.ctxProjectTypeContent;
    default:
      return type;
  }
}

String _projectStatusLabel(String status, AppLocalizations t) {
  switch (status) {
    case 'active':
      return t.projectCommandStatusActive;
    case 'paused':
      return t.projectCommandStatusPaused;
    case 'completed':
      return t.projectCommandStatusCompleted;
    case 'idea':
      return t.projectCommandStatusIdea;
    default:
      return status;
  }
}

// ── Collapsible long text ────────────────────────────────────────────────────

class _CollapsibleText extends StatefulWidget {
  const _CollapsibleText(this.text);
  final String text;

  @override
  State<_CollapsibleText> createState() => _CollapsibleTextState();
}

class _CollapsibleTextState extends State<_CollapsibleText> {
  static const _maxLines = 8;
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    const style =
        TextStyle(color: AppColors.inkMuted, fontSize: 14, height: 1.6);
    final long = '\n'.allMatches(widget.text).length >= _maxLines ||
        widget.text.length > 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _open || !long
              ? SelectableText(widget.text, style: style)
              : Text(widget.text,
                  style: style,
                  maxLines: _maxLines,
                  overflow: TextOverflow.fade),
        ),
        if (long)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _open = !_open),
              icon: Icon(
                  _open
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18),
              label: Text(_open ? t.commonShowLess : t.commonShowMore),
            ),
          ),
      ],
    );
  }
}
