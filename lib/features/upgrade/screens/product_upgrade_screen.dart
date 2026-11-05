// IV-WEB-ECOSYSTEM-UNIFICATION-01 — per-product upgrade CTA screen.
//
// Shown when a user navigates to a product-gated route without owning the
// product, or when the entitlement check fails due to a network/RPC error.
// Query params: ?product=impact|quant|suite  and optional &state=unavailable.
import 'package:flutter/material.dart';
import 'package:ai_social_copilot/core/theme/app_tokens.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';

class ProductUpgradeScreen extends StatelessWidget {
  final String product;

  // true when the check failed due to a transient error (network/RPC),
  // not because the user doesn't own the product.
  final bool isUnavailable;

  const ProductUpgradeScreen({
    super.key,
    required this.product,
    this.isUnavailable = false,
  });

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

    final title = isUnavailable ? 'Produto temporariamente indisponível' : 'Produto não disponível';
    final icon = isUnavailable ? Icons.cloud_off_outlined : Icons.lock_outline;
    final bodyText = isUnavailable
        ? 'Não foi possível verificar seu acesso ao $productName no momento (falha de rede ou serviço). '
          'Tente novamente em alguns instantes.'
        : 'Este produto não está incluído no seu plano atual. '
          'Entre em contato ou faça upgrade para obter acesso.';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
              Icon(icon, size: 48),
              const SizedBox(height: 24),
              Text(
                productName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              if (!isUnavailable)
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              if (!isUnavailable) const SizedBox(height: 32),
              Text(
                bodyText,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              if (!isUnavailable)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => context.go(AppConstants.routeUpgrade),
                    child: const Text('Ver opções de upgrade'),
                  ),
                ),
              if (!isUnavailable) const SizedBox(height: 12),
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
                  child: isUnavailable ? const Text('Tentar novamente') : const Text('Voltar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
