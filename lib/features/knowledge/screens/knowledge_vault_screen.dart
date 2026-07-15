import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/knowledge_item.dart';
import '../../../providers/knowledge_provider.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/context_copilot_widget.dart';
import '../../../data/models/copilot_context_data.dart';

class KnowledgeVaultScreen extends ConsumerWidget {
  const KnowledgeVaultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(knowledgeItemsProvider);

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
            onPressed: () => ref.invalidate(knowledgeItemsProvider),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ContextCopilotButton(
            screenName: 'Conhecimento',
            context: CopilotContextData(),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'knowledge_add',
            backgroundColor: const Color(0xFF6C63FF),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Novo Item'),
            onPressed: () => context.push(AppConstants.routeKnowledgeNew),
          ),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Erro: $e', style: const TextStyle(color: Colors.white70)),
        ),
        data: (items) => items.isEmpty
            ? _EmptyState(onAdd: () => context.push(AppConstants.routeKnowledgeNew))
            : _ItemList(items: items),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

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
            const Text(
              'Cofre vazio',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Adicione textos, URLs ou arquivos para que a IA extraia insights de marketing, SEO e monetização.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14),
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

class _ItemList extends StatelessWidget {
  const _ItemList({required this.items});

  final List<KnowledgeItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _KnowledgeCard(item: items[i]),
    );
  }
}

class _KnowledgeCard extends ConsumerWidget {
  const _KnowledgeCard({required this.item});

  final KnowledgeItem item;

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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _StatusChip(status: item.status, color: _statusColor),
                ],
              ),
              if (item.niche != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Nicho: ${item.niche}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
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
                      final notifier =
                          ref.read(knowledgeAnalysisNotifierProvider.notifier);
                      await notifier.analyze(item);
                      ref.invalidate(knowledgeItemsProvider);
                      if (context.mounted) {
                        context.push(
                          AppConstants.routeKnowledgeAnalysis
                              .replaceFirst(':id', item.id),
                        );
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
                    icon:
                        const Icon(Icons.delete_rounded, color: Colors.white24),
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
    if (ok == true) {
      await ref.read(knowledgeItemNotifierProvider.notifier).delete(item.id);
      ref.invalidate(knowledgeItemsProvider);
    }
  }
}

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
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  final String   label;
  final IconData icon;
  final Color    color;
  final VoidCallback onTap;
  final bool     enabled;

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
