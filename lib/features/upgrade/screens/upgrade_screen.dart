import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/snackbar_utils.dart' show showSuccessSnack;
import '../../../providers/post_provider.dart';

class UpgradeScreen extends ConsumerWidget {
  const UpgradeScreen({super.key});

  static const _primary = Color(0xFF6C63FF);
  static const _gold = Color(0xFFFFD700);
  static const _surface = Color(0xFF1A1A2E);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usageAsync = ref.watch(monthlyUsageProvider);
    final used = usageAsync.valueOrNull ?? 0;
    final limit = AppConstants.freeTierLimit;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planos'),
        leading: const BackButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppConstants.maxBodyWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _UsageBanner(used: used, limit: limit),
                const SizedBox(height: 28),
                _PlanCard(
                  title: 'Gratuito',
                  subtitle: 'Plano atual',
                  price: 'R\$ 0',
                  period: '',
                  isHighlighted: false,
                  badge: null,
                  features: [
                    _Feature('$limit gerações por mês', true),
                    _Feature('Todas as versões de post', true),
                    _Feature('Histórico dos últimos 50 posts', true),
                    _Feature('Gerações ilimitadas', false),
                    _Feature('Prioridade no processamento', false),
                    _Feature('Suporte prioritário', false),
                  ],
                  buttonLabel: 'Plano atual',
                  onPressed: null,
                ),
                const SizedBox(height: 16),
                _PlanCard(
                  title: 'Pro',
                  subtitle: 'Para criadores sérios',
                  price: 'R\$ 29',
                  period: '/mês',
                  isHighlighted: true,
                  badge: 'Mais popular',
                  features: const [
                    _Feature('Gerações ilimitadas', true),
                    _Feature('Todas as versões de post', true),
                    _Feature('Histórico completo sem limite', true),
                    _Feature('Prioridade no processamento', true),
                    _Feature('Suporte prioritário por e-mail', true),
                    _Feature('Acesso a novos recursos primeiro', true),
                  ],
                  buttonLabel: '🚀  Assinar Pro — R\$ 29/mês',
                  onPressed: () => _onUpgradeTap(context, ref),
                ),
                const SizedBox(height: 32),
                _FaqSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onUpgradeTap(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Em breve!'),
        content: const Text(
          'O pagamento online estará disponível em breve.\n\n'
          'Entre em contato pelo e-mail para assinar agora:\n'
          'suporte@aisocialcopilot.com',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              showSuccessSnack(context, 'Entraremos em contato em breve!');
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _UsageBanner extends StatelessWidget {
  const _UsageBanner({required this.used, required this.limit});
  final int used;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final pct = (used / limit).clamp(0.0, 1.0);
    final remaining = limit - used;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFF6C63FF)),
              const SizedBox(width: 6),
              Text(
                'Uso este mês',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Colors.white70),
              ),
              const Spacer(),
              Text(
                '$used / $limit',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                pct >= 1.0 ? Colors.red : const Color(0xFF6C63FF),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            remaining > 0
                ? '$remaining geração${remaining == 1 ? '' : 'ões'} restante${remaining == 1 ? '' : 's'} no plano gratuito.'
                : 'Você usou todas as gerações gratuitas deste mês.',
            style: TextStyle(
              fontSize: 12,
              color: remaining > 0 ? Colors.white54 : Colors.red.shade300,
            ),
          ),
        ],
      ),
    );
  }
}

class _Feature {
  const _Feature(this.label, this.included);
  final String label;
  final bool included;
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.period,
    required this.isHighlighted,
    required this.badge,
    required this.features,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String price;
  final String period;
  final bool isHighlighted;
  final String? badge;
  final List<_Feature> features;
  final String buttonLabel;
  final VoidCallback? onPressed;

  static const _primary = Color(0xFF6C63FF);
  static const _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? _primary : Colors.white12,
          width: isHighlighted ? 2 : 1,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: _primary.withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: const BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Text(
                badge!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isHighlighted) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.star_rounded, color: _gold, size: 18),
                    ],
                  ],
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13, color: Colors.white54),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (period.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4, left: 2),
                        child: Text(
                          period,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12),
                const SizedBox(height: 12),
                ...features.map((f) => _FeatureRow(feature: f)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: onPressed,
                  style: onPressed == null
                      ? ElevatedButton.styleFrom(
                          backgroundColor: Colors.white10,
                          foregroundColor: Colors.white38,
                        )
                      : null,
                  child: Text(buttonLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.feature});
  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            feature.included
                ? Icons.check_circle_rounded
                : Icons.cancel_rounded,
            size: 18,
            color: feature.included ? const Color(0xFF03DAC6) : Colors.white24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              feature.label,
              style: TextStyle(
                fontSize: 14,
                color: feature.included ? Colors.white : Colors.white38,
                decoration:
                    feature.included ? null : TextDecoration.lineThrough,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqSection extends StatelessWidget {
  final _items = const [
    _FaqItem(
      q: 'Como funciona o limite gratuito?',
      a: 'Você pode gerar até ${AppConstants.freeTierLimit} posts por mês no plano gratuito. O contador reinicia todo dia 1º.',
    ),
    _FaqItem(
      q: 'Posso cancelar a qualquer momento?',
      a: 'Sim. O plano Pro é mensal e você pode cancelar a qualquer momento sem taxa.',
    ),
    _FaqItem(
      q: 'Meus dados ficam salvos se eu cancelar?',
      a: 'Sim. Seu histórico fica salvo, mas o limite de gerações volta para ${AppConstants.freeTierLimit}/mês.',
    ),
  ];

  const _FaqSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Perguntas frequentes',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ..._items.map((item) => _FaqTile(item: item)),
      ],
    );
  }
}

class _FaqItem {
  const _FaqItem({required this.q, required this.a});
  final String q;
  final String a;
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.item});
  final _FaqItem item;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      title: Text(
        item.q,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      children: [
        Text(
          item.a,
          style: const TextStyle(fontSize: 13, color: Colors.white70),
        ),
      ],
    );
  }
}
