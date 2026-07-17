import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/opportunity_lab_item.dart';
import '../../../providers/action_queue_provider.dart';
import '../../../providers/opportunity_lab_provider.dart';
import '../../../providers/project_provider.dart';
import '../../action_engine/screens/action_detail_screen.dart';

// ── Colors ────────────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF0F0F1A);
const _kCard    = Color(0xFF1A1A2E);
const _kPrimary = Color(0xFF6C63FF);
const _kGreen   = Color(0xFF4CAF50);
const _kOrange  = Color(0xFFFF9800);
const _kRed     = Color(0xFFF44336);
const _kTeal    = Color(0xFF00BCD4);

Color _scoreColor(int s) {
  if (s >= 80) return _kGreen;
  if (s >= 60) return _kOrange;
  return _kRed;
}

// ════════════════════════════════════════════════════════════════════════════
// Opportunity Detail Screen
// ════════════════════════════════════════════════════════════════════════════
class OpportunityDetailScreen extends ConsumerWidget {
  const OpportunityDetailScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(opportunityLabItemByIdProvider(itemId));

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppConstants.routeOpportunityLab),
        ),
        title: const Text(
          'Detalhe da Oportunidade',
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
                child: Text('Oportunidade não encontrada.',
                    style: TextStyle(color: Colors.white54)))
            : _DetailBody(item: item, ref: ref),
      ),
    );
  }
}

// ── Status change menu ────────────────────────────────────────────────────────
class _StatusMenu extends StatelessWidget {
  const _StatusMenu({required this.item, required this.ref});

  final OpportunityLabItem item;
  final WidgetRef          ref;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      color: _kCard,
      onSelected: (v) async {
        if (v == 'approve') {
          await ref
              .read(opportunityLabNotifierProvider.notifier)
              .approve(item.id);
          ref.invalidate(opportunityLabItemByIdProvider(item.id));
          if (!context.mounted) return;
          try {
            final action = await ref
                .read(actionQueueNotifierProvider.notifier)
                .addFromOpportunityItem(item);
            if (context.mounted) {
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
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Oportunidade aprovada!'),
                backgroundColor: _kGreen,
              ));
            }
          }
        } else if (v == 'delete') {
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: _kCard,
              title: const Text('Excluir oportunidade?',
                  style: TextStyle(color: Colors.white)),
              content: Text(
                '"${item.title}" será removida permanentemente.',
                style: const TextStyle(color: Colors.white70),
              ),
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
            await ref
                .read(opportunityLabNotifierProvider.notifier)
                .delete(item.id);
            if (context.mounted) context.pop();
          }
        }
      },
      itemBuilder: (_) => [
        if (item.status == 'pending')
          const PopupMenuItem(
            value: 'approve',
            child: Text('Aprovar e criar ação', style: TextStyle(color: _kGreen)),
          ),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Excluir', style: TextStyle(color: _kRed)),
        ),
      ],
    );
  }
}

// ── Detail body ───────────────────────────────────────────────────────────────
class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.item, required this.ref});

  final OpportunityLabItem item;
  final WidgetRef          ref;

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
        // ── Hero header ────────────────────────────────────────
        _HeroHeader(item: item),

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

        if (item.rationale != null && item.rationale!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(
            icon: Icons.psychology_rounded,
            title: 'Justificativa da IA',
            child: _RationaleCard(rationale: item.rationale!),
          ),
        ],

        const SizedBox(height: 12),

        // ── Confiança ──────────────────────────────────────────
        if (item.confidence > 0)
          _Section(
            icon: Icons.verified_rounded,
            title: 'Confiança',
            child: _ConfidenceMeter(value: item.confidence),
          ),

        if (item.risks.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(
            icon: Icons.warning_amber_rounded,
            title: 'Riscos',
            child: _RisksList(risks: item.risks),
          ),
        ],

        if (item.actionSteps.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(
            icon: Icons.checklist_rounded,
            title: 'Próximos Passos',
            child: _ActionStepsList(steps: item.actionSteps),
          ),
        ],

        const SizedBox(height: 20),

        // ── Action buttons ─────────────────────────────────────
        _ActionButtons(item: item, ref: ref),
      ],
    );
  }
}

