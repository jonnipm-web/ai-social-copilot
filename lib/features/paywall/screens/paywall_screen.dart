import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/usage_provider.dart';

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usageAsync = ref.watch(usageProvider);
    final count = usageAsync.valueOrNull ?? freeMonthlyLimit;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plano Pro'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              const Icon(Icons.auto_awesome, size: 56, color: Color(0xFF7C3AED)),
              const SizedBox(height: 16),
              const Text(
                'AI Social Copilot Pro',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Posts ilimitados, todas as plataformas,\npara criadores sérios.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white60, height: 1.5),
              ),
              const SizedBox(height: 28),

              // Contador de uso
              _UsageMeter(count: count, limit: freeMonthlyLimit),
              const SizedBox(height: 28),

              // Card de preço
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F1F9E), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Pro',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text('R\$',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ),
                        Text('19',
                            style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(',90/mês',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Benefícios
              const _BenefitsList(),
              const SizedBox(height: 32),

              // CTA principal
              FilledButton.icon(
                onPressed: () => _subscribe(context),
                icon: const Icon(Icons.rocket_launch_rounded),
                label: const Text('Assinar Pro agora'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),

              // Continuar grátis
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Continuar com plano gratuito',
                  style: TextStyle(color: Colors.white38),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cancele a qualquer momento. Sem fidelidade.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.white24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _subscribe(BuildContext context) {
    // TODO: integrar RevenueCat
    // 1. Instale: purchases_flutter: ^8.5.0
    // 2. Configure em main.dart:
    //    await Purchases.configure(PurchasesConfiguration('sua_chave_revenuecat'));
    // 3. Substitua este método:
    //    await Purchases.purchaseStoreProduct(product);
    //    await Purchases.getCustomerInfo(); // verifica entitlement
    // 4. Configure webhook RevenueCat → Supabase Edge Function
    //    para setar user_profiles.is_pro = true/false
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pagamento em breve — configure o RevenueCat para ativar.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _UsageMeter extends StatelessWidget {
  const _UsageMeter({required this.count, required this.limit});

  final int count;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final fraction = (count / limit).clamp(0.0, 1.0);
    final isNearLimit = count >= limit - 2;
    final barColor = isNearLimit ? Colors.orange : const Color(0xFF7C3AED);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isNearLimit ? Colors.orange.withOpacity(0.3) : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Gerações este mês',
                  style: TextStyle(fontSize: 13, color: Colors.white60)),
              Text(
                '$count / $limit',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isNearLimit ? Colors.orange : Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          if (count >= limit) ...[
            const SizedBox(height: 8),
            const Text(
              'Limite atingido. Faça upgrade para continuar.',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
        ],
      ),
    );
  }
}

class _BenefitsList extends StatelessWidget {
  const _BenefitsList();

  @override
  Widget build(BuildContext context) {
    const benefits = [
      (Icons.all_inclusive_rounded, 'Gerações ilimitadas por mês'),
      (Icons.share_rounded, 'Versões para LinkedIn, Instagram e Twitter/X'),
      (Icons.tag_rounded, 'Hashtags sugeridas pela IA'),
      (Icons.record_voice_over_rounded, 'Brand Voice — IA aprende seu estilo'),
      (Icons.schedule_rounded, 'Agendamento com lembretes'),
      (Icons.support_agent_rounded, 'Suporte prioritário'),
    ];

    return Column(
      children: benefits
          .map(
            (b) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(b.$1, size: 18, color: const Color(0xFF7C3AED)),
                  const SizedBox(width: 12),
                  Text(b.$2,
                      style: const TextStyle(fontSize: 14, color: Colors.white70)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
