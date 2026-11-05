import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/content_item.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/content_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../core/utils/snackbar_utils.dart' show extractErrorMessage;
import 'package:ai_social_copilot/core/theme/app_tokens.dart';

class ContentLibraryScreen extends ConsumerStatefulWidget {
  const ContentLibraryScreen({super.key});

  @override
  ConsumerState<ContentLibraryScreen> createState() =>
      _ContentLibraryScreenState();
}

class _ContentLibraryScreenState extends ConsumerState<ContentLibraryScreen> {
  String? _selectedType;
  String? _projectId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final itemsAsync = _projectId != null
        ? ref.watch(contentItemsByProjectProvider(_projectId!))
        : ref.watch(contentItemsProvider);

    final projectsAsync = ref.watch(projectsNotifierProvider);
    final projects = projectsAsync.valueOrNull ?? [];

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
        title: Text(l10n.contentLibraryTitle),
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppConstants.routeContentNew),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.contentLibraryNewItem),
        backgroundColor: AppColors.accent,
      ),
      body: Column(
        children: [
          // ── Filtro por projeto ────────────────────────────────
          if (projects.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: [
                  _FilterChip(
                    label: l10n.commonAll,
                    selected: _projectId == null,
                    onTap: () => setState(() => _projectId = null),
                  ),
                  ...projects.map((p) => _FilterChip(
                        label: p.name,
                        selected: _projectId == p.id,
                        onTap: () => setState(() => _projectId = p.id),
                      )),
                ],
              ),
            ),

          // ── Filtro por tipo ───────────────────────────────────
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                _TypeChip(
                  label: l10n.commonAll,
                  selected: _selectedType == null,
                  onTap: () => setState(() => _selectedType = null),
                ),
                ...ContentItem.types.map((t) => _TypeChip(
                      label: ContentItem.localizedTypeLabel(t, l10n),
                      selected: _selectedType == t,
                      onTap: () => setState(() => _selectedType = t),
                    )),
              ],
            ),
          ),

          Expanded(
            child: itemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(l10n.commonError,
                    style: const TextStyle(color: AppColors.inkMuted)),
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
                            size: 64, color: AppColors.inkSubtle),
                        const SizedBox(height: 12),
                        Text(
                          _selectedType != null
                              ? l10n.contentLibraryEmptyType
                              : _projectId != null
                                  ? l10n.contentLibraryEmptyProject
                                  : l10n.contentLibraryEmpty,
                          style: const TextStyle(color: AppColors.inkMuted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.contentLibraryEmptyHint,
                          style: const TextStyle(
                              color: AppColors.inkSubtle, fontSize: 12),
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
                    projectName: _projectId != null
                        ? null
                        : projects
                            .where((p) => p.id == filtered[i].projectId)
                            .map((p) => p.name)
                            .firstOrNull,
                    onDeleted: () {
                      if (_projectId != null) {
                        ref.invalidate(
                            contentItemsByProjectProvider(_projectId!));
                      } else {
                        ref.invalidate(contentItemsProvider);
                      }
                    },
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

// ── Project filter chip ───────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
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
                color: selected ? AppColors.ink : AppColors.inkMuted,
                fontSize: 12,
              )),
          backgroundColor: selected
              ? AppColors.accent
              : AppColors.ink.withOpacity(0.07),
          side: BorderSide(
              color: selected ? AppColors.accent : AppColors.line),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

// ── Type filter chip ──────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
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
              color: selected ? AppColors.ink : AppColors.inkMuted,
              fontSize: 12,
            ),
          ),
          backgroundColor: selected
              ? AppColors.accent
              : AppColors.ink.withOpacity(0.07),
          side: BorderSide(
            color: selected ? AppColors.accent : AppColors.line,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

// ── Content card ──────────────────────────────────────────────────────────────

class _ContentCard extends StatelessWidget {
  const _ContentCard({
    required this.item,
    required this.ref,
    required this.onDeleted,
    this.projectName,
  });

  final ContentItem item;
  final WidgetRef ref;
  final VoidCallback onDeleted;
  final String? projectName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final typeLabel = ContentItem.localizedTypeLabel(item.type, l10n);
    final typeColor = _typeColor(item.type);

    return Card(
      color: AppColors.ink.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppRadius.md),
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
                  if (projectName != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                            color: AppColors.accent.withOpacity(0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.folder_rounded,
                              size: 10, color: AppColors.accent),
                          const SizedBox(width: 3),
                          Text(
                            projectName!,
                            style: const TextStyle(
                                color: AppColors.accent, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        color: AppColors.inkSubtle, size: 18),
                    color: AppColors.surface,
                    onSelected: (value) async {
                      if (value == 'delete') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(l10n.contentLibraryDeleteTitle),
                            content: Text(
                                l10n.contentLibraryDeleteConfirm(item.title)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(l10n.commonCancel),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text(l10n.commonDelete,
                                    style: const TextStyle(color: AppColors.negative)),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          try {
                            await ref
                                .read(contentNotifierProvider.notifier)
                                .delete(item.id);
                            onDeleted();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text(l10n.contentLibraryDeleteError(
                                    extractErrorMessage(e, l10n))),
                                backgroundColor: AppColors.negative,
                              ));
                            }
                          }
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(l10n.commonDelete,
                            style: const TextStyle(color: AppColors.negative)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.title,
                style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
              if (item.description != null && item.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  item.description!,
                  style: const TextStyle(color: AppColors.inkMuted, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (item.niche != null && item.niche!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.tag_rounded,
                        color: AppColors.inkSubtle, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      item.niche!,
                      style:
                          const TextStyle(color: AppColors.inkSubtle, fontSize: 11),
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
      case 'produto':
        return AppColors.accent;
      case 'campanha':
        return AppColors.accent;
      case 'marca':
        return AppColors.gold;
      case 'livro':
      case 'ebook':
        return AppColors.accent;
      default:
        return AppColors.inkMuted;
    }
  }
}
