import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/content_item.dart';
import '../../../providers/content_provider.dart';
import '../../../shared/widgets/app_drawer.dart';

class ContentLibraryScreen extends ConsumerStatefulWidget {
  const ContentLibraryScreen({super.key});

  @override
  ConsumerState<ContentLibraryScreen> createState() => _ContentLibraryScreenState();
}

class _ContentLibraryScreenState extends ConsumerState<ContentLibraryScreen> {
  String? _selectedType;

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(contentItemsProvider);

    return Scaffold(
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
        title: const Text('Biblioteca de Conteúdo'),
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppConstants.routeContentNew),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo Item'),
        backgroundColor: const Color(0xFF6C63FF),
      ),
      body: Column(
        children: [
          // Filtro por tipo
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _TypeChip(
                  label: 'Todos',
                  selected: _selectedType == null,
                  onTap: () => setState(() => _selectedType = null),
                ),
                ...ContentItem.types.map((t) => _TypeChip(
                      label: ContentItem.typeLabels[t] ?? t,
                      selected: _selectedType == t,
                      onTap: () => setState(() => _selectedType = t),
                    )),
              ],
            ),
          ),
          Expanded(
            child: itemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:   (e, _) => Center(
                child: Text('Erro: $e', style: const TextStyle(color: Colors.white54)),
              ),
              data: (items) {
                final filtered = _selectedType == null
                    ? items
                    : items.where((i) => i.type == _selectedType).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.library_books_rounded,
                            size: 64, color: Colors.white24),
                        const SizedBox(height: 12),
                        Text(
                          _selectedType == null
                              ? 'Biblioteca vazia.'
                              : 'Nenhum item deste tipo.',
                          style: const TextStyle(color: Colors.white54),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Adicione itens usando o botão abaixo.',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _ContentCard(
                    item: filtered[i],
                    ref: ref,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String  label;
  final bool    selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Chip(
          label: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white54,
              fontSize: 12,
            ),
          ),
          backgroundColor: selected
              ? const Color(0xFF6C63FF)
              : Colors.white.withOpacity(0.07),
          side: BorderSide(
            color: selected ? const Color(0xFF6C63FF) : Colors.white12,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.item, required this.ref});
  final ContentItem item;
  final WidgetRef   ref;

  @override
  Widget build(BuildContext context) {
    final typeLabel = ContentItem.typeLabels[item.type] ?? item.type;
    final typeColor = _typeColor(item.type);

    return Card(
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.white12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(
          AppConstants.routeContentEdit.replaceAll(':id', item.id),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: typeColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      typeLabel,
                      style: TextStyle(
                        color: typeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        color: Colors.white38, size: 18),
                    color: const Color(0xFF1A1A2E),
                    onSelected: (value) async {
                      if (value == 'delete') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Excluir item'),
                            content: Text('Deseja excluir "${item.title}"?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Excluir',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await ref
                              .read(contentNotifierProvider.notifier)
                              .delete(item.id);
                          ref.invalidate(contentItemsProvider);
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Excluir',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              if (item.description != null && item.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  item.description!,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (item.niche != null && item.niche!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.tag_rounded,
                        color: Colors.white24, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      item.niche!,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'produto': return const Color(0xFF6C63FF);
      case 'campanha': return const Color(0xFFB44FE8);
      case 'marca': return const Color(0xFFFFD700);
      case 'livro':
      case 'ebook': return Colors.teal;
      default: return Colors.white54;
    }
  }
}
