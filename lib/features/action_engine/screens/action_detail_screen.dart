import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/action_queue_item.dart';
import '../../../providers/action_queue_provider.dart';
import '../../../providers/project_provider.dart';

// ── Colors ────────────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF0F0F1A);
const _kCard    = Color(0xFF1A1A2E);
const _kPrimary = Color(0xFF6C63FF);
const _kGreen   = Color(0xFF4CAF50);
const _kOrange  = Color(0xFFFF9800);
const _kRed     = Color(0xFFF44336);
const _kCyan    = Color(0xFF00BCD4);

Color _statusColor(String s) {
  const m = {
    'pending':   _kOrange,
    'approved':  _kPrimary,
    'executing': _kCyan,
    'completed': _kGreen,
    'cancelled': _kRed,
  };
  return m[s] ?? Colors.white38;
}

Color _scoreColor(int s) {
  if (s >= 80) return _kGreen;
  if (s >= 60) return _kOrange;
  return _kRed;
}

// ════════════════════════════════════════════════════════════════════════════
// Action Detail Screen
// ════════════════════════════════════════════════════════════════════════════
class ActionDetailScreen extends ConsumerWidget {
  const ActionDetailScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(actionQueueItemByIdProvider(itemId));

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppConstants.routeActionEngine),
        ),
        title: const Text(
          'Detalhe da Ação',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          itemAsync.maybeWhen(
            data: (item) => item != null
                ? _StatusMenu(item: item, ref: ref)
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: itemAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _kPrimary)),
        error: (e, _) => Center(
          child: Text('Erro: $e',
              style: const TextStyle(color: Colors.white54)),
        ),
        data: (item) => item == null
            ? const Center(
                child: Text('Ação não encontrada.',
                    style: TextStyle(color: Colors.white54)))
            : _DetailBody(item: item, ref: ref),
      ),
    );
  }
}

// ── Status menu ───────────────────────────────────────────────────────────────
class _StatusMenu extends StatelessWidget {
  const _StatusMenu({required this.item, required this.ref});

  final ActionQueueItem item;
  final WidgetRef       ref;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      color: _kCard,
      onSelected: (v) async {
        final notifier = ref.read(actionQueueNotifierProvider.notifier);
        try {
          if (v == 'approve')  await notifier.approve(item.id,  title: item.title);
          if (v == 'execute')  await notifier.execute(item.id,  title: item.title);
          if (v == 'complete') await notifier.complete(item.id, title: item.title);
          if (v == 'pause')    await notifier.pause(item.id,    title: item.title);
          if (v == 'cancel')   await notifier.cancel(item.id,   title: item.title);
          ref.invalidate(actionQueueItemByIdProvider(item.id));
          if (context.mounted && v == 'complete') {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Ação concluída!'),
              backgroundColor: _kGreen,
            ));
          }
          if (v == 'delete') {
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: _kCard,
                title: const Text('Excluir ação?',
                    style: TextStyle(color: Colors.white)),
                content: Text('"${item.title}" será removida.',
                    style: const TextStyle(color: Colors.white70)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar',
                          style: TextStyle(color: Colors.white54))),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Excluir',
                          style: TextStyle(color: _kRed))),
                ],
              ),
            );
            if (ok == true) {
              await notifier.delete(item.id, title: item.title);
              if (context.mounted) context.pop();
            }
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Erro: $e'),
              backgroundColor: _kRed,
            ));
          }
        }
      },
      itemBuilder: (_) => [
        if (item.status == 'pending')
          const PopupMenuItem(value: 'approve',
              child: Text('Aprovar', style: TextStyle(color: _kPrimary))),
        if (item.status == 'approved')
          const PopupMenuItem(value: 'execute',
              child: Text('Iniciar', style: TextStyle(color: _kCyan))),
        if (item.status == 'executing') ...[
          const PopupMenuItem(value: 'complete',
              child: Text('Concluir', style: TextStyle(color: _kGreen))),
          const PopupMenuItem(value: 'pause',
              child: Text('Pausar', style: TextStyle(color: _kOrange))),
        ],
        if (item.status != 'completed' && item.status != 'cancelled')
          const PopupMenuItem(value: 'cancel',
              child: Text('Cancelar', style: TextStyle(color: Colors.white54))),
        const PopupMenuItem(value: 'delete',
            child: Text('Excluir', style: TextStyle(color: _kRed))),
      ],
    );
  }
}

