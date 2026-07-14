import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/market_analysis.dart';
import '../../../providers/market_analysis_provider.dart';
import '../../../shared/widgets/app_drawer.dart';

class MarketIntelligenceScreen extends ConsumerStatefulWidget {
  const MarketIntelligenceScreen({super.key});

  @override
  ConsumerState<MarketIntelligenceScreen> createState() =>
      _MarketIntelligenceScreenState();
}

class _MarketIntelligenceScreenState
    extends ConsumerState<MarketIntelligenceScreen> {
  final _inputCtrl = TextEditingController();
  String _inputType = 'url';

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final input = _inputCtrl.text.trim();
    if (input.isEmpty) return;
    final notifier = ref.read(marketAnalysisNotifierProvider.notifier);
    final result = await notifier.analyze(input, inputType: _inputType);
    if (result != null && mounted) {
      context.go(
        AppConstants.routeMarketIntelligenceHub.replaceFirst(':id', result.id),
      );
    }
  }

  static String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('404') || lower.contains('not_found') || lower.contains('not found')) {
      return 'A função de análise não foi encontrada no servidor. Verifique se as Edge Functions estão implantadas no Supabase Dashboard.';
    }
    if (lower.contains('401') || lower.contains('unauthorized') || lower.contains('jwt')) {
      return 'Sessão expirada. Saia e entre novamente no aplicativo.';
    }
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return 'A análise demorou demais. Tente novamente em alguns instantes.';
    }
    if (lower.contains('network') || lower.contains('socket') || lower.contains('connection')) {
      return 'Sem conexão com a internet. Verifique sua rede e tente novamente.';
    }
    if (lower.contains('groq') || lower.contains('api key') || lower.contains('apikey')) {
      return 'Chave de API não configurada no servidor. Configure GROQ_API_KEY nos secrets do Supabase.';
    }
    return 'Tente novamente em alguns instantes. Se o erro persistir, verifique o Supabase Dashboard.';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(marketAnalysisNotifierProvider);
    final analyses = ref.watch(marketAnalysesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppConstants.routeHome);
            }
          },
        ),
        backgroundColor: const Color(0xFF0F0F1A),
        title: const Text('Market Intelligence', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.analytics_rounded, color: Color(0xFF00BCD4), size: 28),
                        SizedBox(width: 12),
                        Text(
                          'Market Intelligence Engine',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Analise qualquer URL, domínio ou projeto para descobrir oportunidades de mercado, concorrentes e potencial de receita.',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Input type selector
              const Text('Tipo de entrada', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _TypeChip(label: 'URL / Domínio', value: 'url', selected: _inputType, onTap: (v) => setState(() => _inputType = v)),
                  const SizedBox(width: 8),
                  _TypeChip(label: 'Nicho', value: 'niche', selected: _inputType, onTap: (v) => setState(() => _inputType = v)),
                  const SizedBox(width: 8),
                  _TypeChip(label: 'Projeto', value: 'project', selected: _inputType, onTap: (v) => setState(() => _inputType = v)),
                ],
              ),
              const SizedBox(height: 16),

              // Input field
              TextField(
                controller: _inputCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: _inputType == 'url'
                      ? 'https://exemplo.com ou exemplo.com'
                      : _inputType == 'niche'
                          ? 'Ex: marketing digital para pequenas empresas'
                          : 'Descreva seu projeto ou ideia',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1A1A2E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF333355)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF333355)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF00BCD4)),
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38),
                ),
              ),
              const SizedBox(height: 16),

              // Analyze button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: state is AsyncLoading ? null : _analyze,
                  icon: state is AsyncLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.rocket_launch_rounded),
                  label: Text(
                    state is AsyncLoading ? 'Analisando...' : 'Analisar Mercado',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BCD4),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              if (state is AsyncError) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                          SizedBox(width: 6),
                          Text('Não foi possível conectar ao mecanismo de análise',
                              style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _friendlyError(state.error.toString()),
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // History
              const Text('Análises anteriores', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              analyses.when(
                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00BCD4))),
                error: (e, _) => Text('Erro: $e', style: const TextStyle(color: Colors.redAccent)),
                data: (list) => list.isEmpty
                    ? const Text('Nenhuma análise ainda.', style: TextStyle(color: Colors.white38))
                    : Column(
                        children: list.map((a) => _AnalysisCard(analysis: a)).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final String selected;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00BCD4) : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF00BCD4) : const Color(0xFF333355),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white60,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({required this.analysis});
  final MarketAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(
        AppConstants.routeMarketIntelligenceHub.replaceFirst(':id', analysis.id),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF333355)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF00BCD4).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${analysis.opportunityScore}',
                  style: const TextStyle(
                    color: Color(0xFF00BCD4),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    analysis.input,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    analysis.niche ?? analysis.inputType,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}
