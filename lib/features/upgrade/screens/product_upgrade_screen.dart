// IV-WEB-ECOSYSTEM-UNIFICATION-01 — per-product upgrade CTA screen.
//
// Shown when a user navigates to a product-gated route without owning the
// product. Receives ?product=impact|quant|suite as a query parameter.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';

class ProductUpgradeScreen extends StatelessWidget {
  final String product;

  const ProductUpgradeScreen({super.key, required this.product});

  static const _productNames = {
    'impact': 'InsightValues Impact',
    'quant': 'InsightValues Quant',
    'suite': 'InsightValues Suite',
  };

  static const _productDescriptions = {
    'impact': 'Monitore investimentos de impacto, acompanhe dossiês e descubra oportunidades de alto potencial.',
    'quant': 'Analise portfólios com dados quantitativos, watchlists inteligentes e insights de mercado em tempo real.',
    'suite': 'Acesso completo ao ecossistema InsightValues: Core, Impact e Quant em um único plano.',
  };

  @override
  Widget build(BuildContext context) {
    final productName = _productNames[product] ?? 'InsightValues $product';
    final description = _productDescriptions[product] ??
        'Faça upgrade para acessar este produto.';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produto não disponível'),
        leading: BackButton(onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppConstants.routeDashboard);
          }
        }),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 24),
              Text(
                productName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              Text(
                'Este produto não está incluído no seu plano atual. '
                'Entre em contato ou faça upgrade para obter acesso.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.go(AppConstants.routeUpgrade),
                  child: const Text('Ver opções de upgrade'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(AppConstants.routeDashboard);
                    }
                  },
                  child: const Text('Voltar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
