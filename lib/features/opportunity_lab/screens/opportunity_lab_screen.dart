import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/knowledge_item.dart';
import '../../../data/models/opportunity_lab_item.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/action_queue_provider.dart';
import '../../../providers/knowledge_provider.dart';
import '../../../providers/opportunity_lab_provider.dart';
import '../../../providers/feature_flag_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../action_engine/screens/action_detail_screen.dart';
import '../opportunity_type_labels.dart';
import 'opportunity_detail_screen.dart';

// ── Colors ───────────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF0F0F1A);
const _kCard    = Color(0xFF1A1A2E);
const _kPrimary = Color(0xFF6C63FF);
const _kGreen   = Color(0xFF4CAF50);
const _kOrange  = Color(0xFFFF9800);
const _kRed     = Color(0xFFF44336);
const _kGold    = Color(0xFFFFD700);

Color _scoreColor(int s) {
  if (s >= 80) return _kGreen;
  if (s >= 60) return _kOrange;
  return _kRed;
}

// ════════════════════════════════════════════════════════════════════════════
// Opportunity Lab Screen (M4) — Feature-flagged
// ════════════════════════════════════════════════════════════════════════════
class OpportunityLabScreen extends ConsumerStatefulWidget {
  const OpportunityLabScreen({super.key});

  @override
  ConsumerState<OpportunityLabScreen> createState() => _OpportunityLabScreenState();
}

class _OpportunityLabScreenState extends ConsumerState<OpportunityLabScreen> {
  String? _projectId;

  void _setProject(String? id) {
    setState(() => _projectId = id);
    ref.read(opportunityLabNotifierProvider.notifier).load(projectId: id);
  }

  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, r, _) => _AddOpportunityDialog(ref: r, projectId: _projectId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flagAsync = ref.watch(featureFlagProvider(FeatureFlag.opportunityLabEnabled));
    // 'Opportunity Lab' is intentionally identical in PT/EN -- matches the
    // product's own naming decision already recorded in module_registry.dart
    // (namePt == nameEn for this module), not an untranslated string.
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppConstants.routeDashboard),
        ),
        title: const Text(
          'Opportunity Lab',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.oppNewTitle),
        onPressed: () => _showAddDialog(context),
      ),
      body: flagAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _kPrimary)),
        error: (_, __) => _LabBody(projectId: _projectId, onProjectChange: _setProject),
        data: (enabled) => enabled
            ? _LabBody(projectId: _projectId, onProjectChange: _setProject)
            : const _FeatureGated(),
      ),
    );
  }
}