// ── Detail body ───────────────────────────────────────────────────────────────
class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.item, required this.ref});

  final ActionQueueItem item;
  final WidgetRef       ref;

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsNotifierProvider);
    final projects = projectsAsync.valueOrNull ?? [];
    final projectName = item.projectId == null
        ? null
        : projects.where((p) => p.id == item.projectId).map((p) => p.name).firstOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        // ── Hero ───────────────────────────────────────────────
        _HeroHeader(item: item, projectName: projectName),

        const SizedBox(height: 16),

        // ── Score breakdown ────────────────────────────────────
        _Section(
          icon: Icons.bar_chart_rounded,
          title: 'Score Breakdown',
          child: _ScoreBreakdown(item: item),
        ),

        const SizedBox(height: 12),

        // ── Origem ─────────────────────────────────────────────
        _Section(
          icon: Icons.track_changes_rounded,
          title: 'Origem',
          child: _OriginSection(item: item, projectName: projectName),
        ),

        if (item.sources.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(
            icon: Icons.source_rounded,
            title: 'Fontes',
            child: _SourcesList(sources: item.sources),
          ),
        ],

        if (item.description != null && item.description!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(
            icon: Icons.description_rounded,
            title: 'Descrição',
            child: Text(
              item.description!,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13, height: 1.5),
            ),
          ),
        ],

        if (item.rationale != null && item.rationale!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(
            icon: Icons.psychology_rounded,
            title: 'Justificativa da IA',
            child: _RationaleCard(rationale: item.rationale!),
          ),
        ],

        if (item.plan.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(
            icon: Icons.list_alt_rounded,
            title: 'Plano de Execução',
            child: _PlanList(steps: item.plan),
          ),
        ],

        if (item.risks.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(
            icon: Icons.warning_amber_rounded,
            title: 'Riscos',
            child: _RisksList(risks: item.risks),
          ),
        ],

        const SizedBox(height: 20),

        // ── Status actions ─────────────────────────────────────
        _StatusButtons(item: item, ref: ref),
      ],
    );
  }
}

