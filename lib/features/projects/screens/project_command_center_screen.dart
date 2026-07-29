import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/ecosystem_score.dart';
import '../../../data/models/opportunity_lab_item.dart';
import '../../../data/models/project.dart';
import '../../../data/models/project_intelligence_profile.dart';
import '../../../providers/ecosystem_intelligence_provider.dart';
import '../../../providers/knowledge_provider.dart';
import '../../../providers/opportunity_lab_provider.dart';
import '../../../providers/project_intelligence_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/context_copilot_widget.dart' show showCopilotChat;
import '../../../shared/widgets/ive_detail_sheet.dart';

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
  final _urlCtrl  = TextEditingController();
  String _type    = 'website';
  bool   _saving  = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    ref.invalidate(projectsNotifierProvider);
    ref.invalidate(ecosystemScoresProvider);
    // Aguarda nova leitura para completar o indicador
    await Future.wait([
      ref.read(projectsNotifierProvider.future).catchError((_) => <Project>[]),
      ref.read(ecosystemScoresProvider.future).catchError((_) => <EcosystemScore>[]),
    ]);
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(projectsNotifierProvider.notifier).create({
        'name':        name,
        'description': _descCtrl.text.trim(),
        'url':         _urlCtrl.text.trim().isNotEmpty ? _urlCtrl.text.trim() : null,
        'type':        _type,
        'status':      'idea',
      });
      _nameCtrl.clear();
      _descCtrl.clear();
      _urlCtrl.clear();
      setState(() { _showForm = false; _type = 'website'; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete(Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Confirmar exclusão', style: TextStyle(color: Colors.white)),
        content: Text(
          'Excluir "${project.name}"?\nEsta ação não pode ser desfeita.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF6B6B)),
            child: const Text('Excluir'),
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
            SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _analyzeWithKnowledge(Project project) async {
    Navigator.of(context).pop();

    // Busca knowledge items do projeto
    final items = await ref.read(knowledgeServiceProvider)
        .fetchAll(projectId: project.id);

    if (!mounted) return;

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Adicione conhecimentos ao projeto antes de analisar.',
          ),
          backgroundColor: const Color(0xFFFF9800),
          action: SnackBarAction(
            label: 'Adicionar',
            textColor: Colors.white,
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

    // Mostra progresso
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Analisando projeto "${project.name}" com ${items.length} conhecimento(s)…'),
        backgroundColor: const Color(0xFF6C63FF),
        duration: const Duration(seconds: 30),
      ),
    );

    try {
      final docs = items
          .where((i) => i.content.trim().length >= 20)
          .take(6)
          .map((i) => {
                'title':   i.title,
                'content': i.content.substring(0, i.content.length.clamp(0, 400)),
              })
          .toList();

      final response = await Supabase.instance.client.functions.invoke(
        AppConstants.edgeFunctionGenerateOpportunities,
        body: {
          'project_name':        project.name,
          'project_description': project.description,
          'project_type':        project.type,
          'documents':           docs,
        },
      );

      if (response.data == null) throw Exception('Resposta vazia.');
      final data = response.data as Map<String, dynamic>;
      if (data.containsKey('error')) throw Exception(data['error']);

      final opportunities = (data['opportunities'] as List? ?? []);
      final notifier = ref.read(opportunityLabNotifierProvider.notifier);

      for (final opp in opportunities) {
        final item = OpportunityLabItem(
          id:              '',
          userId:          '',
          projectId:       project.id,
          opportunityType: opp['opportunity_type'] as String? ?? 'expansão',
          title:           opp['title'] as String? ?? '',
          description:     opp['description'] as String? ?? '',
          marketScore:     (opp['market_score'] as num?)?.toInt() ?? 0,
          revenueScore:    (opp['revenue_score'] as num?)?.toInt() ?? 0,
          competitionScore:(opp['competition_score'] as num?)?.toInt() ?? 0,
          synergyScore:    (opp['synergy_score'] as num?)?.toInt() ?? 0,
          strategicFit:    (opp['strategic_fit'] as num?)?.toInt() ?? 0,
          finalScore:      (opp['final_score'] as num?)?.toInt() ?? 0,
          origin:          'knowledge_engine',
          sources:         items.map((i) => i.title).toList(),
          createdAt:       DateTime.now(),
        );
        await notifier.add(item);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${opportunities.length} oportunidade(s) gerada(s) para "${project.name}"!'),
          backgroundColor: const Color(0xFF4CAF50),
          action: SnackBarAction(
            label: 'Ver',
            textColor: Colors.white,
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
          content: Text('Erro ao analisar: $e'),
          backgroundColor: const Color(0xFFF44336),
        ),
      );
    }
  }

  void _openDetail(Project project, EcosystemScore? score) {
    final profile = ref.read(projectIntelligenceProfilesProvider).valueOrNull
        ?.where((p) => p.project.id == project.id)
        .firstOrNull;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProjectDetailSheet(
        project:             project,
        ecosystemScore:      score,
        intelligenceProfile: profile,
        onStatusChange: (s) {
          Navigator.of(context).pop();
          ref.read(projectsNotifierProvider.notifier).updateStatus(project.id, s);
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
        onViewKnowledge: () {
          Navigator.of(context).pop();
          context.push(
            AppConstants.routeKnowledge,
            extra: {'projectId': project.id},
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncProjects = ref.watch(projectsNotifierProvider);
    final asyncScores   = ref.watch(ecosystemScoresProvider);

    // Mapa projectId → EcosystemScore para lookup O(1)
    final scoresMap = asyncScores.valueOrNull != null
        ? {for (final s in asyncScores.valueOrNull!) s.project.id: s}
        : <String, EcosystemScore>{};

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppConstants.routeHome);
            }
          },
        ),
        backgroundColor: const Color(0xFF0F0F1A),
        title: const Text('Project Command Center',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Refresh
          IconButton(
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF6BCB77),
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: Color(0xFF6BCB77)),
            tooltip: 'Atualizar',
            onPressed: _refreshing ? null : _refresh,
          ),
          // Novo projeto
          IconButton(
            icon: Icon(
              _showForm ? Icons.close_rounded : Icons.add_rounded,
              color: const Color(0xFF6BCB77),
            ),
            onPressed: () => setState(() => _showForm = !_showForm),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          if (_showForm) _buildForm(),
          Expanded(
            child: asyncProjects.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFF6BCB77))),
              error: (e, _) => Center(
                  child: Text('Erro: $e',
                      style: const TextStyle(color: Colors.redAccent))),
              data: (projects) => projects.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      color: const Color(0xFF6BCB77),
                      backgroundColor: const Color(0xFF1A1A2E),
                      onRefresh: _refresh,
                      child: _buildProjectList(projects, scoresMap),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.rocket_launch_outlined,
                color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            const Text('Nenhum projeto ainda',
                style: TextStyle(color: Colors.white38, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Adicione seu primeiro projeto',
                style: TextStyle(color: Colors.white24, fontSize: 13)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => setState(() => _showForm = true),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Novo Projeto'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6BCB77),
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      );

  Widget _buildForm() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFF6BCB77).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Novo Projeto',
              style: TextStyle(
                  color: Color(0xFF6BCB77), fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _Field(
              controller: _nameCtrl,
              label: 'Nome do projeto *',
              hint: 'Ex: Blog de Finanças Pessoais'),
          const SizedBox(height: 10),
          _Field(
              controller: _descCtrl,
              label: 'Descrição',
              hint: 'Descreva o projeto brevemente'),
          const SizedBox(height: 10),
          _Field(
              controller: _urlCtrl,
              label: 'URL (opcional)',
              hint: 'https://...'),
          const SizedBox(height: 10),
          const Text('Tipo',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children:
                ['website', 'app', 'product', 'service', 'content'].map(
              (t) => ChoiceChip(
                label: Text(t),
                selected: _type == t,
                onSelected: (_) => setState(() => _type = t),
                selectedColor: const Color(0xFF6BCB77),
                labelStyle: TextStyle(
                    color: _type == t ? Colors.black : Colors.white60,
                    fontSize: 12),
                backgroundColor: const Color(0xFF0F0F1A),
                side: BorderSide(
                    color: _type == t
                        ? const Color(0xFF6BCB77)
                        : const Color(0xFF333355)),
              ),
            ).toList(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _showForm = false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Color(0xFF333355)),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6BCB77),
                    foregroundColor: Colors.black,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.black, strokeWidth: 2))
                      : const Text('Salvar',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProjectList(
    List<Project> projects,
    Map<String, EcosystemScore> scoresMap,
  ) {
    // Ordena por ecosystemScore quando disponível, fallback para priorityScore
    final sorted = [...projects]..sort((a, b) {
        final sa = scoresMap[a.id]?.ecosystemScore ?? a.priorityScore;
        final sb = scoresMap[b.id]?.ecosystemScore ?? b.priorityScore;
        return sb.compareTo(sa);
      });

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      itemBuilder: (_, i) {
        final p     = sorted[i];
        final score = scoresMap[p.id];
        return _ProjectCard(
          project:        p,
          rank:           i + 1,
          ecosystemScore: score,
          onTap:          () => _openDetail(p, score),
          onStatusChange: (s) =>
              ref.read(projectsNotifierProvider.notifier).updateStatus(p.id, s),
          onDelete:  () => _confirmDelete(p),
          onAnalyze: p.marketAnalysisId != null
              ? () => context.go(AppConstants.routeMarketIntelligenceHub
                  .replaceFirst(':id', p.marketAnalysisId!))
              : null,
        );
      },
    );
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
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
        filled: true,
        fillColor: const Color(0xFF0F0F1A),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF333355)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF6BCB77)),
        ),
      ),
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
  });

  final Project project;
  final int rank;
  final EcosystemScore? ecosystemScore;
  final VoidCallback onTap;
  final void Function(String) onStatusChange;
  final VoidCallback onDelete;
  final VoidCallback? onAnalyze;

  Color get _statusColor {
    switch (project.status) {
      case 'active':    return const Color(0xFF6BCB77);
      case 'completed': return const Color(0xFF4D96FF);
      case 'paused':    return const Color(0xFFFFD93D);
      default:          return Colors.white38;
    }
  }

  String get _statusLabel {
    switch (project.status) {
      case 'active':    return 'Ativo';
      case 'completed': return 'Concluído';
      case 'paused':    return 'Pausado';
      default:          return 'Ideia';
    }
  }

  String _fmtRevenue(double v) {
    if (v <= 0)        return 'Não estimado';
    if (v >= 1000000)  return 'R\$ ${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)     return 'R\$ ${(v / 1000).toStringAsFixed(0)}K';
    return 'R\$ ${v.toStringAsFixed(0)}';
  }

  String _fmtPrazo(int days) {
    if (days <= 0) return '—';
    if (days >= 365) return '${(days / 365).round()}a';
    if (days >= 30)  return '${(days / 30).round()}m';
    return '${days}d';
  }

  @override
  Widget build(BuildContext context) {
    final s        = ecosystemScore;
    final oppScore = s?.opportunityScore ?? project.opportunityScore;
    final revenue  = s?.totalRoi != null && s!.totalRoi > 0
        ? _fmtRevenue(s.totalRoi)
        : _fmtRevenue(project.revenuePotential);
    final ecoScore = s?.ecosystemScore;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _statusColor.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6BCB77).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text('#$rank',
                              style: const TextStyle(
                                  color: Color(0xFF6BCB77),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(project.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                      ),
                      // Ecosystem score badge quando disponível
                      if (ecoScore != null)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: _ecoScoreColor(ecoScore).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('$ecoScore',
                              style: TextStyle(
                                  color: _ecoScoreColor(ecoScore),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: _statusColor.withOpacity(0.5)),
                        ),
                        child: Text(_statusLabel,
                            style: TextStyle(
                                color: _statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  if (project.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 38),
                      child: Text(project.description,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  // Recomendação da IA quando disponível
                  if (s != null && s.recommendation.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 38),
                      child: Row(
                        children: [
                          Text(s.recommendationEmoji,
                              style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(s.recommendation,
                              style: const TextStyle(
                                  color: Color(0xFFAB83FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _StatChip(
                          label: 'Oportunidade',
                          value: '$oppScore',
                          color: const Color(0xFF00BCD4)),
                      const SizedBox(width: 8),
                      _StatChip(
                          label: 'Potencial',
                          value: revenue,
                          color: const Color(0xFFFFD93D)),
                      const SizedBox(width: 8),
                      _StatChip(
                          label: 'Prazo',
                          value: _fmtPrazo(project.timeToRevenueDays),
                          color: const Color(0xFFAB83FF)),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF333355), height: 1),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  _ActionBtn(
                    icon: Icons.info_outline_rounded,
                    label: 'Detalhe',
                    color: const Color(0xFF6C63FF),
                    onTap: onTap,
                  ),
                  if (onAnalyze != null)
                    _ActionBtn(
                        icon: Icons.analytics_rounded,
                        label: 'Análise',
                        color: const Color(0xFF00BCD4),
                        onTap: onAnalyze!),
                  _ActionBtn(
                    icon: Icons.play_arrow_rounded,
                    label: 'Ativar',
                    color: const Color(0xFF6BCB77),
                    onTap: () => onStatusChange('active'),
                  ),
                  _ActionBtn(
                    icon: Icons.delete_rounded,
                    label: 'Excluir',
                    color: const Color(0xFFFF6B6B),
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

  Color _ecoScoreColor(int score) {
    if (score >= 70) return const Color(0xFF6BCB77);
    if (score >= 40) return const Color(0xFFFFD93D);
    return const Color(0xFFFF6B6B);
  }
}

// ── Project Detail Bottom Sheet ───────────────────────────────────────────────

class _ProjectDetailSheet extends StatelessWidget {
  const _ProjectDetailSheet({
    required this.project,
    required this.onStatusChange,
    required this.onDelete,
    this.ecosystemScore,
    this.intelligenceProfile,
    this.onAnalyze,
    this.onAnalyzeKnowledge,
    this.onViewKnowledge,
  });

  final Project project;
  final EcosystemScore? ecosystemScore;
  final ProjectIntelligenceProfile? intelligenceProfile;
  final void Function(String) onStatusChange;
  final VoidCallback onDelete;
  final VoidCallback? onAnalyze;
  final VoidCallback? onAnalyzeKnowledge;
  final VoidCallback? onViewKnowledge;

  Color _ecoScoreColor(int score) {
    if (score >= 70) return const Color(0xFF6BCB77);
    if (score >= 40) return const Color(0xFFFFD93D);
    return const Color(0xFFFF6B6B);
  }

  String _classify(int v) => v >= 70 ? 'Alto ✓' : v >= 40 ? 'Médio ⚡' : 'Baixo ⚠';

  void _showScoreExplain(
    BuildContext context,
    String emoji,
    String label,
    int value,
    String weight,
    String explanation,
    String howToImprove, [
    List<IveAction> actions = const [],
  ]) {
    IveDetailSheet.show(
      context,
      title:            label,
      emoji:            emoji,
      humanExplanation: '$explanation\n\nComo melhorar: $howToImprove',
      evidence: [
        IveEvidence(emoji: '📊', label: 'Score atual',          value: '$value/100'),
        IveEvidence(emoji: '🏷️', label: 'Classificação',        value: _classify(value)),
        IveEvidence(emoji: '⚡', label: 'Peso no Ecosystem',     value: weight),
      ],
      expandedData: {
        'Peso no Ecosystem Score': weight,
        'Meta recomendada':       '>= 70 (Alto)',
      },
      suggestedActions: actions,
      screenName: 'Projetos',
    );
  }

  String _fmtRevenue(double v) {
    if (v <= 0)        return 'Ainda não estimado';
    if (v >= 1000000)  return 'R\$ ${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)     return 'R\$ ${(v / 1000).toStringAsFixed(0)}K';
    return 'R\$ ${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final s = ecosystemScore;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize:     0.4,
      maxChildSize:     0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1B2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(project.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                ),
                if (s != null)
                  GestureDetector(
                    onTap: () => IveDetailSheet.show(
                      context,
                      title: 'Ecosystem Score',
                      emoji: '🌐',
                      humanExplanation:
                          'O Ecosystem Score é o indicador geral de saúde e potencial deste projeto. '
                          'Score ${s.ecosystemScore}/100 — ${_classify(s.ecosystemScore)}.\n\n'
                          'É calculado pela combinação ponderada de 5 dimensões: '
                          'Oportunidade (25%), Fit Estratégico (25%), Sinergia (20%), ROI (20%) e Momentum (10%).',
                      evidence: [
                        IveEvidence(emoji: '📊', label: 'Score total',       value: '${s.ecosystemScore}/100'),
                        IveEvidence(emoji: '🏷️', label: 'Classificação',     value: _classify(s.ecosystemScore)),
                        IveEvidence(emoji: '⚡', label: 'Recomendação',       value: s.recommendation),
                        IveEvidence(emoji: '✅', label: 'Ações concluídas',   value: '${s.completedActions}/${s.actionCount} (${s.completionRate}%)'),
                        IveEvidence(emoji: '💰', label: 'ROI total',          value: _fmtRevenue(s.totalRoi)),
                      ],
                      expandedData: {
                        'Fórmula': 'Opp×25% + Fit×25% + Sin×20% + ROI×20% + Mom×10%',
                        'Oportunidade': '${s.opportunityScore} × 0.25 = ${(s.opportunityScore * 0.25).round()}',
                        'Fit Estratégico': '${s.strategicFit} × 0.25 = ${(s.strategicFit * 0.25).round()}',
                        'Sinergia': '${s.synergyScore} × 0.20 = ${(s.synergyScore * 0.20).round()}',
                        'ROI': '${s.roiScore} × 0.20 = ${(s.roiScore * 0.20).round()}',
                        'Momentum': '${s.momentumScore} × 0.10 = ${(s.momentumScore * 0.10).round()}',
                      },
                      screenName: 'Projetos',
                    ),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Column(
                        children: [
                          Text('${s.ecosystemScore}',
                              style: TextStyle(
                                  color: _ecoScoreColor(s.ecosystemScore),
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold)),
                          const Text('eco score',
                              style: TextStyle(color: Colors.white38, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            if (project.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(project.description,
                  style:
                      const TextStyle(color: Colors.white60, fontSize: 13)),
            ],
            if (project.url != null) ...[
              const SizedBox(height: 4),
              Text(project.url!,
                  style: const TextStyle(
                      color: Color(0xFF6C63FF), fontSize: 12)),
            ],
            const SizedBox(height: 16),

            // Recomendação
            if (s != null) ...[
              _sectionTitle('Recomendação IA'),
              GestureDetector(
                onTap: () => IveDetailSheet.show(
                  context,
                  title: 'Recomendação: ${s.recommendation}',
                  emoji: s.recommendationEmoji,
                  humanExplanation: 'A IVE analisou os 5 scores do ecossistema e '
                      'recomenda: ${s.recommendation}.\n\n'
                      'Esta recomendação é gerada quando o Ecosystem Score '
                      '${s.ecosystemScore >= 70 ? "está alto (≥70)" : s.ecosystemScore >= 40 ? "está moderado (40–69)" : "está baixo (<40)"} '
                      'e considera a combinação de oportunidade, '
                      'fit estratégico, sinergia, ROI e momentum.',
                  evidence: [
                    IveEvidence(emoji: '🌐', label: 'Ecosystem Score', value: '${s.ecosystemScore}/100'),
                    IveEvidence(emoji: '🎯', label: 'Oportunidade',    value: '${s.opportunityScore}/100'),
                    IveEvidence(emoji: '🔗', label: 'Fit Estratégico', value: '${s.strategicFit}/100'),
                    IveEvidence(emoji: '⚡', label: 'Momentum',         value: '${s.momentumScore}/100'),
                  ],
                  screenName: 'Projetos',
                ),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFAB83FF).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFAB83FF).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Text(s.recommendationEmoji,
                            style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(s.recommendation,
                              style: const TextStyle(
                                  color: Color(0xFFAB83FF),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ),
                        const Icon(Icons.info_outline_rounded, color: Color(0xFF6C63FF), size: 14),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Score breakdown
              _sectionTitle('Scores do Ecossistema'),
              _ScoreRow('Oportunidade', s.opportunityScore, onTap: () => _showScoreExplain(
                context, '🎯', 'Oportunidade', s.opportunityScore, '25%',
                'Mede o potencial de oportunidade de mercado: demanda de busca, '
                'monetização, concorrência e crescimento do nicho. '
                'Gerado a partir das análises de Market Intelligence.',
                'Execute uma análise detalhada no Market Intelligence e conecte ao projeto.',
                [if (onAnalyze != null) IveAction(emoji: '📊', label: 'Ver Análise de Mercado', onTap: onAnalyze)],
              )),
              _ScoreRow('Fit Estratégico', s.strategicFit, onTap: () => _showScoreExplain(
                context, '🔗', 'Fit Estratégico', s.strategicFit, '25%',
                'Avalia o alinhamento deste projeto com seu portfólio, '
                'habilidades existentes e objetivos de negócio. '
                'Quanto maior, mais este projeto se encaixa na sua estratégia atual.',
                'Adicione conhecimentos e oportunidades relacionadas ao projeto para aumentar o fit.',
              )),
              _ScoreRow('Sinergia', s.synergyScore, onTap: () => _showScoreExplain(
                context, '🤝', 'Sinergia', s.synergyScore, '20%',
                'Mede a complementaridade deste projeto com os outros projetos do portfólio. '
                'Alta sinergia significa que projetos se beneficiam mutuamente '
                '(audiência compartilhada, conteúdo reutilizável, canais em comum).',
                'Crie projetos complementares ou vincule análises de mercado para aumentar a sinergia.',
              )),
              _ScoreRow('ROI', s.roiScore, onTap: () => _showScoreExplain(
                context, '💰', 'ROI', s.roiScore, '20%',
                'Potencial de retorno sobre investimento de tempo e recursos. '
                'Considera receita potencial estimada, receita já registrada '
                'e o esforço de execução nas ações do Action Engine.',
                'Registre entradas no ROI Tracker e aprove mais oportunidades de alta receita.',
              )),
              _ScoreRow('Momentum', s.momentumScore, onTap: () => _showScoreExplain(
                context, '⚡', 'Momentum', s.momentumScore, '10%',
                'Velocidade e ritmo de progresso no projeto. '
                'Calculado com base em ações executadas, taxa de conclusão '
                'e frequência de atualizações recentes.',
                'Complete ações pendentes no Action Engine e mantenha atualização regular do projeto.',
              )),
              _ScoreRow('Mercado', s.marketScore, onTap: () => _showScoreExplain(
                context, '📈', 'Mercado', s.marketScore, '—',
                'Atratividade do mercado-alvo. Baseado em tamanho do mercado, '
                'tendências de crescimento, concorrência e monetização identificada '
                'nas análises de Market Intelligence.',
                'Execute análise de mercado atualizada e pesquise nichos com maior potencial.',
                [if (onAnalyze != null) IveAction(emoji: '📊', label: 'Ver Análise de Mercado', onTap: onAnalyze)],
              )),
              _ScoreRow('Execução', s.executionScore, onTap: () => _showScoreExplain(
                context, '🚀', 'Execução', s.executionScore, '—',
                'Qualidade e ritmo da execução. Considera ações concluídas, '
                'oportunidades aprovadas, existência de roadmap '
                'e taxa de progresso geral do projeto.',
                'Aprove e execute ações no Action Engine. Defina roadmap e prazos claros.',
              )),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ações: ${s.completedActions}/${s.actionCount} (${s.completionRate}%)',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Text(
                    'ROI total: ${_fmtRevenue(s.totalRoi)}',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Scores do projeto (quando sem ecosystemScore ainda)
            if (s == null) ...[
              _sectionTitle('Métricas do Projeto'),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                        label: 'Oportunidade',
                        value: '${project.opportunityScore}',
                        color: const Color(0xFF00BCD4)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricTile(
                        label: 'Complexidade',
                        value: '${project.complexityScore}',
                        color: const Color(0xFFFFD93D)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricTile(
                        label: 'Potencial',
                        value: _fmtRevenue(project.revenuePotential),
                        color: const Color(0xFF6BCB77)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Pontos fortes
            if (s != null && s.strengths.isNotEmpty) ...[
              _sectionTitle('Pontos Fortes'),
              ..._tappableBullets(
                context,
                s.strengths,
                const Color(0xFF6BCB77),
                '✓ ',
                '💪',
                'Ponto Forte',
                'Identificado com base nas análises de mercado, '
                'histórico de execução e dados do portfólio.',
                'Continue investindo neste diferencial. Explore oportunidades que amplificam este ponto forte.',
              ),
              const SizedBox(height: 12),
            ],

            // Riscos
            if (s != null && s.risks.isNotEmpty) ...[
              _sectionTitle('Riscos'),
              ..._tappableBullets(
                context,
                s.risks,
                const Color(0xFFFF6B6B),
                '⚠ ',
                '⚠️',
                'Risco',
                'Identificado nas análises de mercado e no histórico de execução do projeto.',
                'Crie um plano de mitigação e defina ações preventivas no Action Engine.',
              ),
              const SizedBox(height: 12),
            ],

            // Quick wins
            if (s != null && s.quickWins.isNotEmpty) ...[
              _sectionTitle('Quick Wins'),
              ..._tappableBullets(
                context,
                s.quickWins,
                const Color(0xFFFFD93D),
                '⚡ ',
                '⚡',
                'Quick Win',
                'Oportunidade de alto impacto e baixo esforço identificada pela IVE.',
                'Envie para o Action Engine e priorize para execução imediata.',
              ),
              const SizedBox(height: 12),
            ],

            // Next actions (from detailsJson)
            if (project.nextActions.isNotEmpty) ...[
              _sectionTitle('Próximas Ações'),
              ..._bullets(project.nextActions, const Color(0xFFAB83FF), '→ '),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 8),

            // Intelligence Profile section
            if (intelligenceProfile != null) ...[
              const Divider(color: Color(0xFF333355)),
              const SizedBox(height: 12),
              _sectionTitle('Perfil de Inteligência'),
              _intelligenceSection(context, intelligenceProfile!),
              const SizedBox(height: 8),
            ],

            const Divider(color: Color(0xFF333355)),
            const SizedBox(height: 12),

            // Action buttons
            if (onAnalyze != null)
              _SheetButton(
                icon: Icons.analytics_rounded,
                label: 'Ver Análise de Mercado',
                color: const Color(0xFF00BCD4),
                onTap: onAnalyze!,
              ),
            if (onAnalyze != null) const SizedBox(height: 8),
            Row(
              children: [
                if (onViewKnowledge != null)
                  Expanded(
                    child: _SheetButton(
                      icon: Icons.menu_book_rounded,
                      label: 'Ver Conhecimentos',
                      color: const Color(0xFF00BCD4),
                      onTap: onViewKnowledge!,
                    ),
                  ),
                if (onViewKnowledge != null && onAnalyzeKnowledge != null)
                  const SizedBox(width: 8),
                if (onAnalyzeKnowledge != null)
                  Expanded(
                    child: _SheetButton(
                      icon: Icons.psychology_rounded,
                      label: 'Analisar com IA',
                      color: const Color(0xFF6C63FF),
                      onTap: onAnalyzeKnowledge!,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _SheetButton(
                    icon: Icons.play_arrow_rounded,
                    label: 'Ativar',
                    color: const Color(0xFF6BCB77),
                    onTap: () => onStatusChange('active'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SheetButton(
                    icon: Icons.pause_rounded,
                    label: 'Pausar',
                    color: const Color(0xFFFFD93D),
                    onTap: () => onStatusChange('paused'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SheetButton(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Concluir',
                    color: const Color(0xFF4D96FF),
                    onTap: () => onStatusChange('completed'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _SheetButton(
              icon: Icons.delete_outline_rounded,
              label: 'Excluir Projeto',
              color: const Color(0xFFFF6B6B),
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  Widget _intelligenceSection(BuildContext context, ProjectIntelligenceProfile p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Maturity card — clicável
        GestureDetector(
          onTap: () {
            final stages = ['💡 Ideia', '🔬 Validando', '🌱 Crescendo', '🌳 Maduro'];
            final stageDesc = {
              'ideia':     'O projeto existe como conceito. Tem proposta de valor mas ainda não foi validado no mercado.',
              'validando': 'Primeiras análises realizadas. Testando hipóteses com análises de mercado e primeiras ações.',
              'crescendo': 'Validado no mercado com tração inicial. Receita ou usuários crescendo.',
              'maduro':    'Operação estável com crescimento consistente, receita recorrente e processos definidos.',
            };
            final nextStage = {
              'ideia':     '🔬 Validando — Execute análise de mercado, defina ICP e crie primeiras ações.',
              'validando': '🌱 Crescendo — Valide hipóteses, conquiste primeiros clientes e registre receita.',
              'crescendo': '🌳 Maduro — Estabilize operação, documente processos e escale canais que funcionam.',
              'maduro':    '🌎 Escala — Expanda para novos mercados e maximize o ROI.',
            };
            IveDetailSheet.show(
              context,
              title: 'Maturidade: ${p.maturityLabel}',
              emoji: p.maturityEmoji,
              humanExplanation:
                  '${stageDesc[p.maturityStage] ?? "Estágio de maturidade do projeto."}\n\n'
                  'Score de cobertura de dados: ${p.coverage.score}/100 (${p.coverage.coverageLabel}).\n'
                  '${p.dataWarning != null ? "⚠ ${p.dataWarning}" : ""}',
              evidence: [
                IveEvidence(emoji: p.maturityEmoji, label: 'Estágio atual',     value: p.maturityLabel),
                IveEvidence(emoji: '📊', label: 'Cobertura de dados',           value: '${p.coverage.score}/100'),
                IveEvidence(emoji: '🔍', label: 'Análise de mercado',           value: p.analysis != null ? 'Disponível ✓' : 'Ausente ✗'),
                IveEvidence(emoji: '📝', label: 'Próximo estágio',              value: nextStage[p.maturityStage] ?? '—'),
              ],
              expandedData: {
                'Linha do tempo': stages.join(' → '),
                'Estágio atual':  p.maturityLabel,
                'Cobertura mín. para avançar': '>= 30 + análise de mercado',
              },
              screenName: 'Projetos',
            );
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  Text(p.maturityEmoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Maturidade: ${p.maturityLabel}',
                          style: const TextStyle(
                            color: Color(0xFF6C63FF),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        if (p.dataWarning != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              p.dataWarning!,
                              style: const TextStyle(color: Colors.orange, fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF6C63FF), size: 14),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Identity: niche, audience, monetization
        if (p.niche != 'Não definido') ...[
          _infoRow('🎯 Nicho', p.niche),
        ],
        if (p.targetAudience != 'Não definido') ...[
          _infoRow('👥 Público', p.targetAudience),
        ],
        if (p.monetizationModel != 'Não definido') ...[
          _infoRow('💰 Monetização', p.monetizationModel),
        ],
        if (p.valueProposition.isNotEmpty) ...[
          _infoRow('✨ Proposta', p.valueProposition),
        ],

        // Identified topics — clicáveis
        if (p.identifiedTopics.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Tópicos identificados',
              style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: p.identifiedTopics.map((t) => GestureDetector(
              onTap: () => IveDetailSheet.show(
                context,
                title: t,
                emoji: '🏷️',
                humanExplanation:
                    'A IVE classificou este projeto com o tópico "$t" com base nos '
                    'conhecimentos, análises e documentos associados ao projeto.\n\n'
                    'Este tópico indica que o conteúdo, mercado ou estratégia do projeto '
                    'tem relação com $t.',
                evidence: [
                  IveEvidence(emoji: '📁', label: 'Projeto',         value: p.project.name),
                  IveEvidence(emoji: '🎯', label: 'Nicho',           value: p.niche),
                  IveEvidence(emoji: '📊', label: 'Cobertura',       value: '${p.coverage.score}/100'),
                  IveEvidence(emoji: '🏷️', label: 'Total de tópicos', value: '${p.identifiedTopics.length}'),
                ],
                screenName: 'Projetos',
              ),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BCD4).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
                  ),
                  child: Text(t, style: const TextStyle(color: Color(0xFF00BCD4), fontSize: 10)),
                ),
              ),
            )).toList(),
          ),
        ],

        // Missing knowledge gaps
        if (p.missingKnowledge.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Lacunas de conhecimento',
              style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          ...p.missingKnowledge.take(3).map((gap) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⚠ ', style: TextStyle(color: Colors.orange, fontSize: 11)),
                Expanded(child: Text(gap, style: const TextStyle(color: Colors.white54, fontSize: 11))),
              ],
            ),
          )),
        ],

        // Related projects
        if (p.relatedProjectNames.isNotEmpty) ...[
          const SizedBox(height: 8),
          _infoRow('🔗 Relacionados', p.relatedProjectNames.take(3).join(', ')),
        ],

        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6C63FF),
              side: const BorderSide(color: Color(0xFF6C63FF)),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Text('🧠', style: TextStyle(fontSize: 14)),
            label: const Text('Perguntar à IVE sobre este perfil', style: TextStyle(fontSize: 13)),
            onPressed: () {
              Navigator.of(context).pop();
              showCopilotChat(
                context,
                screenName:     'Projetos',
                initialMessage: 'Analise o perfil de inteligência do projeto "${p.project.name}": '
                    'nicho ${p.niche}, público ${p.targetAudience}, maturidade ${p.maturityLabel}. '
                    '${p.missingKnowledge.isNotEmpty ? "Lacunas: ${p.missingKnowledge.join(", ")}." : ""} '
                    'O que devo priorizar agora?',
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
              child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8)),
      );

  List<Widget> _bullets(List<String> items, Color color, String prefix) =>
      items
          .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(prefix, style: TextStyle(color: color, fontSize: 12)),
                    Expanded(
                        child: Text(item,
                            style: const TextStyle(color: Colors.white70, fontSize: 12))),
                  ],
                ),
              ))
          .toList();

  List<Widget> _tappableBullets(
    BuildContext context,
    List<String> items,
    Color color,
    String prefix,
    String emoji,
    String kind,
    String sourceExplanation,
    String howToImprove,
  ) =>
      items
          .map((item) => GestureDetector(
                onTap: () => IveDetailSheet.show(
                  context,
                  title: '$kind identificado',
                  emoji: emoji,
                  humanExplanation: '"$item"\n\n$sourceExplanation',
                  evidence: [
                    IveEvidence(emoji: emoji,  label: kind,               value: item),
                    IveEvidence(emoji: '📋',   label: 'Projeto',          value: project.name),
                  ],
                  expandedData: {'Como agir': howToImprove},
                  screenName: 'Projetos',
                ),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(prefix, style: TextStyle(color: color, fontSize: 12)),
                        Expanded(
                            child: Text(item,
                                style: const TextStyle(color: Colors.white70, fontSize: 12))),
                        Icon(Icons.info_outline_rounded, size: 11, color: color.withOpacity(0.5)),
                      ],
                    ),
                  ),
                ),
              ))
          .toList();
}

// ── Score row com barra de progresso ─────────────────────────────────────────

class _ScoreRow extends StatelessWidget {
  const _ScoreRow(this.label, this.value, {this.onTap});
  final String label;
  final int value;
  final VoidCallback? onTap;

  Color get _color {
    if (value >= 70) return const Color(0xFF6BCB77);
    if (value >= 40) return const Color(0xFFFFD93D);
    return const Color(0xFFFF6B6B);
  }

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value / 100,
                backgroundColor: const Color(0xFF333355),
                valueColor: AlwaysStoppedAnimation(_color),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 30,
            child: Text('$value',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: _color, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          if (onTap != null)
            const SizedBox(
              width: 20,
              child: Icon(Icons.info_outline_rounded, size: 12, color: Color(0xFF6C63FF)),
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: row),
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  const TextStyle(color: Colors.white38, fontSize: 10)),
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
      label: Text(label, style: TextStyle(color: color, fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        side: BorderSide(color: color.withOpacity(0.4)),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
            Text(label,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 10)),
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
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: color, size: 14),
        label: Text(label, style: TextStyle(color: color, fontSize: 11)),
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
      ),
    );
  }
}
