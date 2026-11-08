import 'package:flutter/material.dart';
import 'package:ai_social_copilot/shared/ui/iv_kit.dart';
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
import 'package:ai_social_copilot/core/theme/app_tokens.dart';

// COMMERCIAL-V1-UX-RECONCILIATION (PT/EN commercial matrix) -- item.status
// raw enum values ('pending'/'approved'/'executing'/'completed'/
// 'cancelled') were rendered directly as UI badge text; this maps them to
// a human, localized label instead. Shared by both the queue card badge
// (this file) and action_detail_screen.dart's own _StatusBadge, which
// intentionally reuses the same actionEngineStatusXxx keys.
String actionEngineStatusLabel(AppLocalizations l10n, String status) {
  switch (status) {
    case 'pending':
      return l10n.actionEngineStatusPending;
    case 'approved':
      return l10n.actionEngineStatusApproved;
    case 'executing':
      return l10n.actionEngineStatusExecuting;
    case 'completed':
      return l10n.actionEngineStatusCompleted;
    case 'cancelled':
      return l10n.actionEngineStatusCancelled;
    default:
      return status;
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
    case 'task':
      return l10n.actionEngineTypeTask;
    case 'opportunity':
      return l10n.actionEngineTypeOpportunity;
    default:
      return type;
  }
}