// ── Hero header ───────────────────────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.item, this.projectName});

  final ActionQueueItem item;
  final String?         projectName;

  @override
  Widget build(BuildContext context) {
    final sc = _scoreColor(item.priority);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          // Priority ring
          SizedBox(
            width: 68,
            height: 68,
            child: CustomPaint(
              painter: _RingPainter(score: item.priority, color: sc),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${item.priority}',
                      style: TextStyle(
                          color: sc,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    Text('prio',
                        style: TextStyle(
                            color: sc.withOpacity(0.7), fontSize: 8)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _TypeBadge(type: item.actionType),
                    const SizedBox(width: 6),
                    _StatusBadge(status: item.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      height: 1.3),
                ),
                if (projectName != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.folder_rounded,
                          color: _kPrimary, size: 12),
                      const SizedBox(width: 4),
                      Text(projectName!,
                          style: const TextStyle(
                              color: _kPrimary, fontSize: 11)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.score, required this.color});

  final int   score;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 6;
    final track = Paint()
      ..color = Colors.white12
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    final arc = Paint()
      ..color = color
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, track);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * score / 100,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.score != score || old.color != color;
}

// ── Score breakdown ───────────────────────────────────────────────────────────
class _ScoreBreakdown extends StatelessWidget {
  const _ScoreBreakdown({required this.item});

  final ActionQueueItem item;

  @override
  Widget build(BuildContext context) {
    final fromLab = item.origin == 'opportunity_lab';
    final dims = [
      if (fromLab && item.marketScore > 0)
        ('Mercado',   item.marketScore, const Color(0xFF6C63FF)),
      ('Receita',     item.impactScore, const Color(0xFF4CAF50)),
      ('ROI / Final', item.roiScore,    const Color(0xFFB44FE8)),
      ('Esforço',     item.effortScore, const Color(0xFFFF9800)),
      ('Prioridade',  item.priority,    const Color(0xFF00BCD4)),
      if (fromLab && item.confidence > 0)
        ('Confiança', item.confidence,  const Color(0xFFFFD700)),
    ];
    return Column(
      children: dims
          .map((d) => _ScoreRow(label: d.$1, value: d.$2, color: d.$3))
          .toList(),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.label, required this.value, required this.color});

  final String label;
  final int    value;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value / 100,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text('$value',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ── Origin section ────────────────────────────────────────────────────────────
class _OriginSection extends StatelessWidget {
  const _OriginSection({required this.item, this.projectName});

  final ActionQueueItem item;
  final String?         projectName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(
          icon: Icons.input_rounded,
          label: 'Gerada por',
          value: item.originLabel,
        ),
        if (projectName != null)
          _InfoRow(
            icon: Icons.folder_rounded,
            label: 'Projeto',
            value: projectName!,
          ),
        if (item.opportunityLabId != null)
          _InfoRow(
            icon: Icons.science_rounded,
            label: 'Oportunidade',
            value: 'Lab #${item.opportunityLabId!.substring(0, 8)}…',
          ),
        if (item.marketAnalysisId != null)
          _InfoRow(
            icon: Icons.analytics_rounded,
            label: 'Análise de mercado',
            value: 'Market #${item.marketAnalysisId!.substring(0, 8)}…',
          ),
        _InfoRow(
          icon: Icons.calendar_today_rounded,
          label: 'Criada em',
          value: _fmtDate(item.createdAt),
        ),
        if (item.updatedAt != null)
          _InfoRow(
            icon: Icons.update_rounded,
            label: 'Atualizada em',
            value: _fmtDate(item.updatedAt!),
          ),
      ],
    );
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String   label;
  final String   value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: _kPrimary, size: 15),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ── Sources ───────────────────────────────────────────────────────────────────
class _SourcesList extends StatelessWidget {
  const _SourcesList({required this.sources});

  final List<String> sources;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sources
          .map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kPrimary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.link_rounded, color: _kPrimary, size: 12),
                    const SizedBox(width: 4),
                    Text(s,
                        style: const TextStyle(color: _kPrimary, fontSize: 11)),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

// ── Rationale ─────────────────────────────────────────────────────────────────
class _RationaleCard extends StatelessWidget {
  const _RationaleCard({required this.rationale});

  final String rationale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kPrimary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kPrimary.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.format_quote_rounded, color: _kPrimary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(rationale,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

// ── Plan ──────────────────────────────────────────────────────────────────────
class _PlanList extends StatelessWidget {
  const _PlanList({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: steps.asMap().entries.map((e) {
        final n = e.key + 1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: _kPrimary.withOpacity(0.4)),
                ),
                child: Center(
                  child: Text('$n',
                      style: const TextStyle(
                          color: _kPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(e.value,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12, height: 1.4)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Risks ─────────────────────────────────────────────────────────────────────
class _RisksList extends StatelessWidget {
  const _RisksList({required this.risks});

  final List<String> risks;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: risks
          .map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.report_problem_rounded,
                        color: _kOrange, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(r,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12, height: 1.4)),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

// ── Section wrapper ───────────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.child});

  final IconData icon;
  final String   title;
  final Widget   child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _kPrimary, size: 16),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ── Badges ────────────────────────────────────────────────────────────────────
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _kPrimary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type.toUpperCase(),
        style: const TextStyle(
            color: _kPrimary, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final c = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(status,
          style: TextStyle(
              color: c, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}

// ── Status buttons ────────────────────────────────────────────────────────────
class _StatusButtons extends StatelessWidget {
  const _StatusButtons({required this.item, required this.ref});

  final ActionQueueItem item;
  final WidgetRef       ref;

  Future<void> _run(BuildContext context, Future<void> Function() fn) async {
    try {
      await fn();
      ref.invalidate(actionQueueItemByIdProvider(item.id));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: _kRed,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = ref.read(actionQueueNotifierProvider.notifier);

    return Column(
      children: [
        if (item.status == 'pending')
          _Btn(
            label: 'Aprovar Ação',
            icon: Icons.check_circle_outline_rounded,
            color: _kPrimary,
            onTap: () => _run(context, () => n.approve(item.id, title: item.title)),
          ),

        if (item.status == 'approved') ...[
          _Btn(
            label: 'Iniciar Execução',
            icon: Icons.play_arrow_rounded,
            color: _kCyan,
            onTap: () => _run(context, () => n.execute(item.id, title: item.title)),
          ),
        ],

        if (item.status == 'executing') ...[
          _Btn(
            label: 'Marcar como Concluída',
            icon: Icons.task_alt_rounded,
            color: _kGreen,
            onTap: () async {
              await _run(context, () => n.complete(item.id, title: item.title));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Ação concluída!'),
                  backgroundColor: _kGreen,
                ));
              }
            },
          ),
          const SizedBox(height: 8),
          _Btn(
            label: 'Pausar',
            icon: Icons.pause_rounded,
            color: _kOrange,
            outlined: true,
            onTap: () => _run(context, () => n.pause(item.id, title: item.title)),
          ),
        ],

        if (item.status == 'completed')
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _kGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kGreen.withOpacity(0.3)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.task_alt_rounded, color: _kGreen, size: 18),
                SizedBox(width: 8),
                Text('Concluída',
                    style: TextStyle(color: _kGreen, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

        const SizedBox(height: 10),

        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: _kPrimary,
            side: const BorderSide(color: _kPrimary),
            padding: const EdgeInsets.symmetric(vertical: 14),
            minimumSize: const Size(double.infinity, 0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('Perguntar à IVE sobre esta ação'),
          onPressed: () => context.go(AppConstants.routeActionEngine),
        ),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  final String       label;
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;
  final bool         outlined;

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          icon: Icon(icon),
          label: Text(label),
          onPressed: onTap,
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: Icon(icon),
        label: Text(label),
        onPressed: onTap,
      ),
    );
  }
}
