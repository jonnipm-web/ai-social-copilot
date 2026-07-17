import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/knowledge_item.dart';
import '../../../providers/knowledge_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../shared/widgets/app_drawer.dart';

class KnowledgeVaultScreen extends ConsumerStatefulWidget {
  const KnowledgeVaultScreen({super.key});

  @override
  ConsumerState<KnowledgeVaultScreen> createState() =>
      _KnowledgeVaultScreenState();
}

class _KnowledgeVaultScreenState extends ConsumerState<KnowledgeVaultScreen> {
  String? _projectId;

  void _invalidateItems() {
    if (_projectId != null) {
      ref.invalidate(knowledgeItemsByProjectProvider(_projectId!));
    } else {
      ref.invalidate(knowledgeItemsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = _projectId != null
        ? ref.watch(knowledgeItemsByProjectProvider(_projectId!))
        : ref.watch(knowledgeItemsProvider);

    final projectsAsync = ref.watch(projectsNotifierProvider);
    final projects = projectsAsync.valueOrNull ?? [];

    final selectedProjectName = _projectId == null
        ? null
        : projects.where((p) => p.id == _projectId).map((p) => p.name).firstOrNull;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      drawer: const AppDrawer(),
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
        foregroundColor: Colors.white,
        title: const Text(
          'Cofre de Conhecimento',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _invalidateItems,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo Item'),
        onPressed: () => context.push(
          AppConstants.routeKnowledgeNew,
          extra: _projectId != null ? {'projectId': _projectId} : null,
        ),
      ),
      body: Column(
        children: [
          if (projects.isNotEmpty)
            _ProjectFilter(
              projects: projects,
              selectedId: _projectId,
              onSelect: (id) => setState(() => _projectId = id),
            ),
          Expanded(
            child: itemsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Erro: $e',
                    style: const TextStyle(color: Colors.white70)),
              ),
              data: (items) => items.isEmpty
                  ? _EmptyState(
                      projectFiltered: _projectId != null,
                      projectName: selectedProjectName,
                      onAdd: () => context.push(
                        AppConstants.routeKnowledgeNew,
                        extra: _projectId != null
                            ? {'projectId': _projectId}
                            : null,
                      ),
                    )
                  : _ItemList(
                      items: items,
                      onInvalidate: _invalidateItems,
                      projectsMap: {for (final p in projects) p.id: p.name},
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Project filter chips ──────────────────────────────────────────────────────

class _ProjectFilter extends StatelessWidget {
  const _ProjectFilter({
    required this.projects,
    required this.selectedId,
    required this.onSelect,
  });

  final List<dynamic> projects;
  final String?       selectedId;
  final void Function(String?) onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _Chip(
            label: 'Todos',
            selected: selectedId == null,
            onTap: () => onSelect(null),
          ),
          ...projects.map((p) => _Chip(
                label: p.name as String,
                selected: selectedId == p.id,
                onTap: () => onSelect(p.id as String),
              )),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool   selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Chip(
          label: Text(label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontSize: 12,
              )),
          backgroundColor: selected
              ? const Color(0xFF6C63FF)
              : Colors.white.withOpacity(0.07),
          side: BorderSide(
              color: selected ? const Color(0xFF6C63FF) : Colors.white12),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.onAdd,
    this.projectFiltered = false,
    this.projectName,
  });

  final VoidCallback onAdd;
  final bool         projectFiltered;
  final String?      projectName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_stories_rounded,
                size: 72, color: Color(0xFF6C63FF)),
            const SizedBox(height: 16),
            Text(
              projectFiltered
                  ? 'Nenhum item em ${projectName ?? 'este projeto'}'
                  : 'Cofre vazio',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              projectFiltered
                  ? 'Adicione conhecimento a este projeto para que a IA extraia insights personalizados.'
                  : 'Adicione textos, URLs ou arquivos para que a IA extraia insights de marketing, SEO e monetização.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar Conhecimento'),
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Item list ─────────────────────────────────────────────────────────────────

class _ItemList extends StatelessWidget {
  const _ItemList({
    required this.items,
    required this.onInvalidate,
    required this.projectsMap,
  });

  final List<KnowledgeItem>  items;
  final VoidCallback          onInvalidate;
  final Map<String, String>   projectsMap;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _KnowledgeCard(
        item:        items[i],
        onInvalidate: onInvalidate,
        projectName: items[i].projectId == null
            ? null
            : projectsMap[items[i].projectId],
      ),
    );
  }
}

// ── Knowledge card ────────────────────────────────────────────────────────────

class _KnowledgeCard extends ConsumerWidget {
  const _KnowledgeCard({
    required this.item,
    required this.onInvalidate,
    this.projectName,
  });

  final KnowledgeItem item;
  final VoidCallback  onInvalidate;
  final String?       projectName;

  Color get _statusColor {
    switch (item.status) {
      case 'analyzed':   return const Color(0xFF4CAF50);
      case 'processing': return const Color(0xFFFF9800);
      case 'error':      return const Color(0xFFF44336);
      default:           return Colors.white38;
    }
  }

  IconData get _sourceIcon {
    switch (item.sourceType) {
      case 'url':  return Icons.link_rounded;
      case 'file': return Icons.insert_drive_file_rounded;
      default:     return Icons.edit_note_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: const Color(0xFF1A1A2E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: item.status == 'analyzed'
            ? () => context.push(
                  AppConstants.routeKnowledgeAnalysis
                      .replaceFirst(':id', item.id),
                )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_sourceIcon, color: const Color(0xFF6C63FF), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  _StatusChip(status: item.status, color: _statusColor),
                ],
              ),
              if (projectName != null) ...[
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.folder_rounded,
                        color: Color(0xFF6C63FF), size: 12),
                    const SizedBox(width: 4),
                    Text(
                      projectName!,
                      style: const TextStyle(
                          color: Color(0xFF6C63FF), fontSize: 11),
                    ),
                  ],
                ),
              ],
              if (item.niche != null) ...[
                const SizedBox(height: 4),
                Text('Nicho: ${item.niche}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _ActionButton(
                    label: item.status == 'analyzed'
                        ? 'Ver Análise'
                        : item.status == 'processing'
                            ? 'Processando…'
                            : 'Analisar com IA',
                    icon: item.status == 'analyzed'
                        ? Icons.insights_rounded
                        : Icons.auto_awesome_rounded,
                    color: item.status == 'processing'
                        ? Colors.white24
                        : const Color(0xFF6C63FF),
                    enabled: item.status != 'processing',
                    onTap: () async {
                      if (item.status == 'analyzed') {
                        context.push(
                          AppConstants.routeKnowledgeAnalysis
                              .replaceFirst(':id', item.id),
                        );
                        return;
                      }
                      try {
                        final notifier = ref
                            .read(knowledgeAnalysisNotifierProvider.notifier);
                        await notifier.analyze(item);
                        onInvalidate();
                        if (context.mounted) {
                          context.push(
                            AppConstants.routeKnowledgeAnalysis
                                .replaceFirst(':id', item.id),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erro ao analisar: $e'),
                              backgroundColor: const Color(0xFFF44336),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    label: 'Editar',
                    icon: Icons.edit_rounded,
                    color: Colors.white24,
                    onTap: () => context.push(
                      AppConstants.routeKnowledgeEdit
                          .replaceFirst(':id', item.id),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_rounded,
                        color: Colors.white24),
                    iconSize: 20,
                    onPressed: () => _confirmDelete(context, ref),
                    tooltip: 'Excluir',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Excluir item?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'O item "${item.title}" e sua análise serão removidos.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir',
                style: TextStyle(color: Color(0xFFF44336))),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(knowledgeItemNotifierProvider.notifier).delete(item.id);
      onInvalidate();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir: $e'),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    }
  }
}

// ── Status chip ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.color});

  final String status;
  final Color  color;

  String get _label {
    switch (status) {
      case 'analyzed':   return 'Analisado';
      case 'processing': return 'Processando';
      case 'error':      return 'Erro';
      default:           return 'Pendente';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        _label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  final String       label;
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;
  final bool         enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
