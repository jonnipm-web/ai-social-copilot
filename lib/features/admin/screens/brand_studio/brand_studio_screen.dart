import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../data/models/brand.dart';
import '../../../../providers/brand_provider.dart';
import '../../../../shared/widgets/admin_nav_drawer.dart';
import '../../../../shared/widgets/feature_gate.dart';

class BrandStudioScreen extends ConsumerWidget {
  const BrandStudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brandsAsync = ref.watch(brandsProvider);

    return AdminGuard(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Brand Studio'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Nova Marca',
              onPressed: () => context.push(AppConstants.routeAdminBrandsNew),
            ),
          ],
        ),
        drawer: const AdminNavDrawer(),
        body: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppConstants.maxBodyWidth),
            child: brandsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Erro: $e',
                    style: const TextStyle(color: Colors.white54)),
              ),
              data: (brands) {
                if (brands.isEmpty) {
                  return _EmptyState(
                    onSeed: () async {
                      await ref
                          .read(brandNotifierProvider.notifier)
                          .seedIfEmpty();
                      if (context.mounted) {
                        showSuccessSnack(context, '3 marcas iniciais criadas!');
                      }
                    },
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(brandsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: brands.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _BrandCard(brand: brands[i]),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onSeed;

  const _EmptyState({required this.onSeed});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.style_outlined,
                  size: 64, color: Colors.white12),
              const SizedBox(height: 20),
              const Text(
                'Nenhuma marca criada ainda',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Inicialize com as 3 marcas padrão\nou crie uma nova.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onSeed,
                icon: const Icon(Icons.auto_fix_high, size: 16),
                label: const Text('Inicializar marcas padrão'),
              ),
            ],
          ),
        ),
      );
}

class _BrandCard extends ConsumerWidget {
  final Brand brand;

  const _BrandCard({required this.brand});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = brand.status == 'active'
        ? Colors.green
        : brand.status == 'inactive'
            ? Colors.orange
            : Colors.white24;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            context.push(AppConstants.routeAdminBrandsNew.replaceFirst('new', brand.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.style_outlined,
                      color: Color(0xFF6C63FF), size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(brand.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    if (brand.niche.isNotEmpty)
                      Text(
                        brand.niche,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white38),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(status: brand.status, color: statusColor),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                onSelected: (val) async {
                  await ref
                      .read(brandNotifierProvider.notifier)
                      .setStatus(brand.id, val);
                  if (context.mounted) {
                    showSuccessSnack(context, 'Status atualizado!');
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'active', child: Text('Ativar')),
                  PopupMenuItem(value: 'inactive', child: Text('Desativar')),
                  PopupMenuItem(value: 'archived', child: Text('Arquivar')),
                ],
                icon: const Icon(Icons.more_vert,
                    size: 18, color: Colors.white38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  final Color color;

  const _StatusPill({required this.status, required this.color});

  String get _label => switch (status) {
        'active' => 'Ativa',
        'inactive' => 'Inativa',
        'archived' => 'Arquivada',
        _ => status,
      };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
        ),
      );
}