// ── Hero header ───────────────────────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.item});

  final OpportunityLabItem item;

  @override
  Widget build(BuildContext context) {
    final score = item.finalScore;
    final scoreC = _scoreColor(score);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          // Score ring
          SizedBox(
            width: 72,
            height: 72,
            child: CustomPaint(
              painter: _RingPainter(score: score, color: scoreC),
              child: Center(
                child: Text(
                  '$score',
                  style: TextStyle(
                      color: scoreC,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
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
                    _TypeBadge(type: item.opportunityType),
                    const SizedBox(width: 8),
                    _StatusBadge(status: item.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.3),
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.description,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 12, height: 1.4),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
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
    final trackPaint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    final arcPaint = Paint()
      ..color = color
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(c, r, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * score / 100,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.score != score || old.color != color;
}

// ── Score breakdown ───────────────────────────────────────────────────────────
class _ScoreBreakdown extends StatelessWidget {
  const _ScoreBreakdown({required this.item});

  final OpportunityLabItem item;

  @override
  Widget build(BuildContext context) {
    final dims = [
      ('Mercado',          item.marketScore,      const Color(0xFF6C63FF)),
      ('Receita',          item.revenueScore,     const Color(0xFF4CAF50)),
      ('Competição',       item.competitionScore, const Color(0xFFFF9800)),
      ('Sinergia',         item.synergyScore,     const Color(0xFF00BCD4)),
      ('Fit Estratégico',  item.strategicFit,     const Color(0xFFB44FE8)),
    ];

    return Column(
      children: dims.map((d) => _ScoreRow(label: d.$1, value: d.$2, color: d.$3)).toList(),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.label,
    required this.value,
    required this.color,
  });

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
            width: 110,
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
            child: Text(
              '$value',
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Origin section ────────────────────────────────────────────────────────────
class _OriginSection extends StatelessWidget {
  const _OriginSection({required this.item, this.projectName});

  final OpportunityLabItem item;
  final String?            projectName;

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
        if (item.marketAnalysisId != null)
          _InfoRow(
            icon: Icons.analytics_rounded,
            label: 'Análise de mercado',
            value: item.marketAnalysisId!.substring(0, 8) + '…',
          ),
        _InfoRow(
          icon: Icons.calendar_today_rounded,
          label: 'Criada em',
          value: _formatDate(item.createdAt),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

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

// ── Sources list ──────────────────────────────────────────────────────────────
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kPrimary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.link_rounded,
                        color: _kPrimary, size: 12),
                    const SizedBox(width: 4),
                    Text(s,
                        style: const TextStyle(
                            color: _kPrimary, fontSize: 11)),
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
          const Icon(Icons.format_quote_rounded,
              color: _kPrimary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              rationale,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Confidence meter ──────────────────────────────────────────────────────────
class _ConfidenceMeter extends StatelessWidget {
  const _ConfidenceMeter({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(value);
    final label = value >= 80
        ? 'Alta'
        : value >= 60
            ? 'Média'
            : 'Baixa';

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value / 100,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text('$value% $label',
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ── Risks list ────────────────────────────────────────────────────────────────
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

// ── Action steps ──────────────────────────────────────────────────────────────
class _ActionStepsList extends StatelessWidget {
  const _ActionStepsList({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: steps.asMap().entries.map((e) {
        final n = e.key + 1;
        final text = e.value;
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
                  child: Text(
                    '$n',
                    style: const TextStyle(
                        color: _kPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text,
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

// ── Section wrapper ───────────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
  });

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

// ── Type & Status badges ──────────────────────────────────────────────────────
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

  static Color _color(String s) {
    const m = {
      'approved':  _kGreen,
      'executing': _kTeal,
      'rejected':  _kRed,
    };
    return m[s] ?? _kOrange;
  }

  @override
  Widget build(BuildContext context) {
    final c = _color(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
            color: c, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ── Action buttons ────────────────────────────────────────────────────────────
class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.item, required this.ref});

  final OpportunityLabItem item;
  final WidgetRef          ref;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (item.status == 'pending')
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.bolt_rounded),
              label: const Text('Aprovar e Criar Ação'),
              onPressed: () async {
                await ref
                    .read(opportunityLabNotifierProvider.notifier)
                    .approve(item.id);
                ref.invalidate(opportunityLabItemByIdProvider(item.id));
                if (!context.mounted) return;
                try {
                  final action = await ref
                      .read(actionQueueNotifierProvider.notifier)
                      .addFromOpportunityItem(item);
                  if (context.mounted) {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ActionDetailScreen(itemId: action.id),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Aprovada! Erro ao criar ação: $e'),
                      backgroundColor: _kOrange,
                    ));
                  }
                }
              },
            ),
          ),

        if (item.status == 'approved') ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.bolt_rounded),
              label: const Text('Enviar para Action Engine'),
              onPressed: () async {
                try {
                  await ref
                      .read(actionQueueNotifierProvider.notifier)
                      .addFromOpportunityItem(item);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Ação criada no Action Engine!'),
                      backgroundColor: _kGreen,
                    ));
                    context.go(AppConstants.routeActionEngine);
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
            ),
          ),
        ],

        const SizedBox(height: 10),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _kPrimary,
              side: const BorderSide(color: _kPrimary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Perguntar à IVE sobre esta oportunidade'),
            onPressed: () {
              // IVE overlay is always available via the floating button;
              // navigate to lab screen so IVE has opportunity context loaded
              context.go(AppConstants.routeOpportunityLab);
            },
          ),
        ),
      ],
    );
  }
}
