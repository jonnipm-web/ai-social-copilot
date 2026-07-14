import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/weekly_briefing.dart';
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
const _kCyan    = Color(0xFF00E5FF);

// ════════════════════════════════════════════════════════════════════════════
// Weekly Executive Briefing Screen — Módulo 7
// ════════════════════════════════════════════════════════════════════════════
class WeeklyBriefingScreen extends ConsumerWidget {
  const WeeklyBriefingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final briefingAsync = ref.watch(weeklyBriefingProvider);

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
        title: const Text('Briefing Executivo Semanal',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
            onPressed: () => ref.invalidate(weeklyBriefingProvider),
          ),
        ],
      ),
      body: briefingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _kPrimary)),
        error: (e, _) => Center(
          child: Text('Erro ao gerar briefing: $e',
            style: const TextStyle(color: _kRed), textAlign: TextAlign.center)),
        data: (b) => _BriefingBody(briefing: b),
      ),
    );
  }
}

class _BriefingBody extends StatelessWidget {
  final WeeklyBriefing briefing;
  const _BriefingBody({required this.briefing});

  @override
  Widget build(BuildContext context) {
    final day   = briefing.generatedAt.day.toString().padLeft(2, '0');
    final month = briefing.generatedAt.month.toString().padLeft(2, '0');
    final year  = briefing.generatedAt.year;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        _Header(briefing: briefing, dateStr: '$day/$month/$year'),
        const SizedBox(height: 16),

        // Executive summary
        _SummaryCard(text: briefing.executiveSummary),
        const SizedBox(height: 16),

        // Sections
        _Section(
          title: '🔄 O que mudou',
          color: _kCyan,
          items: briefing.whatChanged,
        ),
        const SizedBox(height: 12),
        _Section(
          title: '📈 O que cresceu',
          color: _kGreen,
          items: briefing.whatGrew,
        ),
        const SizedBox(height: 12),
        _Section(
          title: '📉 O que piorou',
          color: _kRed,
          items: briefing.whatDeclined,
        ),
        const SizedBox(height: 12),
        _Section(
          title: '🎯 O que priorizar',
          color: _kGold,
          items: briefing.topPriorities,
        ),
        const SizedBox(height: 12),
        _Section(
          title: '⏸️ O que pausar',
          color: _kOrange,
          items: briefing.toPause,
        ),
        const SizedBox(height: 12),
        _Section(
          title: '💡 Oportunidades novas',
          color: _kCyan,
          items: briefing.newOpportunities,
        ),
        const SizedBox(height: 12),
        _Section(
          title: '⚠️ Riscos identificados',
          color: _kRed,
          items: briefing.risks,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final WeeklyBriefing briefing;
  final String dateStr;
  const _Header({required this.briefing, required this.dateStr});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0E40), Color(0xFF0A0A14)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kPrimary.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('BRIEFING EXECUTIVO',
                  style: TextStyle(color: _kPrimary, fontWeight: FontWeight.bold,
                      fontSize: 11, letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text('Semana de $dateStr',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 8),
                Text(briefing.healthEmoji + '  Saúde Geral: ${briefing.overallHealthScore}/100',
                  style: const TextStyle(color: Colors.white, fontSize: 15,
                      fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: briefing.overallHealthScore / 100,
                  strokeWidth: 6,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation(_healthColor(briefing.overallHealthScore)),
                ),
                Text('${briefing.overallHealthScore}',
                  style: TextStyle(
                    color: _healthColor(briefing.overallHealthScore),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _healthColor(int h) {
    if (h >= 70) return _kGreen;
    if (h >= 45) return _kOrange;
    return _kRed;
  }
}

class _SummaryCard extends StatelessWidget {
  final String text;
  const _SummaryCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumo Executivo',
            style: TextStyle(color: Colors.white54, fontSize: 11,
                fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Color color;
  final List<BriefingItem> items;
  const _Section({required this.title, required this.color, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text('Nenhum item nesta semana',
              style: TextStyle(color: color.withOpacity(0.4), fontSize: 12)),
          )
        else
          ...items.map((item) => _BriefingRow(item: item, color: color)),
      ],
    );
  }
}

class _BriefingRow extends StatelessWidget {
  final BriefingItem item;
  final Color color;
  const _BriefingRow({required this.item, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          if (item.detail.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(item.detail,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}
