import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/project.dart';
import '../../../providers/project_provider.dart';
import '../../../shared/widgets/app_drawer.dart';

class ProjectCommandCenterScreen extends ConsumerStatefulWidget {
  const ProjectCommandCenterScreen({super.key});

  @override
  ConsumerState<ProjectCommandCenterScreen> createState() =>
      _ProjectCommandCenterScreenState();
}

class _ProjectCommandCenterScreenState
    extends ConsumerState<ProjectCommandCenterScreen> {
  bool _showForm = false;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  String _type = 'website';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncProjects = ref.watch(projectsNotifierProvider);

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
        title: const Text('Project Command Center', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
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
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6BCB77))),
              error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: Colors.redAccent))),
              data: (projects) => projects.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.rocket_launch_outlined, color: Colors.white24, size: 64),
                          const SizedBox(height: 16),
                          const Text('Nenhum projeto ainda', style: TextStyle(color: Colors.white38, fontSize: 16)),
                          const SizedBox(height: 8),
                          const Text('Adicione seu primeiro projeto', style: TextStyle(color: Colors.white24, fontSize: 13)),
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
                    )
                  : _buildProjectList(projects),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6BCB77).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Novo Projeto', style: TextStyle(color: Color(0xFF6BCB77), fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _Field(controller: _nameCtrl, label: 'Nome do projeto *', hint: 'Ex: Blog de Finanças Pessoais'),
          const SizedBox(height: 10),
          _Field(controller: _descCtrl, label: 'Descrição', hint: 'Descreva o projeto brevemente'),
          const SizedBox(height: 10),
          _Field(controller: _urlCtrl, label: 'URL (opcional)', hint: 'https://...'),
          const SizedBox(height: 10),
          // Type selector
          const Text('Tipo', style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: ['website', 'app', 'product', 'service', 'content'].map(
              (t) => ChoiceChip(
                label: Text(t),
                selected: _type == t,
                onSelected: (_) => setState(() => _type = t),
                selectedColor: const Color(0xFF6BCB77),
                labelStyle: TextStyle(color: _type == t ? Colors.black : Colors.white60, fontSize: 12),
                backgroundColor: const Color(0xFF0F0F1A),
                side: BorderSide(color: _type == t ? const Color(0xFF6BCB77) : const Color(0xFF333355)),
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
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Text('Salvar', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProjectList(List<Project> projects) {
    final sorted = [...projects]..sort((a, b) => b.priorityScore.compareTo(a.priorityScore));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      itemBuilder: (_, i) => _ProjectCard(
        project: sorted[i],
        rank: i + 1,
        onStatusChange: (status) =>
            ref.read(projectsNotifierProvider.notifier).updateStatus(sorted[i].id, status),
        onDelete: () => _confirmDelete(sorted[i]),
        onAnalyze: sorted[i].marketAnalysisId != null
            ? () => context.go(
                AppConstants.routeMarketIntelligenceHub
                    .replaceFirst(':id', sorted[i].marketAnalysisId!))
            : null,
      ),
    );
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
      ref.read(projectsNotifierProvider.notifier).delete(project.id);
    }
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label, required this.hint});
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.rank,
    required this.onStatusChange,
    required this.onDelete,
    this.onAnalyze,
  });

  final Project project;
  final int rank;
  final void Function(String) onStatusChange;
  final VoidCallback onDelete;
  final VoidCallback? onAnalyze;

  Color get _statusColor {
    switch (project.status) {
      case 'active': return const Color(0xFF6BCB77);
      case 'completed': return const Color(0xFF4D96FF);
      case 'paused': return const Color(0xFFFFD93D);
      default: return Colors.white38;
    }
  }

  String get _statusLabel {
    switch (project.status) {
      case 'active': return 'Ativo';
      case 'completed': return 'Concluído';
      case 'paused': return 'Pausado';
      default: return 'Ideia';
    }
  }

  String _fmtRevenue(double v) {
    if (v >= 1000000) return 'R\$ ${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return 'R\$ ${(v / 1000).toStringAsFixed(0)}K';
    return 'R\$ ${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
                            style: const TextStyle(color: Color(0xFF6BCB77), fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(project.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _statusColor.withOpacity(0.5)),
                      ),
                      child: Text(_statusLabel,
                          style: TextStyle(color: _statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                if (project.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 38),
                    child: Text(project.description,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    _StatChip(label: 'Oportunidade', value: '${project.opportunityScore}', color: const Color(0xFF00BCD4)),
                    const SizedBox(width: 8),
                    _StatChip(label: 'Potencial', value: _fmtRevenue(project.revenuePotential), color: const Color(0xFFFFD93D)),
                    const SizedBox(width: 8),
                    _StatChip(label: 'Prazo', value: '${project.timeToRevenueDays}d', color: const Color(0xFFAB83FF)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF333355), height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                if (onAnalyze != null)
                  _ActionBtn(icon: Icons.analytics_rounded, label: 'Análise', color: const Color(0xFF00BCD4), onTap: onAnalyze!),
                _ActionBtn(
                  icon: Icons.play_arrow_rounded,
                  label: 'Ativar',
                  color: const Color(0xFF6BCB77),
                  onTap: () => onStatusChange('active'),
                ),
                _ActionBtn(
                  icon: Icons.pause_rounded,
                  label: 'Pausar',
                  color: const Color(0xFFFFD93D),
                  onTap: () => onStatusChange('paused'),
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
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.color});
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
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});
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
