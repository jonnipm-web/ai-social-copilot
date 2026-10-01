import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/action_queue_item.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/action_queue_provider.dart';
import '../../../providers/feature_flag_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/ive_exclusion_region.dart';
import '../widgets/action_engine_execute_sheet.dart';
import 'action_detail_screen.dart';

// COMMERCIAL-V1-UX-RECONCILIATION (PT/EN commercial matrix) -- item.status
// raw enum values ('pending'/'approved'/'executing'/'completed'/
// 'cancelled') were rendered directly as UI badge text; this maps them to
// a human, localized label instead. Shared by both the queue card badge
// (this file) and action_detail_screen.dart's own _StatusBadge, which
// intentionally reuses the same actionEngineStatusXxx keys.
String actionEngineStatusLabel(AppLocalizations l10n, String status) {
  switch (status) {
    case 'pending':   return l10n.actionEngineStatusPending;
    case 'approved':  return l10n.actionEngineStatusApproved;
    case 'executing': return l10n.actionEngineStatusExecuting;
    case 'completed': return l10n.actionEngineStatusCompleted;
    case 'cancelled': return l10n.actionEngineStatusCancelled;
    default:          return status;
  }
}

// COMMERCIAL-V1-PHYSICAL-QA-RECOVERY (section 6 spot-check) -- same bug
// class as item.status above: action_detail_screen.dart's _TypeBadge
// rendered item.actionType.toUpperCase() raw. actionType is free text
// (no DB CHECK constraint); only 'task' (model default) and 'opportunity'
// (action_queue_provider.dart's addFromOpportunityItem) are known
// call sites today -- any other/future value falls back to itself,
// same as every other xxxLabel() helper in this codebase.
String actionEngineTypeLabel(AppLocalizations l10n, String type) {
  switch (type) {
    case 'task':        return l10n.actionEngineTypeTask;
    case 'opportunity': return l10n.actionEngineTypeOpportunity;
    default:            return type;
  }
}

// ── Colors ───────────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF0F0F1A);
const _kCard    = Color(0xFF1A1A2E);
const _kPrimary = Color(0xFF6C63FF);
const _kGreen   = Color(0xFF4CAF50);
const _kOrange  = Color(0xFFFF9800);
const _kRed     = Color(0xFFF44336);
const _kCyan    = Color(0xFF00BCD4);
const _kGold    = Color(0xFFFFD700);

// ════════════════════════════════════════════════════════════════════════════
// Action Engine Screen (M5) — Feature-flagged
// ════════════════════════════════════════════════════════════════════════════
class ActionEngineScreen extends ConsumerStatefulWidget {
  const ActionEngineScreen({super.key});

  @override
  ConsumerState<ActionEngineScreen> createState() => _ActionEngineScreenState();
}

class _ActionEngineScreenState extends ConsumerState<ActionEngineScreen> {
  String? _projectId;

  void _setProject(String? id) {
    setState(() => _projectId = id);
    ref.read(actionQueueNotifierProvider.notifier).load(projectId: id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final flagAsync =
        ref.watch(featureFlagProvider(FeatureFlag.actionEngineEnabled));

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
        title: Text(
          l10n.navActionEngine,
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      drawer: const AppDrawer(),
      body: flagAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _kPrimary)),
        error: (_, __) => _ActionBody(projectId: _projectId, onProjectChange: _setProject),
        data: (enabled) => enabled
            ? _ActionBody(projectId: _projectId, onProjectChange: _setProject)
            : const _FeatureGated(),
      ),
    );
  }
}

