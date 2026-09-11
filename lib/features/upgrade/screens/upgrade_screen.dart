import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/snackbar_utils.dart' show showSuccessSnack;
import '../../../data/models/quota_info.dart';
import '../../../providers/quota_provider.dart';

class UpgradeScreen extends ConsumerWidget {
  const UpgradeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotaAsync = ref.watch(currentQuotaProvider);

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
            child: quotaAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'Não foi possível carregar seu plano agora. Tente novamente em instantes.',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              data: (quota) => _UpgradeContent(quota: quota),
            ),
          ),
        ),
      ),
    );
  }
}

class _UpgradeContent extends ConsumerWidget {
  const _UpgradeContent({required this.quota});
  final QuotaInfo quota;

  static const _freeLimit = 5;
  static const _proLimit = 300;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Se o usuário já é Pro, mostra o limite REAL configurado no servidor
    // (profiles.monthly_limit) em vez do número padrão de marketing --
    // evita anunciar um limite diferente do que a cota realmente aplica
    // (achado do Codex Gate).
    final displayedProLimit = quota.isPro ? quota.limit : _proLimit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _UsageBanner(quota: quota),
        const SizedBox(height: 28),
        _PlanCard(
          title: 'Gratuito',
          subtitle: 'Plano atual',
          price: 'R\$ 0',
          period: '',
          isHighlighted: false,
          isCurrentPlan: !quota.isPro,
          badge: null,
          features: const [
            _Feature('$_freeLimit análises de IA por mês', true),
            _Feature('Análise de site, mercado e concorrência', true),
            _Feature('Estratégia e ações priorizadas', true),
            _Feature('Análises ilimitadas', false),
            _Feature('Prioridade no processamento', false),
            _Feature('Suporte prioritário', false),
          ],
          buttonLabel: quota.isPro ? 'Plano anterior' : 'Plano atual',
          onPressed: null,
        ),
        const SizedBox(height: 16),
        _PlanCard(
          title: 'Pro',
          subtitle: 'Para quem já está executando a estratégia',
          price: 'R\$ 29',
          period: '/mês',
          isHighlighted: !quota.isPro,
          isCurrentPlan: quota.isPro,
          badge: quota.isPro ? 'Seu plano' : 'Mais popular',
          features: [
            _Feature('$displayedProLimit análises de IA por mês', true),
            const _Feature('Análise de site, mercado e concorrência', true),
            const _Feature('Estratégia e ações priorizadas', true),
            const _Feature('Prioridade no processamento', true),
            const _Feature('Suporte prioritário por e-mail', true),
            const _Feature('Acesso a novos recursos primeiro', true),
          ],
          buttonLabel: quota.isPro ? 'Plano atual' : '🚀  Assinar Pro — R\$ 29/mês',
          onPressed: quota.isPro ? null : () => _onUpgradeTap(context, ref),
        ),
        const SizedBox(height: 32),
        const _FaqSection(freeLimit: _freeLimit, proLimit: _proLimit),
      ],
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
  const _UsageBanner({required this.quota});
  final QuotaInfo quota;

  @override
  Widget build(BuildContext context) {
    final remaining = quota.remaining;

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
                'Análises de IA este mês',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Colors.white70),
              ),
              const Spacer(),
              Text(
                '${quota.used} / ${quota.limit}',
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
              value: quota.fractionUsed,
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                quota.isExhausted ? Colors.red : const Color(0xFF6C63FF),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            remaining > 0
                ? '$remaining análise${remaining == 1 ? '' : 's'} restante${remaining == 1 ? '' : 's'} no plano ${quota.isPro ? 'Pro' : 'gratuito'}.'
                : 'Você usou todas as análises de IA deste mês.',
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
    required this.isCurrentPlan,
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
  final bool isCurrentPlan;
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
              decoration: BoxDecoration(
                color: isCurrentPlan ? const Color(0xFF03DAC6) : _primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
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
  const _FaqSection({required this.freeLimit, required this.proLimit});
  final int freeLimit;
  final int proLimit;

  @override
  Widget build(BuildContext context) {
    final items = [
      _FaqItem(
        q: 'Como funciona o limite gratuito?',
        a: 'Você pode fazer até $freeLimit análises de IA por mês no plano gratuito (análise de site, estratégia, mercado, etc). O contador reinicia todo dia 1º.',
      ),
      _FaqItem(
        q: 'Posso cancelar a qualquer momento?',
        a: 'Sim. O plano Pro é mensal e você pode cancelar a qualquer momento sem taxa.',
      ),
      const _FaqItem(
        q: 'Meus dados ficam salvos se eu cancelar?',
        a: 'Sim. Seu histórico e projetos ficam salvos, mas o limite de análises volta para o do plano gratuito.',
      ),
    ];

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
        ...items.map((item) => _FaqTile(item: item)),
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
