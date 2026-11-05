// IV-QUANT-MACRO-05 FASE 11 — Quant product shell (/quant).
//
// Functional minimum: HOME → ENTER INSTRUMENT → ANALYZE → RESULTS →
// EXPLANATION → WATCHLIST. Admin/lab controls are NOT shown here.
// For full lab controls, use the Quant Lab screen (/quant-lab).
//
// MUST NOT contain:
//   - Buy/sell/broker actions (DENY_BY_V0 — AEF hard boundary)
//   - Price forecasts or investment recommendations
//   - Any numeric output not sourced from the deterministic quant engine
// See: docs/quant/QUANT_RESEARCH_ADVICE_BOUNDARY.md
import 'package:flutter/material.dart';
import 'package:ai_social_copilot/core/theme/app_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/profile_provider.dart';
import '../../shared/widgets/ive_exclusion_region.dart';
import '../../shared/widgets/quant_disclaimer_banner.dart';

class QuantScreen extends ConsumerStatefulWidget {
  const QuantScreen({super.key});

  @override
  ConsumerState<QuantScreen> createState() => _QuantScreenState();
}

class _QuantScreenState extends ConsumerState<QuantScreen> {
  final _symbolController = TextEditingController();

  @override
  void dispose() {
    _symbolController.dispose();
    super.dispose();
  }

  void _goToAnalyze() {
    // Routes to Quant Lab (full analysis surface) with the entered symbol.
    // The lab already implements the full ANALYZE → RESULTS → EXPLANATION →
    // WATCHLIST journey. Direct integration into this shell will happen on
    // lifecycle promotion to ALPHA (gate: Agente Martins + Paulo).
    final symbol = _symbolController.text.trim();
    if (symbol.isEmpty) return;
    context.go(AppConstants.routeQuantLab);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(currentProfileProvider);

    return IveExclusionRegion(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quant Analytics'),
          centerTitle: false,
          actions: [
            // Research/Advice boundary disclosure
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'About Quant Research',
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Research, Not Advice'),
                  content: const Text(
                    'InsightValues Quant provides historical market-data '
                    'analytics and mathematical metrics. It is financial '
                    'research, not investment advice.\n\n'
                    'No buy/sell recommendations are made. Past performance '
                    'does not guarantee future results. Review '
                    'QUANT_RESEARCH_ADVICE_BOUNDARY for full policy.',
                  ),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header ────────────────────────────────────────────
                      Text(
                        'Market Analytics',
                        style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Historical returns · volatility · signals · watchlists',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6)),
                      ),
                      const SizedBox(height: 28),

                      // ── Instrument entry ──────────────────────────────────
                      Text(
                        'Analyse an instrument',
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _symbolController,
                        decoration: InputDecoration(
                          hintText: 'e.g. AAPL, TSLA, MSFT',
                          labelText: 'Symbol',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: _goToAnalyze,
                          ),
                        ),
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) => _goToAnalyze(),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _goToAnalyze,
                        icon: const Icon(Icons.bar_chart_rounded),
                        label: const Text('Open in Quant Lab'),
                      ),
                      const SizedBox(height: 32),

                      // ── Journey cards ─────────────────────────────────────
                      _JourneyCard(
                        icon: Icons.show_chart,
                        title: 'Analyse',
                        subtitle: 'Upload CSV or connect your watchlist for server-side OHLCV data.',
                      ),
                      const SizedBox(height: 10),
                      _JourneyCard(
                        icon: Icons.analytics_outlined,
                        title: 'Results',
                        subtitle: 'Return · volatility · drawdown · SMA · Sharpe — all deterministic.',
                      ),
                      const SizedBox(height: 10),
                      _JourneyCard(
                        icon: Icons.lightbulb_outline,
                        title: 'Explanation',
                        subtitle: 'IVE narrates the engine output. It never fabricates numbers.',
                      ),
                      const SizedBox(height: 10),
                      _JourneyCard(
                        icon: Icons.playlist_add_check_rounded,
                        title: 'Watchlist',
                        subtitle: 'Save instruments to your watchlist for recurring analysis.',
                      ),
                      const SizedBox(height: 32),

                      // ── Access level chip ─────────────────────────────────
                      profileAsync.whenOrNull(
                        data: (p) => p != null
                            ? Row(
                                children: [
                                  Chip(
                                    label: Text('Role: ${p.role.toUpperCase()}'),
                                    avatar: const Icon(Icons.person, size: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  const Chip(
                                    label: Text('INTERNAL PILOT'),
                                    avatar: Icon(Icons.science_outlined, size: 16),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ) ??
                          const SizedBox.shrink(),
                    ],
                  ),
                ),
              ),

              // ── Mandatory disclaimer ───────────────────────────────────────
              // See QUANT_RESEARCH_ADVICE_BOUNDARY.md §5
              const QuantDisclaimerBanner(),
            ],
          ),
        ),
      ),
    );
  }
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        dense: false,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
      ),
    );
  }
}
