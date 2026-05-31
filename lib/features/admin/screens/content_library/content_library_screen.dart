import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../data/models/content_item.dart';
import '../../../../providers/brand_provider.dart';
import '../../../../providers/content_library_provider.dart';
import '../../../../shared/widgets/admin_nav_drawer.dart';
import '../../../../shared/widgets/feature_gate.dart';

class ContentLibraryScreen extends ConsumerStatefulWidget {
  const ContentLibraryScreen({super.key});

  @override
  ConsumerState<ContentLibraryScreen> createState() =>
      _ContentLibraryScreenState();
}

class _ContentLibraryScreenState extends ConsumerState<ContentLibraryScreen> {
  String? _selectedBrandId;

  @override
  Widget build(BuildContext context) {
    final brandsAsync = ref.watch(brandsProvider);
    final itemsAsync = ref.watch(contentLibraryProvider(_selectedBrandId));

    return AdminGuard(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Biblioteca de Conteúdo'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () =>
                  context.push(AppConstants.routeAdminLibraryNew),
            ),
          ],
        ),
        drawer: const AdminNavDrawer(),
        body: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppConstants.maxBodyWidth),
            child: Column(
              children: [
                brandsAsync.whenOrNull(
                      data: (brands) => brands.isNotEmpty
                          ? Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 16, 16, 0),
                              child: DropdownButtonFormField<String?>(
                                value: _selectedBrandId,
                                decoration: const InputDecoration(
                                    labelText: 'Filtrar por Marca'),
                                items: [
                                  const DropdownMenuItem(
                                      value: null,
                                      child: Text('Todas as marcas')),
                                  ...brands.map((b) => DropdownMenuItem(
                                        value: b.id,
                                        child: Text(b.name),
                                      )),
                                ],
                                onChanged: (v) =>
                                    setState(() => _selectedBrandId = v),
                              ),
                            )
                          : null,
                    ) ??
                    const SizedBox.shrink(),
                const SizedBox(height: 8),
                Expanded(
                  child: itemsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                        child: Text('Erro: $e',
                            style: const TextStyle(color: Colors.white54))),
                    data: (items) {
                      if (items.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.library_books_outlined,
                                  size: 48, color: Colors.white12),
                              const SizedBox(height: 16),
                              const Text('Nenhum item na biblioteca',
                                  style: TextStyle(color: Colors.white38)),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: () => context
                                    .push(AppConstants.routeAdminLibraryNew),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Adicionar conteúdo'),
                              ),
                            ],
                          ),
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(contentLibraryProvider),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) =>
                              _ContentCard(item: items[i]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContentCard extends ConsumerWidget {
  final ContentItem item;

  const _ContentCard({required this.item});

  Color get _statusColor => switch (item.status) {
        'draft' => Colors.white38,
        'in_use' => const Color(0xFF6C63FF),
        'used' => Colors.green,
        'archived' => Colors.white24,
        _ => Colors.white38,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            context.push('${AppConstants.routeAdminLibrary}/${item.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      item.statusLabel,
                      style: TextStyle(
                          fontSize: 11,
                          color: _statusColor,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.baseText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 13, color: Colors.white54, height: 1.4),
              ),
              if (item.notes.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  item.notes,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 11, color: Colors.white24),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
