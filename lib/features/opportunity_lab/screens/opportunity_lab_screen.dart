import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/action_queue_item.dart';
import '../../../data/models/opportunity_lab_item.dart';
import '../../../providers/action_queue_provider.dart';
import '../../../providers/opportunity_lab_provider.dart';
import '../../../providers/feature_flag_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../action_engine/screens/action_detail_screen.dart';
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
        builder: (ctx, r, _) => _AddOpportunityDialog(ref: r),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flagAsync = ref.watch(featureFlagProvider(FeatureFlag.opportunityLabEnabled));

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
        label: const Text('Nova Oportunidade'),
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
                    builder: (ctx) =>
                        Consumer(builder: (ctx, r, _) => _AddOpportunityDialog(ref: r)),
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
                    onDelete: () =>
                        ref.read(opportunityLabNotifierProvider.notifier).delete(items[i].id),
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

class _LabItemCard extends ConsumerStatefulWidget {
  const _LabItemCard({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });
  final OpportunityLabItem item;
  final VoidCallback        onTap;
  final VoidCallback        onDelete;
}

class _LabItemCardState extends ConsumerState<_LabItemCard> {
  bool   _loading      = false;
  String? _linkedActionId;

  static Color _statusColor(String s) {
    const m = {
      'approved':  Color(0xFF4CAF50),
      'executing': Color(0xFF00BCD4),
      'rejected':  Color(0xFFF44336),
    };
    return m[s] ?? const Color(0xFFFF9800);
  }

  Future<void> _approve() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final action = await ref
          .read(opportunityLabNotifierProvider.notifier)
          .approveAndCreateAction(
            widget.item,
            ref.read(actionQueueNotifierProvider.notifier),
          );
      if (mounted) {
        setState(() => _linkedActionId = action.id);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Aprovada e enviada ao Action Engine!'),
          backgroundColor: _kGreen,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Não foi possível criar a ação. A oportunidade não foi convertida. Tente novamente.',
            style: const TextStyle(fontSize: 12),
          ),
          backgroundColor: _kRed,
          duration: const Duration(seconds: 5),
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openLinkedAction(String actionId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ActionDetailScreen(itemId: actionId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item  = widget.item;
    final score = item.finalScore;
    final c     = _scoreColor(score);

    // For already-approved items (loaded from DB), look up linked action
    final linkedAsync = item.status == 'approved' && _linkedActionId == null
        ? ref.watch(actionByOpportunityLabIdProvider(item.id))
        : null;
    final dbLinkedId = linkedAsync?.valueOrNull?.id;
    final effectiveActionId = _linkedActionId ?? dbLinkedId;

    return GestureDetector(
      onTap: widget.onTap,
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
                    item.opportunityType.toUpperCase(),
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
                            color: c, fontSize: 13, fontWeight: FontWeight.bold)),
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

                // ── Approve button (pending only) ────────────────
                if (item.status == 'pending')
                  _loading
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _kGreen),
                        )
                      : TextButton(
                          onPressed: _approve,
                          style: TextButton.styleFrom(
                              foregroundColor: _kGreen,
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(horizontal: 8)),
                          child: const Text('Aprovar', style: TextStyle(fontSize: 12)),
                        ),

                // ── Open action button (approved with linked action) ──
                if (item.status == 'approved' && effectiveActionId != null)
                  TextButton(
                    onPressed: () => _openLinkedAction(effectiveActionId),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF00BCD4),
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 8)),
                    child: const Text('Abrir Ação', style: TextStyle(fontSize: 12)),
                  ),

                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Colors.white24, size: 18),
                  onPressed: widget.onDelete,
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
class _AddOpportunityDialog extends ConsumerStatefulWidget {
  const _AddOpportunityDialog({required this.ref});
  final WidgetRef ref;

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
    return AlertDialog(
      backgroundColor: _kCard,
      title: const Text('Nova Oportunidade',
          style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _type,
              dropdownColor: _kCard,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Tipo',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
              ),
              items: OpportunityLabItem.types
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Título',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: _saving || _titleCtrl.text.trim().isEmpty
              ? null
              : () async {
                  setState(() => _saving = true);
                  final item = OpportunityLabItem(
                    id:              '',
                    userId:          '',
                    opportunityType: _type,
                    title:           _titleCtrl.text.trim(),
                    description:     _descCtrl.text.trim(),
                    createdAt:       DateTime.now(),
                  );
                  await ref
                      .read(opportunityLabNotifierProvider.notifier)
                      .add(item);
                  if (context.mounted) Navigator.pop(context);
                },
          style: ElevatedButton.styleFrom(backgroundColor: _kPrimary),
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}