class _FeatureGated extends StatelessWidget {
  const _FeatureGated();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bolt_rounded, color: Colors.white24, size: 64),
            const SizedBox(height: 20),
            Text(l10n.navActionEngine,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              l10n.actionEngineComingSoonBody,
              style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
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
              child: Column(
                children: [
                  const Icon(Icons.lock_rounded, color: _kGold, size: 28),
                  const SizedBox(height: 8),
                  Text(l10n.actionEngineComingSoonPro,
                      style: const TextStyle(
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

class _ActionBody extends ConsumerWidget {
  const _ActionBody({required this.projectId, required this.onProjectChange});
  final String?                projectId;
  final void Function(String?) onProjectChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final itemsAsync = ref.watch(actionQueueNotifierProvider);

    return itemsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: _kPrimary)),
      error: (e, _) => Center(
        child: Text(l10n.commonError,
            style: const TextStyle(color: Colors.white54)),
      ),
      data: (items) {
        // 'approved' sits between 'pending' (awaiting approval) and
        // 'executing' (running) -- an item never stays 'pending' once
        // approved, but it also isn't 'executing' yet. Grouped into this
        // same section (not its own) because _ActionCard already renders
        // the correct per-status badge/button (line ~313, ~458): before
        // this fix, an 'approved' item matched none of the three lists
        // below and simply vanished from every section, invisible but
        // still real in the database (reproduced live, Action Engine
        // continuation session).
        final pending   = items.where((i) => i.status == 'pending' || i.status == 'approved').toList();
        final active    = items.where((i) => i.status == 'executing').toList();
        final completed = items.where((i) => i.status == 'completed').toList();

        return Column(
          children: [
            _ProjectFilter(selected: projectId, onSelect: onProjectChange),
            Expanded(
              child: items.isEmpty
                  ? const _EmptyQueue()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ActionSummaryRow(
                            pending: pending.length,
                            active:  active.length,
                            done:    completed.length,
                          ),
                          const SizedBox(height: 20),

                          if (pending.isNotEmpty) ...[
                            _SectionHeader(l10n.actionEngineSectionPending, pending.length, _kOrange),
                            ...pending.map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _ActionCard(item: item),
                                )),
                            const SizedBox(height: 8),
                          ],

                          if (active.isNotEmpty) ...[
                            _SectionHeader(l10n.actionEngineSectionActive, active.length, _kCyan),
                            ...active.map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _ActionCard(item: item),
                                )),
                            const SizedBox(height: 8),
                          ],

                          if (completed.isNotEmpty) ...[
                            _SectionHeader(l10n.actionEngineSectionCompleted, completed.length, _kGreen),
                            ...completed.take(5).map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _ActionCard(item: item),
                                )),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ActionSummaryRow extends StatelessWidget {
  const _ActionSummaryRow({
    required this.pending,
    required this.active,
    required this.done,
  });
  final int pending;
  final int active;
  final int done;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        _SummaryChip(l10n.actionEngineSummaryPending,   '$pending', _kOrange),
        const SizedBox(width: 10),
        _SummaryChip(l10n.actionEngineSummaryActive,    '$active',  _kCyan),
        const SizedBox(width: 10),
        _SummaryChip(l10n.actionEngineSummaryCompleted, '$done',    _kGreen),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, this.count, this.color);
  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action Card ───────────────────────────────────────────────────────────────

class _ActionCard extends ConsumerStatefulWidget {
  const _ActionCard({required this.item});
  final ActionQueueItem item;

  @override
  ConsumerState<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends ConsumerState<_ActionCard> {
  bool _loading = false;

  static Color _statusColor(String s) {
    const m = {
      'pending':   Color(0xFFFF9800),
      'approved':  Color(0xFF6C63FF),
      'executing': Color(0xFF00BCD4),
      'completed': Color(0xFF4CAF50),
      'cancelled': Color(0xFFF44336),
    };
    return m[s] ?? Colors.white38;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.commonError),
            backgroundColor: _kRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(l10n.actionEngineDeleteTitle,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          l10n.actionEngineDeleteBody(widget.item.title),
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel,
                style: const TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.actionEngineDelete,
                style: const TextStyle(color: _kRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(() => ref
          .read(actionQueueNotifierProvider.notifier)
          .delete(widget.item.id, title: widget.item.title));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n     = AppLocalizations.of(context)!;
    final notifier = ref.read(actionQueueNotifierProvider.notifier);
    final item     = widget.item;
    // COMMERCIAL-V1-PHYSICAL-QA-RECOVERY (§11) -- Opportunity Lab cards
    // already show the linked project's name; Action Engine kept the same
    // traceability gap this mission's brief called out (PROJECT -> OPPORTUNITY
    // -> ACTION must preserve project identity/context end to end). Resolved
    // the same way: filter the user's own RLS-scoped project list by
    // item.projectId, never trust/display an unverified id.
    final projectName = item.projectId == null
        ? null
        : ref.watch(projectsProvider).valueOrNull
            ?.where((p) => p.id == item.projectId)
            .map((p) => p.name)
            .firstOrNull;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ActionDetailScreen(itemId: item.id),
        ),
      ),
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              if (_loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: _kPrimary,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(item.status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    actionEngineStatusLabel(l10n, item.status),
                    style: TextStyle(
                        color: _statusColor(item.status),
                        fontSize: 9,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white24, size: 16),
            ],
          ),
          if (projectName != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.folder_outlined, size: 12, color: Colors.white38),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(projectName,
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _ScoreBadge(l10n.actionEngineScoreRoi, item.roiScore),
              _ScoreBadge(l10n.actionEngineScoreImpact, item.impactScore),
              _ScoreBadge(l10n.actionEngineScoreEffort, item.effortScore),
              _ScoreBadge(l10n.actionEngineScorePriority, item.priority, isSmaller: true),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (item.status == 'pending' && !_loading) ...[
                _ActionBtn(l10n.actionEngineApprove, _kGreen, () => _run(
                    () => notifier.approve(item.id, title: item.title))),
                const SizedBox(width: 8),
              ],
              // INSIGHTVALUES-PRODUCTIZATION-MACRO-03 — "execute"/"complete"
              // now open the AEF Human Gate sheet instead of a direct
              // status write; there is no separate "complete" action left
              // (completion is proven by the receipt, not asserted by a tap).
              if (item.status == 'approved' && !_loading) ...[
                _ActionBtn(l10n.actionEngineExecute, _kCyan, () async {
                  await ActionEngineExecuteSheet.show(context, item);
                  ref.invalidate(actionQueueItemByIdProvider(item.id));
                }),
                const SizedBox(width: 8),
              ],
              if (item.status == 'executing' && !_loading) ...[
                // GATE-17-FINAL-CLOSURE (IVE Adaptive Resting Placement) —
                // physically reproduced collision: the floating IVE avatar's
                // fixed resting corner sat on top of this button. Reports
                // its geometry so the placement engine steers clear;
                // renders unchanged otherwise (ive_exclusion_region.dart).
                IveExclusionRegion(
                  child: _ActionBtn(l10n.actionEngineVerify, _kGreen, () async {
                    await ActionEngineExecuteSheet.show(context, item);
                    ref.invalidate(actionQueueItemByIdProvider(item.id));
                  }),
                ),
                const SizedBox(width: 8),
                _ActionBtn(l10n.actionEnginePause, _kOrange, () => _run(
                    () => notifier.pause(item.id, title: item.title))),
                const SizedBox(width: 8),
              ],
              if (!_loading)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Colors.white24, size: 16),
                  onPressed: _confirmDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ],
      ),
    ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge(this.label, this.value, {this.isSmaller = false});
  final String label;
  final int value;
  final bool isSmaller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
            color: Colors.white54,
            fontSize: isSmaller ? 9 : 10),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn(this.label, this.color, this.onTap);
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
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
    final l10n = AppLocalizations.of(context)!;
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
                label: l10n.actionEngineFilterAll,
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

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.bolt_rounded, color: Colors.white24, size: 56),
          const SizedBox(height: 16),
          Text(
            l10n.actionEngineEmptyTitle,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.actionEngineEmptyBody,
            style: const TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