// ── Colors ───────────────────────────────────────────────────────────────────
const _kCard = AppColors.surface;
const _kPrimary = AppColors.accent;
const _kGreen = AppColors.positive;
const _kOrange = AppColors.warning;
const _kRed = AppColors.negative;
const _kCyan = AppColors.info;
const _kGold = AppColors.gold;

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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(tooltip: MaterialLocalizations.of(context).backButtonTooltip, 
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.ink),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppConstants.routeDashboard),
        ),
        title: Text(
          l10n.navActionEngine,
          style: const TextStyle(
              color: AppColors.ink, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      drawer: const AppDrawer(),
      body: IvBody(child: flagAsync.when(
        loading: () => const IvLoadingSkeleton(),
        error: (_, __) =>
            _ActionBody(projectId: _projectId, onProjectChange: _setProject),
        data: (enabled) => enabled
            ? _ActionBody(projectId: _projectId, onProjectChange: _setProject)
            : const _FeatureGated(),
      )),
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
            const Icon(Icons.bolt_rounded, color: AppColors.inkSubtle, size: 64),
            const SizedBox(height: 20),
            Text(l10n.navActionEngine,
                style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(
              l10n.actionEngineComingSoonBody,
              style: const TextStyle(
                  color: AppColors.inkMuted, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kGold.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppRadius.lg),
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
  final String? projectId;
  final void Function(String?) onProjectChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final itemsAsync = ref.watch(actionQueueNotifierProvider);

    return itemsAsync.when(
      loading: () => const IvLoadingSkeleton(),
      error: (e, _) => Center(
        child: Text(l10n.commonError,
            style: const TextStyle(color: AppColors.inkMuted)),
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
        final pending = items
            .where((i) => i.status == 'pending' || i.status == 'approved')
            .toList();
        final active = items.where((i) => i.status == 'executing').toList();
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
                            active: active.length,
                            done: completed.length,
                          ),
                          const SizedBox(height: 20),
                          if (pending.isNotEmpty) ...[
                            _SectionHeader(l10n.actionEngineSectionPending,
                                pending.length, _kOrange),
                            ...pending.map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _ActionCard(item: item),
                                )),
                            const SizedBox(height: 8),
                          ],
                          if (active.isNotEmpty) ...[
                            _SectionHeader(l10n.actionEngineSectionActive,
                                active.length, _kCyan),
                            ...active.map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _ActionCard(item: item),
                                )),
                            const SizedBox(height: 8),
                          ],
                          if (completed.isNotEmpty) ...[
                            _SectionHeader(l10n.actionEngineSectionCompleted,
                                completed.length, _kGreen),
                            ...completed.take(5).map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
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
        _SummaryChip(l10n.actionEngineSummaryPending, '$pending', _kOrange),
        const SizedBox(width: 10),
        _SummaryChip(l10n.actionEngineSummaryActive, '$active', _kCyan),
        const SizedBox(width: 10),
        _SummaryChip(l10n.actionEngineSummaryCompleted, '$done', _kGreen),
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
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: AppColors.inkSubtle, fontSize: 11)),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600),
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
      'pending': AppColors.warning,
      'approved': AppColors.accent,
      'executing': AppColors.info,
      'completed': AppColors.positive,
      'cancelled': AppColors.negative,
    };
    return m[s] ?? AppColors.inkSubtle;
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
        backgroundColor: AppColors.surface,
        title: Text(l10n.actionEngineDeleteTitle,
            style: const TextStyle(color: AppColors.ink, fontSize: 16)),
        content: Text(
          l10n.actionEngineDeleteBody(widget.item.title),
          style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel,
                style: const TextStyle(color: AppColors.inkSubtle)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.actionEngineDelete,
                style:
                    const TextStyle(color: _kRed, fontWeight: FontWeight.w600)),
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
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(actionQueueNotifierProvider.notifier);
    final item = widget.item;
    // COMMERCIAL-V1-PHYSICAL-QA-RECOVERY (§11) -- Opportunity Lab cards
    // already show the linked project's name; Action Engine kept the same
    // traceability gap this mission's brief called out (PROJECT -> OPPORTUNITY
    // -> ACTION must preserve project identity/context end to end). Resolved
    // the same way: filter the user's own RLS-scoped project list by
    // item.projectId, never trust/display an unverified id.
    final projectName = item.projectId == null
        ? null
        : ref
            .watch(projectsProvider)
            .valueOrNull
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kCard, gradient: kIvSurfaceGradient,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.ink.withOpacity(0.07)),
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
                        color: AppColors.ink,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusColor(item.status).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      actionEngineStatusLabel(l10n, item.status),
                      style: TextStyle(
                          color: _statusColor(item.status),
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.inkSubtle, size: 16),
              ],
            ),
            if (projectName != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.folder_outlined,
                      size: 12, color: AppColors.inkSubtle),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(projectName,
                        style: const TextStyle(
                            color: AppColors.inkSubtle, fontSize: 11),
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
                _ScoreBadge(l10n.actionEngineScorePriority, item.priority,
                    isSmaller: true),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (item.status == 'pending' && !_loading) ...[
                  _ActionBtn(
                      l10n.actionEngineApprove,
                      _kGreen,
                      () => _run(
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
                    child:
                        _ActionBtn(l10n.actionEngineVerify, _kGreen, () async {
                      await ActionEngineExecuteSheet.show(context, item);
                      ref.invalidate(actionQueueItemByIdProvider(item.id));
                    }),
                  ),
                  const SizedBox(width: 8),
                  _ActionBtn(
                      l10n.actionEnginePause,
                      _kOrange,
                      () => _run(
                          () => notifier.pause(item.id, title: item.title))),
                  const SizedBox(width: 8),
                ],
                if (!_loading)
                  IconButton(
                    tooltip: AppLocalizations.of(context)!.commonDelete,
                icon: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.inkSubtle, size: 16),
                    onPressed: _confirmDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(color: AppColors.surface, gradient: kIvSurfaceGradient,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(color: AppColors.inkMuted, fontSize: isSmaller ? 9 : 10),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(AppRadius.sm),
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
  final String? selected;
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
  const _Chip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? _kPrimary : _kCard,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? _kPrimary : AppColors.ink.withOpacity(0.12),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.ink : AppColors.inkMuted,
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
    return IvEmptyState(
      icon: Icons.bolt_rounded,
      color: AppColors.warning,
      title: l10n.actionEngineEmptyTitle,
      message: l10n.actionEngineEmptyBody,
    );
  }
}
