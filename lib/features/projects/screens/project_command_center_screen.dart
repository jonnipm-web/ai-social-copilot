import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/copilot_context_data.dart';
import '../../../data/models/ecosystem_score.dart';
import '../../../data/models/project.dart';
import '../../../providers/ecosystem_intelligence_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/context_copilot_widget.dart'
    show openIveWithContext, synchronizeIveProjectContext;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/knowledge_item.dart';
import '../../../data/models/opportunity_lab_item.dart';
import '../../../providers/knowledge_provider.dart';
import '../../../providers/opportunity_lab_provider.dart';

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
  bool _isIdeaMode = false;
  String _filter = 'all';
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
        'name':         name,
        'description':  _descCtrl.text.trim(),
        'url':          _urlCtrl.text.trim().isNotEmpty ? _urlCtrl.text.trim() : null,
        'type':         _type,
        'status':       'idea',
        'details_json': {'is_idea': _isIdeaMode},
      });
      _nameCtrl.clear();
      _descCtrl.clear();
      _urlCtrl.clear();
      setState(() { _showForm = false; _type = 'website'; _isIdeaMode = false; });
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

  Future<void> _openDetail(Project project, EcosystemScore? score) async {
    await synchronizeIveProjectContext(
      ProviderScope.containerOf(context),
      projectId: project.id,
      project: project,
    );
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProjectDetailSheet(
        project:        project,
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
      ),
    );
  }

  void _showEntityChoice() {
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('O que deseja criar?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.rocket_launch_rounded,
                  color: Color(0xFF6BCB77)),
              title: const Text('Projeto Real',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('Algo que você vai executar agora',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () => Navigator.of(ctx).pop('project'),
            ),
            const Divider(color: Color(0xFF333355), height: 1),
            ListTile(
              leading: const Text('💡',
                  style: TextStyle(fontSize: 22)),
              title: const Text('Somente uma Ideia',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('Capture para avaliar depois com a IVE',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () => Navigator.of(ctx).pop('idea'),
            ),
          ],
        ),
      ),
    ).then((choice) {
      if (choice != null && mounted) {
        setState(() {
          _isIdeaMode = choice == 'idea';
          _showForm = true;
        });
      }
    });
  }

  Widget _buildFilterBar() {
    const filters = [
      ('all', 'TODOS'),
      ('projects', 'PROJETOS'),
      ('ideas', 'IDEIAS'),
      ('active', 'ATIVOS'),
      ('paused', 'PAUSADOS'),
      ('completed', 'CONCLUÍDOS'),
    ];
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: filters.map((rec) {
          final (key, label) = rec;
          final selected = _filter == key;
          return Padding(
            padding: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
            child: GestureDetector(
              onTap: () => setState(() => _filter = key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF6BCB77).withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF6BCB77)
                        : const Color(0xFF333355),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF6BCB77)
                        : Colors.white38,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilteredEmpty() {
    final labels = {
      'projects': 'projetos',
      'ideas': 'ideias',
      'active': 'projetos ativos',
      'paused': 'projetos pausados',
      'completed': 'projetos concluídos',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Nenhum ${labels[_filter] ?? 'item'} encontrado.',
          style: const TextStyle(color: Colors.white38, fontSize: 14),
          textAlign: TextAlign.center,
        ),
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
          // Novo projeto / ideia
          IconButton(
            icon: Icon(
              _showForm ? Icons.close_rounded : Icons.add_rounded,
              color: const Color(0xFF6BCB77),
            ),
            onPressed: _showForm
                ? () => setState(() {
                      _showForm = false;
                      _isIdeaMode = false;
                    })
                : _showEntityChoice,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          if (_showForm) _buildForm(),
          _buildFilterBar(),
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
              onPressed: _showEntityChoice,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Criar Projeto ou Ideia'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6BCB77),
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      );

  Widget _buildForm() {
    final accentColor =
        _isIdeaMode ? const Color(0xFFAB83FF) : const Color(0xFF6BCB77);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_isIdeaMode) ...[
                const Text('💡 ', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
              ],
              Text(
                _isIdeaMode ? 'Nova Ideia' : 'Novo Projeto',
                style: TextStyle(
                    color: accentColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
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
                  onPressed: () => setState(() {
                    _showForm = false;
                    _isIdeaMode = false;
                  }),
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
                    backgroundColor: _isIdeaMode
                        ? const Color(0xFFAB83FF)
                        : const Color(0xFF6BCB77),
                    foregroundColor: Colors.white,
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
    // Apply active filter
    final filtered = _filter == 'projects'
        ? projects.where((p) => !p.isIdea).toList()
        : _filter == 'ideas'
            ? projects.where((p) => p.isIdea).toList()
            : _filter == 'active'
                ? projects.where((p) => p.status == 'active').toList()
                : _filter == 'paused'
                    ? projects.where((p) => p.status == 'paused').toList()
                    : _filter == 'completed'
                        ? projects.where((p) => p.status == 'completed').toList()
                        : projects;

    if (filtered.isEmpty) return _buildFilteredEmpty();

    // Ordena por ecosystemScore quando disponível, fallback para priorityScore
    final sorted = [...filtered]..sort((a, b) {
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
    if (project.isIdea) return const Color(0xFFAB83FF);
    switch (project.status) {
      case 'active':    return const Color(0xFF6BCB77);
      case 'completed': return const Color(0xFF4D96FF);
      case 'paused':    return const Color(0xFFFFD93D);
      default:          return Colors.white38;
    }
  }

  String get _statusLabel {
    if (project.isIdea) {
      switch (project.ideaState) {
        case 'evaluated': return 'Avaliada';
        case 'promoted':  return 'Promovida';
        case 'linked':    return 'Vinculada';
        default:          return 'Ideia';
      }
    }
    switch (project.status) {
      case 'active':    return 'Ativo';
      case 'completed': return 'Concluído';
      case 'paused':    return 'Pausado';
      default:          return 'Ideia';
    }
  }

  String _fmtRevenue(double v) {
    if (v >= 1000000) return 'R\$ ${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return 'R\$ ${(v / 1000).toStringAsFixed(0)}K';
    return 'R\$ ${v.toStringAsFixed(0)}';
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
                      project.isIdea
                          ? const SizedBox(
                              width: 28,
                              height: 28,
                              child: Center(
                                child: Text('💡',
                                    style: TextStyle(fontSize: 18)),
                              ),
                            )
                          : Container(
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
                          value: '${project.timeToRevenueDays}d',
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

class _ProjectDetailSheet extends ConsumerStatefulWidget {
  const _ProjectDetailSheet({
    required this.project,
    required this.onStatusChange,
    required this.onDelete,
    this.onAnalyze,
  });

  final Project project;
  final void Function(String) onStatusChange;
  final VoidCallback onDelete;
  final VoidCallback? onAnalyze;

  @override
  ConsumerState<_ProjectDetailSheet> createState() => _ProjectDetailSheetState();
}

class _ProjectDetailSheetState extends ConsumerState<_ProjectDetailSheet> {
  bool _analyzing = false;
  String? _analysisError;
  String? _analysisSuccess;

  // Idea lifecycle
  bool _evaluating = false;
  String? _evaluationError;
  Map<String, dynamic>? _localEvaluation;

  Color _ecoScoreColor(int score) {
    if (score >= 70) return const Color(0xFF6BCB77);
    if (score >= 40) return const Color(0xFFFFD93D);
    return const Color(0xFFFF6B6B);
  }

  String _fmtRevenue(double v) {
    if (v >= 1000000) return 'R\$ ${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return 'R\$ ${(v / 1000).toStringAsFixed(0)}K';
    return 'R\$ ${v.toStringAsFixed(0)}';
  }

  Future<void> _analyzeProject() async {
    if (_analyzing) return;
    setState(() {
      _analyzing = true;
      _analysisError = null;
      _analysisSuccess = null;
    });
    try {
      final items = await ref.read(
          knowledgeItemsByProjectProvider(widget.project.id).future);
      final documents = items
          .where((i) => i.content.isNotEmpty)
          .map((i) => {'title': i.title, 'content': i.content})
          .toList();

      final response = await Supabase.instance.client.functions.invoke(
        'generate-project-opportunities',
        body: {
          'project_name':        widget.project.name,
          'project_description': widget.project.description,
          'project_type':        widget.project.type,
          'documents':           documents,
          'market_context':      '',
        },
      );

      if (response.data == null) throw Exception('Sem resposta da IA');

      final data          = response.data as Map<String, dynamic>;
      final opportunities = (data['opportunities'] as List<dynamic>?) ?? [];
      final uid           = Supabase.instance.client.auth.currentUser!.id;
      final labNotifier   = ref.read(opportunityLabNotifierProvider.notifier);

      for (final raw in opportunities) {
        final opp = raw as Map<String, dynamic>;
        await labNotifier.add(OpportunityLabItem(
          id:               '',
          userId:           uid,
          projectId:        widget.project.id,
          opportunityType:  opp['opportunity_type'] as String? ?? 'expansão',
          title:            opp['title'] as String? ?? '',
          description:      opp['description'] as String? ?? '',
          marketScore:      (opp['market_score'] as num?)?.toInt() ?? 0,
          revenueScore:     (opp['revenue_score'] as num?)?.toInt() ?? 0,
          competitionScore: (opp['competition_score'] as num?)?.toInt() ?? 0,
          synergyScore:     (opp['synergy_score'] as num?)?.toInt() ?? 0,
          strategicFit:     (opp['strategic_fit'] as num?)?.toInt() ?? 0,
          finalScore:       (opp['final_score'] as num?)?.toInt() ?? 0,
          status:           'pending',
          createdAt:        DateTime.now(),
          origin:           'ia-project-analysis',
        ));
      }

      if (mounted) {
        ref.invalidate(ecosystemScoresProvider);
        setState(() => _analysisSuccess =
            '${opportunities.length} oportunidade(s) gerada(s). Scores atualizados.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _analysisError =
            'Erro na análise: ${e.toString().replaceAll('Exception: ', '')}');
      }
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _showKnowledgeSelector(List<KnowledgeItem> linked) async {
    List<KnowledgeItem> all;
    try {
      all = await ref.read(knowledgeItemsProvider.future);
    } catch (e) {
      if (mounted) setState(() => _analysisError = 'Erro ao carregar Cofre: $e');
      return;
    }
    final linkedIds = linked.map((i) => i.id).toSet();
    // Show ALL items not already linked to THIS project (including those
    // linked to other projects — user may want to move them).
    final available = all
        .where((i) => !linkedIds.contains(i.id))
        .toList();

    if (!mounted) return;

    if (available.isEmpty) {
      setState(() => _analysisError =
          'Nenhum item disponível. Adicione itens no Cofre de Conhecimento primeiro.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1B2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) => _KnowledgeSelectorSheet(
        items: available,
        currentProjectId: widget.project.id,
        onSelect: (item) async {
          Navigator.of(ctx).pop();
          try {
            await ref
                .read(knowledgeServiceProvider)
                .update(item.id, {'project_id': widget.project.id});
            ref.invalidate(knowledgeItemsByProjectProvider(widget.project.id));
            if (mounted) setState(() => _analysisError = null);
          } catch (e) {
            if (mounted) setState(() => _analysisError = 'Erro ao vincular: $e');
          }
        },
      ),
    );
  }

  Future<void> _unlinkItem(KnowledgeItem item) async {
    try {
      await ref
          .read(knowledgeServiceProvider)
          .update(item.id, {'project_id': null});
      ref.invalidate(knowledgeItemsByProjectProvider(widget.project.id));
    } catch (e) {
      if (mounted) setState(() => _analysisError = 'Erro ao desvincular: $e');
    }
  }

  void _openIdeaIntake() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1B2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _IdeaIntakeSheet(
        project: widget.project,
        onIdeaSaved: () {
          ref.invalidate(knowledgeItemsByProjectProvider(widget.project.id));
          if (mounted) setState(() => _analysisSuccess = 'Ideia salva no Cofre.');
        },
        onOpportunitiesGenerated: () {
          ref.invalidate(ecosystemScoresProvider);
          if (mounted) setState(() => _analysisSuccess = 'Ideia analisada. Scores atualizados.');
        },
      ),
    );
  }

  Future<void> _evaluateIdea() async {
    if (_evaluating) return;
    setState(() { _evaluating = true; _evaluationError = null; });
    try {
      final allProjects = ref.read(projectsNotifierProvider).valueOrNull ?? [];
      final context = allProjects
          .where((p) => p.id != widget.project.id && !p.isIdea)
          .take(5)
          .map((p) => {'title': p.name, 'content': p.description})
          .toList();

      final response = await Supabase.instance.client.functions.invoke(
        'generate-project-opportunities',
        body: {
          'project_name':        widget.project.name,
          'project_description': widget.project.description,
          'project_type':        widget.project.type,
          'documents':           context,
          'market_context':
              'Esta é uma ideia em avaliação estratégica. Compare com os projetos existentes.',
        },
      );

      if (response.data == null) throw Exception('Sem resposta da IVE');

      final data = Map<String, dynamic>.from(response.data as Map);
      await ref
          .read(projectsNotifierProvider.notifier)
          .saveIveEvaluation(widget.project.id, data);

      if (mounted) setState(() => _localEvaluation = data);
    } catch (e) {
      if (mounted) {
        setState(() => _evaluationError =
            'Erro na avaliação: ${e.toString().replaceAll('Exception: ', '')}');
      }
    } finally {
      if (mounted) setState(() => _evaluating = false);
    }
  }

  Future<void> _promoteToProject() async {
    try {
      await ref
          .read(projectsNotifierProvider.notifier)
          .promoteToProject(widget.project.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _analysisError = 'Erro ao promover: $e');
    }
  }

  void _showProjectLinker() {
    final allProjects = ref.read(projectsNotifierProvider).valueOrNull ?? [];
    final realProjects =
        allProjects.where((p) => !p.isIdea && p.id != widget.project.id).toList();

    if (realProjects.isEmpty) {
      setState(() => _analysisError =
          'Nenhum projeto real disponível para vincular. Crie um projeto primeiro.');
      return;
    }

    showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E1B2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text('Vincular ideia a qual projeto?',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ),
            const Divider(color: Color(0xFF333355), height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: realProjects
                    .map((p) => ListTile(
                          leading: const Icon(Icons.rocket_launch_rounded,
                              color: Color(0xFF6BCB77), size: 20),
                          title: Text(p.name,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13)),
                          subtitle: p.description.isNotEmpty
                              ? Text(p.description,
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)
                              : null,
                          onTap: () => Navigator.of(ctx).pop(p.id),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ).then((linkedId) async {
      if (linkedId != null && mounted) {
        try {
          await ref
              .read(projectsNotifierProvider.notifier)
              .linkIdeaToProject(widget.project.id, linkedId);
          if (mounted) Navigator.of(context).pop();
        } catch (e) {
          if (mounted) setState(() => _analysisError = 'Erro ao vincular: $e');
        }
      }
    });
  }

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
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12))),
                  ],
                ),
              ))
          .toList();

  @override
  Widget build(BuildContext context) {
    // Reactive: sheet updates automatically after _analyzeProject invalidates.
    final asyncScores = ref.watch(ecosystemScoresProvider);
    final allScores   = asyncScores.valueOrNull ?? const <EcosystemScore>[];
    EcosystemScore? s;
    for (final score in allScores) {
      if (score.project.id == widget.project.id) {
        s = score;
        break;
      }
    }

    final asyncKnowledge = ref.watch(
        knowledgeItemsByProjectProvider(widget.project.id));
    final linkedItems = asyncKnowledge.valueOrNull ?? const <KnowledgeItem>[];

    final bool noData = s == null || !s.hasEnoughData;

    final String analyzeLabel = s == null
        ? 'ANALISAR PROJETO'
        : !s.hasEnoughData
            ? 'COMPLETAR ANÁLISE'
            : 'REANALISAR';

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.project.isIdea)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFAB83FF).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color:
                                      const Color(0xFFAB83FF).withOpacity(0.4)),
                            ),
                            child: const Text('💡 SOMENTE IDEIA',
                                style: TextStyle(
                                    color: Color(0xFFAB83FF),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.4)),
                          ),
                        ),
                      Text(widget.project.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18)),
                    ],
                  ),
                ),
                if (s != null && s.hasEnoughData)
                  Column(
                    children: [
                      Text('${s.ecosystemScore}',
                          style: TextStyle(
                              color: _ecoScoreColor(s.ecosystemScore),
                              fontSize: 28,
                              fontWeight: FontWeight.bold)),
                      const Text('eco score',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 10)),
                    ],
                  ),
              ],
            ),
            if (widget.project.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(widget.project.description,
                  style:
                      const TextStyle(color: Colors.white60, fontSize: 13)),
            ],
            if (widget.project.url != null) ...[
              const SizedBox(height: 4),
              Text(widget.project.url!,
                  style: const TextStyle(
                      color: Color(0xFF6C63FF), fontSize: 12)),
            ],
            const SizedBox(height: 16),

            // ── Aviso de dados insuficientes ──────────────────────
            if (noData) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD93D).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFFFD93D).withOpacity(0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: Color(0xFFFFD93D), size: 16),
                        SizedBox(width: 6),
                        Text('Dados insuficientes para análise',
                            style: TextStyle(
                                color: Color(0xFFFFD93D),
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Vincule itens do Cofre de Conhecimento a este projeto '
                      'e toque em "Analisar Projeto" para gerar scores reais.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Recomendação ──────────────────────────────────────
            if (s != null) ...[
              _sectionTitle('Recomendação IA'),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFAB83FF).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFAB83FF).withOpacity(0.3)),
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
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Score breakdown
              _sectionTitle('Scores do Ecossistema'),
              _ScoreRow('Oportunidade',    s.opportunityScore,
                  showDash: !s.hasEnoughData),
              _ScoreRow('Fit Estratégico', s.strategicFit,
                  showDash: !s.hasEnoughData),
              _ScoreRow('Sinergia',        s.synergyScore,
                  showDash: !s.hasEnoughData),
              _ScoreRow('ROI',             s.roiScore,
                  showDash: !s.hasRoiData || !s.hasEnoughData),
              _ScoreRow('Momentum',        s.momentumScore,
                  showDash: !s.hasEnoughData),
              _ScoreRow('Mercado',         s.marketScore,
                  showDash: !s.hasEnoughData),
              _ScoreRow('Execução',        s.executionScore,
                  showDash: !s.hasEnoughData),
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
                        value: '${widget.project.opportunityScore}',
                        color: const Color(0xFF00BCD4)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricTile(
                        label: 'Complexidade',
                        value: '${widget.project.complexityScore}',
                        color: const Color(0xFFFFD93D)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricTile(
                        label: 'Potencial',
                        value: _fmtRevenue(widget.project.revenuePotential),
                        color: const Color(0xFF6BCB77)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Pontos fortes
            if (s != null && s.strengths.isNotEmpty) ...[
              _sectionTitle('Pontos Fortes'),
              ..._bullets(s.strengths, const Color(0xFF6BCB77), '✓ '),
              const SizedBox(height: 12),
            ],

            // Riscos
            if (s != null && s.risks.isNotEmpty) ...[
              _sectionTitle('Riscos'),
              ..._bullets(s.risks, const Color(0xFFFF6B6B), '⚠ '),
              const SizedBox(height: 12),
            ],

            // Quick wins
            if (s != null && s.quickWins.isNotEmpty) ...[
              _sectionTitle('Quick Wins'),
              ..._bullets(s.quickWins, const Color(0xFFFFD93D), '⚡ '),
              const SizedBox(height: 12),
            ],

            // Next actions (from detailsJson)
            if (widget.project.nextActions.isNotEmpty) ...[
              _sectionTitle('Próximas Ações'),
              ..._bullets(
                  widget.project.nextActions, const Color(0xFFAB83FF), '→ '),
              const SizedBox(height: 12),
            ],

            // ── Feedback inline análise ──────────────────────────
            if (_analysisError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFFFF6B6B).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Color(0xFFFF6B6B), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_analysisError!,
                            style: const TextStyle(
                                color: Color(0xFFFF6B6B), fontSize: 12)),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _analysisError = null),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white38, size: 14),
                      ),
                    ],
                  ),
                ),
              ),
            if (_analysisSuccess != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6BCB77).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF6BCB77).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          color: Color(0xFF6BCB77), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_analysisSuccess!,
                            style: const TextStyle(
                                color: Color(0xFF6BCB77), fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Conhecimento Vinculado ────────────────────────────
            const Divider(color: Color(0xFF333355)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('CONHECIMENTO VINCULADO',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8)),
                // Tap target mínimo de 44x44 para uso em dispositivo real.
                InkWell(
                  onTap: () => _showKnowledgeSelector(linkedItems),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded,
                            size: 14, color: Color(0xFF6BCB77)),
                        SizedBox(width: 4),
                        Text('ADICIONAR',
                            style: TextStyle(
                                color: Color(0xFF6BCB77),
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (asyncKnowledge.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (linkedItems.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Nenhum item vinculado. Adicione itens do Cofre para enriquecer a análise.',
                  style:
                      TextStyle(color: Colors.white38, fontSize: 12),
                ),
              )
            else
              ...linkedItems.map((item) => _KnowledgeItemTile(
                    item: item,
                    onRemove: () => _unlinkItem(item),
                  )),
            const SizedBox(height: 12),

            const Divider(color: Color(0xFF333355)),
            const SizedBox(height: 12),

            // ── Action buttons ────────────────────────────────────
            IveProjectAskButton(
              project: widget.project,
              ecosystemScore: s,
              knowledgeItems: linkedItems,
            ),
            const SizedBox(height: 8),

            // IVE Idea Intake
            _SheetButton(
              icon: Icons.lightbulb_outline_rounded,
              label: 'ANALISAR IDEIA COM IVE',
              color: const Color(0xFFAB83FF),
              onTap: () => _openIdeaIntake(),
            ),
            const SizedBox(height: 8),

            // Analisar / Reanalisar
            _analyzing
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        children: [
                          CircularProgressIndicator(
                              color: Color(0xFF6BCB77)),
                          SizedBox(height: 8),
                          Text('Analisando com IA...',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                  )
                : _SheetButton(
                    icon: Icons.auto_awesome_rounded,
                    label: analyzeLabel,
                    color: const Color(0xFF6BCB77),
                    onTap: _analyzeProject,
                  ),
            const SizedBox(height: 8),
            if (widget.onAnalyze != null)
              _SheetButton(
                icon: Icons.analytics_rounded,
                label: 'Ver Análise de Mercado',
                color: const Color(0xFF00BCD4),
                onTap: widget.onAnalyze!,
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _SheetButton(
                    icon: Icons.play_arrow_rounded,
                    label: 'Ativar',
                    color: const Color(0xFF6BCB77),
                    onTap: () => widget.onStatusChange('active'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SheetButton(
                    icon: Icons.pause_rounded,
                    label: 'Pausar',
                    color: const Color(0xFFFFD93D),
                    onTap: () => widget.onStatusChange('paused'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SheetButton(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Concluir',
                    color: const Color(0xFF4D96FF),
                    onTap: () => widget.onStatusChange('completed'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ── Ideia — Avaliação e Decisão ──────────────────────
            if (widget.project.isIdea) ...[
              const SizedBox(height: 4),
              const Divider(color: Color(0xFF333355)),
              const SizedBox(height: 8),
              const Text('AVALIAÇÃO DA IDEIA',
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8)),
              const SizedBox(height: 8),
              if (_evaluating)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: Color(0xFFAB83FF)),
                        SizedBox(height: 8),
                        Text('IVE avaliando ideia...',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                )
              else if (_evaluationError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B6B).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFFFF6B6B).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Color(0xFFFF6B6B), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_evaluationError!,
                              style: const TextStyle(
                                  color: Color(0xFFFF6B6B), fontSize: 12)),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _evaluationError = null),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white38, size: 14),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Builder(builder: (_) {
                  final eval =
                      _localEvaluation ?? widget.project.iveEvaluation;
                  final opps =
                      (eval['opportunities'] as List<dynamic>?) ?? [];
                  if (opps.isEmpty) {
                    return _SheetButton(
                      icon: Icons.psychology_rounded,
                      label: 'AVALIAR IDEIA COM IVE',
                      color: const Color(0xFFAB83FF),
                      onTap: _evaluateIdea,
                    );
                  }
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFAB83FF).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFFAB83FF).withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded,
                                color: Color(0xFFAB83FF), size: 14),
                            SizedBox(width: 6),
                            Text('Avaliação da IVE',
                                style: TextStyle(
                                    color: Color(0xFFAB83FF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...opps.take(3).map((raw) {
                          final opp = raw as Map<String, dynamic>;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('⚡ ',
                                    style: TextStyle(fontSize: 11)),
                                Expanded(
                                  child: Text(
                                    opp['title'] as String? ?? '',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _evaluateIdea,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Reavaliar',
                              style: TextStyle(
                                  color: Color(0xFFAB83FF), fontSize: 11)),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 12),
              const Text('DECISÃO',
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _SheetButton(
                      icon: Icons.rocket_launch_rounded,
                      label: 'Transformar',
                      color: const Color(0xFF6BCB77),
                      onTap: _promoteToProject,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SheetButton(
                      icon: Icons.link_rounded,
                      label: 'Vincular',
                      color: const Color(0xFF00BCD4),
                      onTap: _showProjectLinker,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            _SheetButton(
              icon: Icons.delete_outline_rounded,
              label: widget.project.isIdea ? 'Excluir Ideia' : 'Excluir Projeto',
              color: const Color(0xFFFF6B6B),
              onTap: widget.onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

@visibleForTesting
class IveProjectAskButton extends StatelessWidget {
  const IveProjectAskButton({
    super.key,
    required this.project,
    this.ecosystemScore,
    this.knowledgeItems = const [],
  });

  final Project project;
  final EcosystemScore? ecosystemScore;
  final List<KnowledgeItem> knowledgeItems;

  @override
  Widget build(BuildContext context) {
    final score = ecosystemScore;
    final knowledgeContext = knowledgeItems.isEmpty
        ? null
        : knowledgeItems
            .take(3)
            .map((i) => {
                  'title': i.title,
                  'excerpt': i.content.length > 200
                      ? i.content.substring(0, 200)
                      : i.content,
                })
            .toList();

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const ValueKey('ive-project-ask-cta'),
        onPressed: () => openIveWithContext(
          context,
          screenName: 'Detalhe do Projeto',
          projectId: project.id,
          route: AppConstants.routeProjects,
          contextData: CopilotContextData(
            userId: project.userId,
            projectId: project.id,
            route: AppConstants.routeProjects,
            project: {
              'id': project.id,
              'name': project.name,
              'status': project.status,
              if (knowledgeContext != null)
                'knowledge_context': knowledgeContext,
            },
            scores: score == null
                ? null
                : {
                    'ecosystem': score.ecosystemScore,
                    'opportunity': score.opportunityScore,
                    'strategic_fit': score.strategicFit,
                    'synergy': score.synergyScore,
                    'roi': score.roiScore,
                    'momentum': score.momentumScore,
                    'market': score.marketScore,
                    'execution': score.executionScore,
                  },
          ),
          inputHint: 'Pergunte algo sobre este projeto...',
          selectedEntityType: 'project',
          selectedEntityId: project.id,
          selectedEntityLabel: 'Projeto — ${project.name}',
        ),
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('Perguntar à IVE sobre este projeto'),
      ),
    );
  }
}

// ── Score row com barra de progresso ─────────────────────────────────────────

class _ScoreRow extends StatelessWidget {
  const _ScoreRow(this.label, this.value, {this.showDash = false});
  final String label;
  final int value;
  final bool showDash;

  Color get _color {
    if (value >= 70) return const Color(0xFF6BCB77);
    if (value >= 40) return const Color(0xFFFFD93D);
    return const Color(0xFFFF6B6B);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style:
                    const TextStyle(color: Colors.white60, fontSize: 12)),
          ),
          Expanded(
            child: showDash
                ? const SizedBox.shrink()
                : ClipRRect(
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
            child: Text(
                showDash ? '—' : '$value',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: showDash ? Colors.white38 : _color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
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

// ── Knowledge item tile (linked items list) ───────────────────────────────────

class _KnowledgeItemTile extends StatelessWidget {
  const _KnowledgeItemTile({required this.item, required this.onRemove});

  final KnowledgeItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.auto_stories_rounded,
              color: Color(0xFF6C63FF), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.title,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Row(
                children: [
                  Icon(Icons.link_off_rounded,
                      color: Colors.white38, size: 14),
                  SizedBox(width: 2),
                  Text('remover',
                      style:
                          TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Knowledge selector bottom sheet ──────────────────────────────────────────

class _KnowledgeSelectorSheet extends StatelessWidget {
  const _KnowledgeSelectorSheet({
    required this.items,
    required this.onSelect,
    this.currentProjectId,
  });

  final List<KnowledgeItem> items;
  final Future<void> Function(KnowledgeItem) onSelect;
  final String? currentProjectId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (_, ctrl) => Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Selecionar do Cofre',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF333355), height: 1),
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  final isElsewhere =
                      item.projectId != null &&
                      item.projectId != currentProjectId;
                  return ListTile(
                    leading: const Icon(Icons.auto_stories_rounded,
                        color: Color(0xFF6C63FF), size: 20),
                    title: Text(item.title,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13)),
                    subtitle: isElsewhere
                        ? const Text('Vinculado a outro projeto — será movido',
                            style: TextStyle(
                                color: Color(0xFFFFD93D), fontSize: 10))
                        : item.sourceType.isNotEmpty
                            ? Text(item.sourceType,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 11))
                            : null,
                    trailing: const Icon(Icons.add_link_rounded,
                        color: Color(0xFF6BCB77), size: 18),
                    onTap: () => onSelect(item),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── IVE Idea Intake Sheet ─────────────────────────────────────────────────────

class _IdeaIntakeSheet extends ConsumerStatefulWidget {
  const _IdeaIntakeSheet({
    required this.project,
    required this.onIdeaSaved,
    required this.onOpportunitiesGenerated,
  });

  final Project project;
  final VoidCallback onIdeaSaved;
  final VoidCallback onOpportunitiesGenerated;

  @override
  ConsumerState<_IdeaIntakeSheet> createState() => _IdeaIntakeSheetState();
}

class _IdeaIntakeSheetState extends ConsumerState<_IdeaIntakeSheet> {
  final _ideaCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _ideaCtrl.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final text = _ideaCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() { _loading = true; _error = null; _result = null; });

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'generate-project-opportunities',
        body: {
          'project_name':        widget.project.name,
          'project_description': text,
          'project_type':        widget.project.type,
          'documents':           [],
          'market_context':      'Ideia submetida pelo usuário para análise estratégica.',
        },
      );
      if (response.data == null) throw Exception('Sem resposta da IA');
      setState(() => _result = Map<String, dynamic>.from(response.data as Map));
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAsIdea() async {
    final text = _ideaCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      await ref.read(knowledgeServiceProvider).create(KnowledgeItem(
        id:        '',
        userId:    uid,
        projectId: widget.project.id,
        title:     text.length > 60 ? '${text.substring(0, 57)}...' : text,
        sourceType: 'manual',
        content:   text,
        status:    'pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      widget.onIdeaSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = 'Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveOpportunities() async {
    final data = _result;
    if (data == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final uid  = Supabase.instance.client.auth.currentUser!.id;
      final text = _ideaCtrl.text.trim();
      // Save idea as knowledge item
      await ref.read(knowledgeServiceProvider).create(KnowledgeItem(
        id:        '',
        userId:    uid,
        projectId: widget.project.id,
        title:     text.length > 60 ? '${text.substring(0, 57)}...' : text,
        sourceType: 'manual',
        content:   text,
        status:    'pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      // Save opportunities to lab
      final opps = (data['opportunities'] as List<dynamic>?) ?? [];
      final lab  = ref.read(opportunityLabNotifierProvider.notifier);
      for (final raw in opps) {
        final opp = raw as Map<String, dynamic>;
        await lab.add(OpportunityLabItem(
          id:               '',
          userId:           uid,
          projectId:        widget.project.id,
          opportunityType:  opp['opportunity_type'] as String? ?? 'ideia',
          title:            opp['title'] as String? ?? '',
          description:      opp['description'] as String? ?? '',
          marketScore:      (opp['market_score'] as num?)?.toInt() ?? 0,
          revenueScore:     (opp['revenue_score'] as num?)?.toInt() ?? 0,
          competitionScore: (opp['competition_score'] as num?)?.toInt() ?? 0,
          synergyScore:     (opp['synergy_score'] as num?)?.toInt() ?? 0,
          strategicFit:     (opp['strategic_fit'] as num?)?.toInt() ?? 0,
          finalScore:       (opp['final_score'] as num?)?.toInt() ?? 0,
          status:           'pending',
          createdAt:        DateTime.now(),
          origin:           'ia-idea-intake',
        ));
      }
      widget.onOpportunitiesGenerated();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = 'Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded,
                      color: Color(0xFFAB83FF), size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Analisar Ideia com IVE',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Projeto: ${widget.project.name}',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ideaCtrl,
                maxLines: 5,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Descreva sua ideia em detalhes...',
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF0F0F1A),
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF333355)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFAB83FF)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(_error!,
                      style: const TextStyle(
                          color: Color(0xFFFF6B6B), fontSize: 12)),
                ),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: Color(0xFFAB83FF)),
                        SizedBox(height: 8),
                        Text('IVE analisando ideia...',
                            style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                )
              else if (_result != null) ...[
                // Show analysis result
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFAB83FF).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFAB83FF).withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded,
                              color: Color(0xFFAB83FF), size: 14),
                          SizedBox(width: 6),
                          Text('Análise da IVE',
                              style: TextStyle(
                                  color: Color(0xFFAB83FF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...(_result!['opportunities'] as List<dynamic>? ?? [])
                          .take(3)
                          .map((raw) {
                        final opp = raw as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('⚡ ',
                                  style: TextStyle(fontSize: 12)),
                              Expanded(
                                child: Text(
                                  opp['title'] as String? ?? '',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saveAsIdea,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white54,
                          side: const BorderSide(color: Color(0xFF333355)),
                        ),
                        child: const Text('Salvar Ideia', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _saveOpportunities,
                        icon: const Icon(Icons.rocket_launch_rounded, size: 14),
                        label: const Text('Vincular ao Projeto',
                            style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFAB83FF),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _ideaCtrl.text.trim().isEmpty ? null : _analyze,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                    label: const Text('Analisar com IVE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFAB83FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _ideaCtrl.text.trim().isEmpty ? null : _saveAsIdea,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(color: Color(0xFF333355)),
                    ),
                    child: const Text('Salvar como Ideia no Cofre'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