class _FeatureGated extends StatelessWidget {
  const _FeatureGated();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.science_rounded, color: Colors.white24, size: 64),
            const SizedBox(height: 20),
            const Text(
              'Opportunity Lab',
              style: TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'O Opportunity Lab está sendo preparado para lançamento.\nEm breve você poderá gerar e avaliar oportunidades de negócio de forma massiva e inteligente.',
              style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kGold.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kGold.withOpacity(0.25)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.lock_rounded, color: _kGold, size: 28),
                  SizedBox(height: 8),
                  Text('Disponível em breve — Plano Pro',
                      style: TextStyle(
                          color: _kGold,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabBody extends ConsumerWidget {
  const _LabBody({required this.projectId, required this.onProjectChange});
  final String?                 projectId;
  final void Function(String?)  onProjectChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(opportunityLabNotifierProvider);

    return itemsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: _kPrimary)),
      error: (e, _) => Center(
        child: Text('Erro: $e',
            style: const TextStyle(color: Colors.white54)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Column(
            children: [
              _ProjectFilter(selected: projectId, onSelect: onProjectChange),
              Expanded(
                child: _EmptyLab(
                  onAdd: () => showDialog(
                    context: context,
                    builder: (ctx) => Consumer(
                      builder: (ctx, r, _) => _AddOpportunityDialog(ref: r, projectId: projectId),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            _ProjectFilter(selected: projectId, onSelect: onProjectChange),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                itemCount: items.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _LabItemCard(
                    item: items[i],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OpportunityDetailScreen(itemId: items[i].id),
                      ),
                    ),
                    onApprove: () {
                      final opp = items[i];
                      Future(() async {
                        await ref
                            .read(opportunityLabNotifierProvider.notifier)
                            .approve(opp.id);
                        if (!context.mounted) return;
                        try {
                          final action = await ref
                              .read(actionQueueNotifierProvider.notifier)
                              .addFromOpportunityItem(opp);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: const Text('Aprovada e enviada ao Action Engine!'),
                              backgroundColor: const Color(0xFF4CAF50),
                              action: SnackBarAction(
                                label: 'Ver Ação',
                                textColor: Colors.white,
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ActionDetailScreen(itemId: action.id),
                                  ),
                                ),
                              ),
                            ));
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Aprovada, mas erro ao criar ação: $e'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        }
                      });
                    },
                    onDelete: () =>
                        ref.read(opportunityLabNotifierProvider.notifier).delete(items[i].id),
                    onConvertToAction: items[i].status == 'approved'
                        ? () async {
                            try {
                              final action = await ref
                                  .read(actionQueueNotifierProvider.notifier)
                                  .addFromOpportunityItem(items[i]);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: const Text('Ação criada no Action Engine!'),
                                  backgroundColor: const Color(0xFF4CAF50),
                                  action: SnackBarAction(
                                    label: 'Ver',
                                    textColor: Colors.white,
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ActionDetailScreen(itemId: action.id),
                                      ),
                                    ),
                                  ),
                                ));
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          }
                        : null,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LabItemCard extends StatelessWidget {
  const _LabItemCard({
    required this.item,
    required this.onTap,
    required this.onApprove,
    required this.onDelete,
    this.onConvertToAction,
  });
  final OpportunityLabItem item;
  final VoidCallback        onTap;
  final VoidCallback        onApprove;
  final VoidCallback        onDelete;
  final VoidCallback?       onConvertToAction;

  static Color _statusColor(String s) {
    const m = {
      'approved':  Color(0xFF4CAF50),
      'executing': Color(0xFF00BCD4),
      'rejected':  Color(0xFFF44336),
    };
    return m[s] ?? const Color(0xFFFF9800);
  }

  @override
  Widget build(BuildContext context) {
    final score = item.finalScore;
    final c     = _scoreColor(score);

    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  opportunityTypeLabel(item.opportunityType, AppLocalizations.of(context)!).toUpperCase(),
                  style: const TextStyle(
                      color: _kPrimary, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (score > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('$score',
                      style: TextStyle(
                          color: c,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(item.description,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(item.status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.status,
                  style: TextStyle(
                      color: _statusColor(item.status),
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              if (item.status == 'pending')
                TextButton(
                  onPressed: onApprove,
                  style: TextButton.styleFrom(
                      foregroundColor: _kGreen,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: const Text('Aprovar', style: TextStyle(fontSize: 12)),
                ),
              if (item.status == 'approved' && onConvertToAction != null)
                TextButton(
                  onPressed: onConvertToAction,
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF00BCD4),
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: const Text('→ Ação', style: TextStyle(fontSize: 12)),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.white24, size: 18),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white24, size: 18),
            ],
          ),
        ],
      ),
    ),
    );
  }
}

class _EmptyLab extends StatelessWidget {
  const _EmptyLab({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.science_rounded, color: Colors.white24, size: 64),
            const SizedBox(height: 20),
            const Text(
              'Opportunity Lab vazio',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Adicione oportunidades para analisar, priorizar e executar.',
              style: TextStyle(
                  color: Colors.white38, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar Oportunidade'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Project Filter ────────────────────────────────────────────────────────────

class _ProjectFilter extends ConsumerWidget {
  const _ProjectFilter({required this.selected, required this.onSelect});
  final String?                selected;
  final void Function(String?) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);
    return projectsAsync.maybeWhen(
      data: (projects) {
        if (projects.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            children: [
              _Chip(
                label: 'Todos',
                selected: selected == null,
                onTap: () => onSelect(null),
              ),
              ...projects.map((p) => _Chip(
                    label: p.name,
                    selected: selected == p.id,
                    onTap: () => onSelect(p.id),
                  )),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String       label;
  final bool         selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? _kPrimary : _kCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? _kPrimary : Colors.white.withOpacity(0.12),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white54,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Add Dialog ────────────────────────────────────────────────────────────────
// COMMERCIAL-EXPERIENCE-CLOSURE-16 (mission Section 01.6/17) — the owner
// explicitly rejected this dialog remaining an isolated Tipo/Título/
// Descrição form when useful Knowledge already exists for the active
// project. `projectId` is now required (still nullable -- "Todos" in the
// filter above is a legitimate state, see Section 19) so this dialog can:
// (a) actually stamp the created opportunity with the project the user was
// filtered to (previously never set at all -- a pre-existing gap, not
// something this mission introduced), and (b) offer a project-scoped
// Knowledge picker.
class _AddOpportunityDialog extends ConsumerStatefulWidget {
  const _AddOpportunityDialog({required this.ref, required this.projectId});
  final WidgetRef ref;
  final String?   projectId;

  @override
  ConsumerState<_AddOpportunityDialog> createState() =>
      _AddOpportunityDialogState();
}

class _AddOpportunityDialogState
    extends ConsumerState<_AddOpportunityDialog> {
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  String _type = OpportunityLabItem.types.first;
  bool _saving = false;
  final Set<String> _selectedKnowledgeIds = {};

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: _kCard,
      title: Text(l10n.oppNewTitle, style: const TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: _type,
                dropdownColor: _kCard,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: l10n.oppTypeLabel,
                  labelStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                ),
                items: OpportunityLabItem.types
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(opportunityTypeLabel(t, l10n)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: l10n.oppTitleLabel,
                  labelStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.oppDescriptionLabel,
                  labelStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                ),
              ),
              const SizedBox(height: 16),
              _knowledgeSection(l10n),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.oppCancel, style: const TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: _saving || _titleCtrl.text.trim().isEmpty
              ? null
              : () async {
                  setState(() => _saving = true);
                  final item = OpportunityLabItem(
                    id:               '',
                    userId:           '',
                    projectId:        widget.projectId,
                    opportunityType:  _type,
                    title:            _titleCtrl.text.trim(),
                    description:      _descCtrl.text.trim(),
                    createdAt:        DateTime.now(),
                    knowledgeItemIds: _selectedKnowledgeIds.toList(),
                  );
                  await ref
                      .read(opportunityLabNotifierProvider.notifier)
                      .add(item);
                  if (context.mounted) Navigator.pop(context);
                },
          style: ElevatedButton.styleFrom(backgroundColor: _kPrimary),
          child: Text(l10n.oppAdd),
        ),
      ],
    );
  }

  // COMMERCIAL-EXPERIENCE-CLOSURE-16 (mission Section 19) — project
  // isolation is non-negotiable: with no active project, this shows a
  // truthful deterministic hint instead of silently listing knowledge from
  // every project the user has (which `knowledgeItemsByProjectProvider`
  // structurally cannot even do -- it always filters by a single
  // `project_id`, and RLS additionally scopes every row to `auth.uid()`).
  Widget _knowledgeSection(AppLocalizations l10n) {
    if (widget.projectId == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          l10n.oppKnowledgeSelectProjectFirst,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      );
    }

    final knowledgeAsync = ref.watch(knowledgeItemsByProjectProvider(widget.projectId!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.oppKnowledgeSectionTitle,
          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.oppKnowledgeSectionHint,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 8),
        knowledgeAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimary)),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (items) {
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l10n.oppKnowledgeEmpty,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (_, i) => _KnowledgeCheckTile(
                      item:     items[i],
                      selected: _selectedKnowledgeIds.contains(items[i].id),
                      onChanged: (v) => setState(() {
                        if (v) {
                          _selectedKnowledgeIds.add(items[i].id);
                        } else {
                          _selectedKnowledgeIds.remove(items[i].id);
                        }
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.oppKnowledgeCountSelected(_selectedKnowledgeIds.length),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _KnowledgeCheckTile extends StatelessWidget {
  const _KnowledgeCheckTile({required this.item, required this.selected, required this.onChanged});
  final KnowledgeItem                item;
  final bool                         selected;
  final ValueChanged<bool>           onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      dense:           true,
      value:           selected,
      onChanged:       (v) => onChanged(v ?? false),
      activeColor:     _kPrimary,
      checkColor:      Colors.white,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding:  EdgeInsets.zero,
      title: Text(
        item.title.isEmpty ? (item.fileName ?? item.sourceUrl ?? item.id) : item.title,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
