import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/weekly_briefing.dart';
import '../../../providers/action_queue_provider.dart';
import '../../../providers/ecosystem_intelligence_provider.dart';
import '../../../providers/market_analysis_provider.dart';
import '../../../providers/opportunity_lab_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/ive_detail_sheet.dart';

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
            onPressed: () {
              ref.invalidate(projectsProvider);
              ref.invalidate(opportunityLabProvider);
              ref.invalidate(actionQueueProvider);
              ref.invalidate(marketAnalysesProvider);
              ref.invalidate(ecosystemScoresProvider);
              ref.invalidate(weeklyBriefingProvider);
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: briefingAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: _kPrimary)),
          error: (e, _) => Center(
            child: Text('Erro ao gerar briefing: $e',
              style: const TextStyle(color: _kRed), textAlign: TextAlign.center)),
          data: (b) => _BriefingBody(briefing: b),
        ),
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
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;
        final hPad = isDesktop ? 32.0 : 16.0;

        final header = _Header(briefing: briefing, dateStr: '$day/$month/$year');
        final dataOrigin = _DataOriginCard(briefing: briefing);
        final summary = _SummaryCard(text: briefing.executiveSummary);

        final mainSections = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Section(title: '🔄 O que mudou',        color: _kCyan,   items: briefing.whatChanged),
            const SizedBox(height: 12),
            _Section(title: '📈 O que cresceu',       color: _kGreen,  items: briefing.whatGrew),
            const SizedBox(height: 12),
            _Section(title: '📉 O que piorou',        color: _kRed,    items: briefing.whatDeclined),
            const SizedBox(height: 12),
            _Section(title: '🎯 O que priorizar',     color: _kGold,   items: briefing.topPriorities),
            const SizedBox(height: 12),
            _Section(title: '⏸️ O que pausar',        color: _kOrange, items: briefing.toPause),
            const SizedBox(height: 12),
            _Section(title: '💡 Oportunidades novas', color: _kCyan,   items: briefing.newOpportunities),
          ],
        );

        final sidebar = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HealthSideCard(briefing: briefing),
            const SizedBox(height: 12),
            _Section(title: '⚠️ Riscos',              color: _kRed,    items: briefing.risks),
          ],
        );

        Widget body;
        if (isDesktop) {
          body = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: mainSections),
              const SizedBox(width: 20),
              SizedBox(width: 300, child: sidebar),
            ],
          );
        } else {
          body = Column(
            children: [
              mainSections,
              const SizedBox(height: 12),
              _Section(title: '⚠️ Riscos identificados', color: _kRed, items: briefing.risks),
            ],
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 16 + bottomPad),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  const SizedBox(height: 10),
                  dataOrigin,
                  const SizedBox(height: 16),
                  summary,
                  const SizedBox(height: 16),
                  body,
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HealthSideCard extends StatelessWidget {
  const _HealthSideCard({required this.briefing});
  final WeeklyBriefing briefing;

  Color _healthColor(int h) {
    if (h >= 70) return _kGreen;
    if (h >= 45) return _kOrange;
    return _kRed;
  }

  void _showHealthExplain(BuildContext context) {
    final h = briefing.overallHealthScore;
    final hc = _healthColor(h);
    final label = h >= 70 ? 'Saudável 🟢' : h >= 45 ? 'Atenção 🟡' : 'Crítico 🔴';
    IveDetailSheet.show(
      context,
      title: 'Health Score: $h/100',
      emoji: briefing.healthEmoji,
      humanExplanation:
          'A Saúde Geral do portfólio está em $h/100 — $label.\n\n'
          'O Health Score é calculado com base em:\n'
          '• Projetos ativos vs. em ideia\n'
          '• Oportunidades aprovadas e em execução\n'
          '• Ações concluídas na semana\n'
          '• Análises de mercado disponíveis\n'
          '• Receita registrada no ROI Tracker\n\n'
          '${h < 50 ? "⚠ Score baixo indica que há poucos projetos ativos, "
              "ações executadas ou análises de mercado. "
              "Priorize as recomendações desta semana." : "Score positivo — continue executando as prioridades identificadas."}',
      evidence: [
        IveEvidence(emoji: briefing.healthEmoji, label: 'Saúde Geral',     value: '$h/100'),
        IveEvidence(emoji: '🏷️',                 label: 'Classificação',    value: label),
        IveEvidence(emoji: '📋',                 label: 'Projetos',         value: '${briefing.projectCount}'),
        IveEvidence(emoji: '📊',                 label: 'Análises',         value: '${briefing.analysisCount}'),
        IveEvidence(emoji: '⚡',                 label: 'Ações',            value: '${briefing.actionsCount}'),
        IveEvidence(emoji: '💡',                 label: 'Oportunidades',    value: '${briefing.opportunitiesCount}'),
      ],
      expandedData: {
        'Fórmula': 'Ponderação de projetos ativos, execução, análises e receita',
        'Meta recomendada': '>= 70 (Saudável)',
        'Gerado em': '${briefing.generatedAt.day}/${briefing.generatedAt.month}/${briefing.generatedAt.year}',
      },
      screenName: 'Briefing Semanal',
    );
  }

  @override
  Widget build(BuildContext context) {
    final hc = _healthColor(briefing.overallHealthScore);
    return GestureDetector(
      onTap: () => _showHealthExplain(context),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF12121E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: hc.withOpacity(0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(briefing.healthEmoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text('Saúde Geral',
                      style: TextStyle(color: hc, fontSize: 13, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('${briefing.overallHealthScore}/100',
                      style: TextStyle(color: hc, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  Icon(Icons.info_outline_rounded, color: hc.withOpacity(0.6), size: 14),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: briefing.overallHealthScore / 100,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(hc),
                borderRadius: BorderRadius.circular(4),
                minHeight: 6,
              ),
              if (briefing.overallHealthScore < 50) ...[
                const SizedBox(height: 8),
                const Text(
                  '⚠ Score baixo. Toque para ver a análise completa.',
                  style: TextStyle(color: Colors.orange, fontSize: 11, height: 1.4),
                ),
              ],
            ],
          ),
        ),
      ),
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
                GestureDetector(
                  onTap: () {
                    final h = briefing.overallHealthScore;
                    final label = h >= 70 ? 'Saudável 🟢' : h >= 45 ? 'Atenção 🟡' : 'Crítico 🔴';
                    IveDetailSheet.show(
                      context,
                      title: 'Saúde Geral: $h/100',
                      emoji: briefing.healthEmoji,
                      humanExplanation:
                          'A Saúde Geral do portfólio está em $h/100 — $label.\n\n'
                          '${h >= 70 ? "O ecossistema está saudável. Continue executando as prioridades desta semana." : h >= 45 ? "Há pontos de atenção. Priorize os riscos e execute as recomendações." : "Score crítico. Priorize projetos ativos e execute ações pendentes imediatamente."}\n\n'
                          'Componentes desta semana:\n'
                          '• ${briefing.projectCount} projeto(s) no portfólio\n'
                          '• ${briefing.analysisCount} análise(s) de mercado\n'
                          '• ${briefing.actionsCount} ação(ões) no pipeline\n'
                          '• ${briefing.opportunitiesCount} oportunidade(s) identificada(s)',
                      evidence: <IveEvidence>[
                        IveEvidence(emoji: briefing.healthEmoji, label: 'Saúde Geral',  value: '$h/100'),
                        IveEvidence(emoji: '🏷️',                 label: 'Status',        value: label),
                        IveEvidence(emoji: '📋',                 label: 'Projetos',      value: '${briefing.projectCount}'),
                        IveEvidence(emoji: '📊',                 label: 'Análises MI',   value: '${briefing.analysisCount}'),
                        IveEvidence(emoji: '⚡',                 label: 'Ações',         value: '${briefing.actionsCount}'),
                        IveEvidence(emoji: '💡',                 label: 'Oportunidades', value: '${briefing.opportunitiesCount}'),
                      ],
                      expandedData: {
                        'Meta recomendada': '>= 70 (Saudável)',
                        'Fórmula': 'Ponderação de projetos ativos, execução, análises e receita',
                        'Gerado em': '${briefing.generatedAt.day}/${briefing.generatedAt.month}/${briefing.generatedAt.year}',
                      },
                      screenName: 'Briefing Semanal',
                    );
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Text(
                      briefing.healthEmoji + '  Saúde Geral: ${briefing.overallHealthScore}/100',
                      style: const TextStyle(color: Colors.white, fontSize: 15,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              final h = briefing.overallHealthScore;
              final hc = _healthColor(h);
              final label = h >= 70 ? 'Saudável 🟢' : h >= 45 ? 'Atenção 🟡' : 'Crítico 🔴';
              IveDetailSheet.show(
                context,
                title: 'Health Score: $h/100',
                emoji: briefing.healthEmoji,
                humanExplanation:
                    'Saúde Geral do portfólio: $h/100 — $label.\n\n'
                    'Calculado com base em projetos ativos, ações executadas, '
                    'análises de mercado, oportunidades aprovadas e receita registrada.',
                evidence: [
                  IveEvidence(emoji: briefing.healthEmoji, label: 'Saúde Geral',  value: '$h/100'),
                  IveEvidence(emoji: '🏷️',                 label: 'Status',        value: label),
                  IveEvidence(emoji: '📋',                 label: 'Projetos',      value: '${briefing.projectCount}'),
                  IveEvidence(emoji: '📊',                 label: 'Análises',      value: '${briefing.analysisCount}'),
                  IveEvidence(emoji: '⚡',                 label: 'Ações',         value: '${briefing.actionsCount}'),
                  IveEvidence(emoji: '💡',                 label: 'Oportunidades', value: '${briefing.opportunitiesCount}'),
                ],
                screenName: 'Briefing Semanal',
              );
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: SizedBox(
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
    final card = Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
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
          ),
          Icon(Icons.info_outline_rounded, size: 12, color: color.withOpacity(0.5)),
        ],
      ),
    );

    if (item.detail.isEmpty) return card;
    return GestureDetector(
      onTap: () => IveDetailSheet.show(
        context,
        title: item.title,
        emoji: '📋',
        humanExplanation: item.detail.isNotEmpty ? item.detail : item.title,
        evidence: [
          IveEvidence(emoji: '📋', label: 'Insight da semana', value: item.title),
        ],
        screenName: 'Briefing Semanal',
      ),
      child: MouseRegion(cursor: SystemMouseCursors.click, child: card),
    );
  }
}

// ── Data Origin Card ──────────────────────────────────────────────────────────
class _DataOriginCard extends StatelessWidget {
  final WeeklyBriefing briefing;
  const _DataOriginCard({required this.briefing});

  @override
  Widget build(BuildContext context) {
    final h  = briefing.generatedAt.hour.toString().padLeft(2, '0');
    final m  = briefing.generatedAt.minute.toString().padLeft(2, '0');
    final d  = briefing.generatedAt.day.toString().padLeft(2, '0');
    final mo = briefing.generatedAt.month.toString().padLeft(2, '0');
    final y  = briefing.generatedAt.year;

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
          Row(
            children: [
              const Icon(Icons.analytics_rounded, color: _kPrimary, size: 14),
              const SizedBox(width: 6),
              const Text(
                'DADOS ANALISADOS',
                style: TextStyle(
                  color: _kPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                'Gerado em $d/$mo/$y às $h:$m',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Contadores de origem — clicáveis
          Row(
            children: [
              _CountChip(
                label: 'Projetos',
                value: briefing.projectCount,
                color: _kCyan,
                onTap: () => IveDetailSheet.show(
                  context,
                  title: 'Projetos Analisados: ${briefing.projectCount}',
                  emoji: '📋',
                  humanExplanation:
                      'Este briefing foi gerado com base em ${briefing.projectCount} projeto(s) do portfólio.\n\n'
                      'Os projetos são a principal fonte de dados para o Ecosystem Score, Health Score '
                      'e as recomendações semanais da IVE.',
                  evidence: <IveEvidence>[
                    IveEvidence(emoji: '📋', label: 'Total de projetos',     value: '${briefing.projectCount}'),
                    IveEvidence(emoji: '📊', label: 'Análises disponíveis',  value: '${briefing.analysisCount}'),
                    IveEvidence(emoji: '📅', label: 'Gerado em',             value: '${briefing.generatedAt.day}/${briefing.generatedAt.month}/${briefing.generatedAt.year}'),
                  ],
                  suggestedActions: <IveAction>[
                    IveAction(emoji: '📋', label: 'Ver Projetos', description: 'Acesse o Project Command Center para gerenciar projetos'),
                  ],
                  screenName: 'Briefing Semanal',
                ),
              ),
              const SizedBox(width: 8),
              _CountChip(
                label: 'Análises',
                value: briefing.analysisCount,
                color: _kGold,
                onTap: () => IveDetailSheet.show(
                  context,
                  title: 'Análises de Mercado: ${briefing.analysisCount}',
                  emoji: '📊',
                  humanExplanation:
                      'Há ${briefing.analysisCount} análise(s) de Market Intelligence disponíveis no portfólio.\n\n'
                      'As análises de mercado alimentam os scores de Oportunidade, Mercado e ROI do Ecosystem Score.',
                  evidence: <IveEvidence>[
                    IveEvidence(emoji: '📊', label: 'Total de análises',  value: '${briefing.analysisCount}'),
                    IveEvidence(emoji: '📋', label: 'Projetos',           value: '${briefing.projectCount}'),
                    IveEvidence(emoji: '💡', label: 'Oportunidades',      value: '${briefing.opportunitiesCount}'),
                  ],
                  suggestedActions: <IveAction>[
                    IveAction(emoji: '📊', label: 'Market Intelligence', description: 'Execute novas análises de mercado para projetos sem cobertura'),
                  ],
                  screenName: 'Briefing Semanal',
                ),
              ),
              const SizedBox(width: 8),
              _CountChip(
                label: 'Ações',
                value: briefing.actionsCount,
                color: _kOrange,
                onTap: () => IveDetailSheet.show(
                  context,
                  title: 'Ações no Pipeline: ${briefing.actionsCount}',
                  emoji: '⚡',
                  humanExplanation:
                      'Há ${briefing.actionsCount} ação(ões) no Action Engine do portfólio.\n\n'
                      'As ações executadas influenciam o Score de Momentum, Execução e ROI. '
                      'Mais ações concluídas = Health Score mais alto.',
                  evidence: <IveEvidence>[
                    IveEvidence(emoji: '⚡',  label: 'Total de ações',   value: '${briefing.actionsCount}'),
                    IveEvidence(emoji: '📋',  label: 'Projetos ativos',  value: '${briefing.projectCount}'),
                    IveEvidence(emoji: '💡',  label: 'Oportunidades',    value: '${briefing.opportunitiesCount}'),
                  ],
                  suggestedActions: <IveAction>[
                    IveAction(emoji: '⚡', label: 'Action Engine', description: 'Acesse o Action Engine para executar e registrar ações'),
                  ],
                  screenName: 'Briefing Semanal',
                ),
              ),
              const SizedBox(width: 8),
              _CountChip(
                label: 'Oportunidades',
                value: briefing.opportunitiesCount,
                color: _kGreen,
                onTap: () => IveDetailSheet.show(
                  context,
                  title: 'Oportunidades: ${briefing.opportunitiesCount}',
                  emoji: '💡',
                  humanExplanation:
                      'Há ${briefing.opportunitiesCount} oportunidade(s) identificadas no portfólio.\n\n'
                      'As oportunidades são geradas pelas análises de Market Intelligence e pelo '
                      'Opportunity Lab. Cada oportunidade aprovada aumenta o Score de Execução e ROI.',
                  evidence: <IveEvidence>[
                    IveEvidence(emoji: '💡', label: 'Total de oportunidades', value: '${briefing.opportunitiesCount}'),
                    IveEvidence(emoji: '📊', label: 'Análises de mercado',    value: '${briefing.analysisCount}'),
                    IveEvidence(emoji: '📋', label: 'Projetos',               value: '${briefing.projectCount}'),
                  ],
                  suggestedActions: <IveAction>[
                    IveAction(emoji: '💡', label: 'Opportunity Lab', description: 'Acesse o Opportunity Lab para explorar e aprovar oportunidades'),
                  ],
                  screenName: 'Briefing Semanal',
                ),
              ),
            ],
          ),

          // Projetos analisados
          if (briefing.analyzedProjectNames.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Projetos incluídos',
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: briefing.analyzedProjectNames.map((name) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kPrimary.withOpacity(0.25)),
                ),
                child: Text(
                  name,
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.value, required this.color, this.onTap});
  final String label;
  final int    value;
  final Color  color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 9),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return chip;
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: chip),
    );
  }
}
