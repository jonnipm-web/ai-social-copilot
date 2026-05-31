import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../providers/brand_provider.dart';
import '../../../providers/editorial_provider.dart';
import '../../../providers/persona_provider.dart';
import '../../../shared/widgets/admin_nav_drawer.dart';
import '../../../shared/widgets/feature_gate.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdminGuard(
      child: Scaffold(
        appBar: AppBar(title: const Text('Modo Editorial')),
        drawer: const AdminNavDrawer(),
        body: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppConstants.maxBodyWidth),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _SectionHeader(
                    label: 'Configuração', icon: Icons.settings_outlined),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DashCard(
                        icon: Icons.style_outlined,
                        label: 'Brand Studio',
                        subtitle: 'Marcas criadas',
                        color: const Color(0xFF6C63FF),
                        countProvider: brandsProvider
                            .select((v) => v.valueOrNull?.length ?? 0),
                        onTap: () => context.go(AppConstants.routeAdminBrands),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DashCard(
                        icon: Icons.people_outline,
                        label: 'Personas',
                        subtitle: 'Personas ativas',
                        color: const Color(0xFF03DAC6),
                        countProvider: allPersonasProvider
                            .select((v) => v.valueOrNull?.length ?? 0),
                        onTap: () =>
                            context.go(AppConstants.routeAdminPersonas),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _DashCard(
                  icon: Icons.library_books_outlined,
                  label: 'Biblioteca de Conteúdo',
                  subtitle: 'Textos-base salvos',
                  color: Colors.orange,
                  countProvider: null,
                  onTap: () => context.go(AppConstants.routeAdminLibrary),
                ),
                const SizedBox(height: 24),
                _SectionHeader(label: 'Geradores', icon: Icons.auto_awesome),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.format_quote_outlined,
                  label: 'Extrator de Trechos',
                  description:
                      '10 frases de impacto, 5 posts curtos, 3 carrosséis e mais',
                  onTap: () => context.go(AppConstants.routeAdminExtract),
                ),
                const SizedBox(height: 8),
                _ActionTile(
                  icon: Icons.auto_awesome_outlined,
                  label: 'Motor de Reaproveitamento',
                  description:
                      'De um capítulo gera posts, carrosséis, Reels, e-mail e artigo',
                  onTap: () => context.go(AppConstants.routeAdminRepurpose),
                ),
                const SizedBox(height: 8),
                _ActionTile(
                  icon: Icons.calendar_month_outlined,
                  label: 'Calendário Editorial',
                  description: '7, 15 ou 30 dias de conteúdo estratégico',
                  onTap: () => context.go(AppConstants.routeAdminCalendar),
                ),
                const SizedBox(height: 24),
                _SectionHeader(
                    label: 'Histórico', icon: Icons.history_edu_outlined),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.history_edu_outlined,
                  label: 'Histórico Avançado',
                  description: 'Todos os conteúdos gerados com status editorial',
                  onTap: () => context.go(AppConstants.routeAdminHistory),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 14, color: Colors.white38),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white38,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      );
}

class _DashCard extends ConsumerWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final ProviderListenable<int>? countProvider;
  final VoidCallback onTap;

  const _DashCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.countProvider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = countProvider != null ? ref.watch(countProvider!) : 0;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 12),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style:
                      const TextStyle(fontSize: 11, color: Colors.white38)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon, color: const Color(0xFF6C63FF)),
          title: Text(label,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Text(description,
              style: const TextStyle(fontSize: 12, color: Colors.white54)),
          trailing: const Icon(Icons.chevron_right, color: Colors.white38),
          onTap: onTap,
        ),
      );
}
