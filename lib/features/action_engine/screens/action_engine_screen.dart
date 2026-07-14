import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/action_queue_item.dart';
import '../../../providers/action_queue_provider.dart';
import '../../../providers/feature_flag_provider.dart';
import '../../../shared/widgets/app_drawer.dart';

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
class ActionEngineScreen extends ConsumerWidget {
  const ActionEngineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        title: const Text(
          'Action Engine',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      drawer: const AppDrawer(),
      body: flagAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _kPrimary)),
        error: (_, __) => _ActionBody(ref: ref),
        data: (enabled) =>
            enabled ? _ActionBody(ref: ref) : const _FeatureGated(),
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
            const Icon(Icons.bolt_rounded, color: Colors.white24, size: 64),
            const SizedBox(height: 20),
            const Text('Action Engine',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              'O motor de ações está sendo calibrado.\nEm breve você terá um sistema inteligente que transforma análises em tarefas executáveis com priorização automática.',
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

class _ActionBody extends StatelessWidget {
  const _ActionBody({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(actionQueueNotifierProvider);

    return itemsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: _kPrimary)),
      error: (e, _) => Center(
        child: Text('Erro: $e',
            style: const TextStyle(color: Colors.white54)),
      ),
      data: (items) {
        final pending   = items.where((i) => i.status == 'pending').toList();
        final active    = items.where((i) => i.status == 'executing').toList();
        final completed = items.where((i) => i.status == 'completed').toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary
              _ActionSummaryRow(
                pending: pending.length,
                active:  active.length,
                done:    completed.length,
              ),
              const SizedBox(height: 20),

              if (pending.isNotEmpty) ...[
                _SectionHeader('Pendentes', pending.length, _kOrange),
                ...pending.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ActionCard(item: item, ref: ref),
                    )),
                const SizedBox(height: 8),
              ],

              if (active.isNotEmpty) ...[
                _SectionHeader('Em Execução', active.length, _kCyan),
                ...active.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ActionCard(item: item, ref: ref),
                    )),
                const SizedBox(height: 8),
              ],

              if (completed.isNotEmpty) ...[
                _SectionHeader('Concluídas', completed.length, _kGreen),
                ...completed.take(5).map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ActionCard(item: item, ref: ref),
                    )),
              ],

              if (items.isEmpty)
                const _EmptyQueue(),
            ],
          ),
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
    return Row(
      children: [
        _SummaryChip('Pendentes',  '$pending', _kOrange),
        const SizedBox(width: 10),
        _SummaryChip('Ativas',     '$active',  _kCyan),
        const SizedBox(width: 10),
        _SummaryChip('Concluídas', '$done',    _kGreen),
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

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.item, required this.ref});
  final ActionQueueItem item;
  final WidgetRef ref;

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

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(actionQueueNotifierProvider.notifier);

    return Container(
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(item.status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.status,
                  style: TextStyle(
                      color: _statusColor(item.status),
                      fontSize: 9,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _ScoreBadge('ROI', item.roiScore),
              _ScoreBadge('Impacto', item.impactScore),
              _ScoreBadge('Esforço', item.effortScore),
              _ScoreBadge('Prio.', item.priority, isSmaller: true),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (item.status == 'pending') ...[
                _ActionBtn('Aprovar', _kGreen,
                    () => notifier.approve(item.id)),
                const SizedBox(width: 8),
              ],
              if (item.status == 'approved') ...[
                _ActionBtn('Iniciar', _kCyan,
                    () => notifier.execute(item.id)),
                const SizedBox(width: 8),
              ],
              if (item.status == 'executing') ...[
                _ActionBtn('Concluir', _kGreen,
                    () => notifier.complete(item.id)),
                const SizedBox(width: 8),
                _ActionBtn('Pausar', _kOrange,
                    () => notifier.approve(item.id)),
                const SizedBox(width: 8),
              ],
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.white24, size: 16),
                onPressed: () => notifier.delete(item.id),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
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

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.bolt_rounded, color: Colors.white24, size: 56),
          const SizedBox(height: 16),
          const Text(
            'Fila de ações vazia',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ações serão geradas automaticamente a partir de análises de mercado e oportunidades.',
            style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
