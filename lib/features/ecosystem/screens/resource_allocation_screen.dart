import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/resource_allocation.dart';
import '../../../providers/ecosystem_intelligence_provider.dart';
import '../../../shared/widgets/app_drawer.dart';

const _kBg      = Color(0xFF0A0A14);
const _kCard    = Color(0xFF12121E);
const _kBorder  = Color(0xFF1E1E30);
const _kPrimary = Color(0xFF7C4DFF);
const _kGreen   = Color(0xFF00E676);
const _kOrange  = Color(0xFFFF9100);
const _kRed     = Color(0xFFFF1744);
const _kGold    = Color(0xFFFFD700);

// ════════════════════════════════════════════════════════════════════════════
// Resource Allocation Screen — Módulo 5
// ════════════════════════════════════════════════════════════════════════════
class ResourceAllocationScreen extends ConsumerStatefulWidget {
  const ResourceAllocationScreen({super.key});

  @override
  ConsumerState<ResourceAllocationScreen> createState() => _ResourceAllocationScreenState();
}

class _ResourceAllocationScreenState extends ConsumerState<ResourceAllocationScreen> {
  String _mode = 'hours';
  double _budget = 10;

  static const List<double> _hourOptions  = [10, 20, 40, 80];
  static const List<double> _moneyOptions = [100, 500, 1000, 5000];

  @override
  Widget build(BuildContext context) {
    final provider = _mode == 'hours'
        ? ref.watch(resourceAllocationHoursProvider(_budget))
        : ref.watch(resourceAllocationMoneyProvider(_budget));

    return Scaffold(
      backgroundColor: _kBg,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppConstants.routeEcosystem),
        ),
        title: const Text('Alocação de Recursos',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Mode selector
          _ModeSelector(
            selected: _mode,
            onChanged: (m) => setState(() => _mode = m),
          ),
          const SizedBox(height: 16),

          // Budget selector
          _BudgetSelector(
            mode: _mode,
            selected: _budget,
            options: _mode == 'hours' ? _hourOptions : _moneyOptions,
            onChanged: (v) => setState(() => _budget = v),
          ),
          const SizedBox(height: 20),

          // Results
          provider.when(
            loading: () => const Center(child: CircularProgressIndicator(color: _kPrimary)),
            error: (e, _) => Text('Erro: $e', style: const TextStyle(color: _kRed)),
            data: (alloc) => _AllocationResult(alloc: alloc),
          ),
        ],
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _ModeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _ModeChip(label: '⏱ Tempo (Horas)', value: 'hours', selected: selected, onTap: () => onChanged('hours'))),
        const SizedBox(width: 8),
        Expanded(child: _ModeChip(label: '💰 Dinheiro (R\$)', value: 'money', selected: selected, onTap: () => onChanged('money'))),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final VoidCallback onTap;
  const _ModeChip({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = value == selected;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? _kPrimary : _kCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? _kPrimary : _kBorder),
        ),
        child: Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? Colors.white : Colors.white54,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          )),
      ),
    );
  }
}

class _BudgetSelector extends StatelessWidget {
  final String mode;
  final double selected;
  final List<double> options;
  final ValueChanged<double> onChanged;
  const _BudgetSelector({required this.mode, required this.selected, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final label = mode == 'hours' ? 'horas' : 'R\$';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quanto tenho disponível?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((v) {
            final active = v == selected;
            final display = mode == 'hours' ? '${v.round()}h' : 'R\$${v.round()}';
            return GestureDetector(
              onTap: () => onChanged(v),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: active ? _kGold.withOpacity(0.2) : _kCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: active ? _kGold : _kBorder),
                ),
                child: Text(display,
                  style: TextStyle(
                    color: active ? _kGold : Colors.white54,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  )),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _AllocationResult extends StatelessWidget {
  final ResourceAllocation alloc;
  const _AllocationResult({required this.alloc});

  @override
  Widget build(BuildContext context) {
    final label = alloc.budgetType == 'hours' ? 'horas' : 'R\$';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A1040), Color(0xFF12121E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kPrimary.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, color: _kGold, size: 18),
                  const SizedBox(width: 8),
                  const Text('Recomendação Executiva',
                    style: TextStyle(color: _kGold, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              Text(alloc.summary,
                style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (alloc.items.isEmpty)
          const Text('Adicione projetos com análises para ver a alocação.',
            style: TextStyle(color: Colors.white54))
        else ...[
          Text('Distribuição das ${alloc.totalBudget.round()} $label',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          ...alloc.items.map((item) => _AllocationItem(item: item, budgetType: alloc.budgetType)),
        ],
      ],
    );
  }
}

class _AllocationItem extends StatelessWidget {
  final AllocationItem item;
  final String budgetType;
  const _AllocationItem({required this.item, required this.budgetType});

  Color _color(int score) {
    if (score >= 70) return _kGreen;
    if (score >= 45) return _kOrange;
    return _kRed;
  }

  @override
  Widget build(BuildContext context) {
    final label = budgetType == 'hours' ? 'h' : 'R\$';
    final alloc = budgetType == 'hours'
        ? '${item.allocation.toStringAsFixed(1)}$label'
        : '$label${item.allocation.toStringAsFixed(0)}';
    final color = _color(item.score.ecosystemScore);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.score.project.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              Text(alloc,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(width: 6),
              Text('${item.percentage.round()}%',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: item.percentage / 100,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(item.reason, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 2),
          Text('Ecosystem Score: ${item.score.ecosystemScore}/100  •  ${item.score.recommendationEmoji} ${item.score.recommendation}',
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }
}
