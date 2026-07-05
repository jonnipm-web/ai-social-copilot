import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../providers/calendar_provider.dart';
import '../../../providers/content_provider.dart';
import '../../../providers/persona_provider.dart';
import '../../../providers/post_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../shared/widgets/app_drawer.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final usageAsync   = ref.watch(monthlyUsageProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
      ),
      drawer: const AppDrawer(),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Erro: $e')),
        data:    (profile) {
          final isAdmin = profile?.isAdmin ?? false;
          final isPro   = profile?.isPro   ?? false;
          final limit   = profile?.monthlyLimit ?? 5;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppConstants.maxBodyWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Boas-vindas
                    Text(
                      'Olá! Bem-vindo de volta 👋',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Plano: ${profile?.roleLabel ?? "Free"}',
                      style: const TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    const SizedBox(height: 24),

                    // Card de uso mensal
                    usageAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error:   (_, __) => const SizedBox.shrink(),
                      data:    (used) => _UsageCard(used: used, limit: limit),
                    ),
                    const SizedBox(height: 16),

                    // Ação principal
                    _ActionButton(
                      icon: Icons.auto_fix_high_rounded,
                      label: 'Melhorar Post com IA',
                      subtitle: 'Transforme seu texto agora',
                      color: const Color(0xFF6C63FF),
                      onTap: () => context.push(AppConstants.routeHome),
                    ),
                    const SizedBox(height: 12),

                    // Grid de atalhos
                    Row(
                      children: [
                        Expanded(
                          child: _ShortcutCard(
                            icon: Icons.person_pin_rounded,
                            label: 'Personas',
                            locked: !isPro && !isAdmin,
                            onTap: () => context.go(AppConstants.routePersonas),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ShortcutCard(
                            icon: Icons.library_books_rounded,
                            label: 'Biblioteca',
                            locked: !isPro && !isAdmin,
                            onTap: () => context.go(AppConstants.routeContent),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ShortcutCard(
                            icon: Icons.calendar_month_rounded,
                            label: 'Calendário',
                            locked: !isPro && !isAdmin,
                            onTap: () => context.go(AppConstants.routeCalendar),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ShortcutCard(
                            icon: Icons.history_rounded,
                            label: 'Histórico',
                            onTap: () => context.push(AppConstants.routeHistory),
                          ),
                        ),
                      ],
                    ),

                    // Painel Admin
                    if (isAdmin) ...[
                      const SizedBox(height: 24),
                      const Divider(color: Colors.white12),
                      const SizedBox(height: 12),
                      const Text(
                        'Admin',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _AdminStats(ref: ref),
                      const SizedBox(height: 12),
                      _ActionButton(
                        icon: Icons.admin_panel_settings_rounded,
                        label: 'Painel Administrativo',
                        subtitle: 'Usuários, personas e planos',
                        color: const Color(0xFFFFD700),
                        onTap: () => context.go(AppConstants.routeAdmin),
                      ),
                    ],

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.used, required this.limit});
  final int used;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final remaining = (limit - used).clamp(0, limit);
    final pct = limit > 0 ? used / limit : 0.0;
    final isFull = remaining <= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFull ? Icons.lock_outline_rounded : Icons.bolt_rounded,
                color: isFull ? Colors.red : Colors.teal,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                isFull
                    ? 'Limite atingido'
                    : '$remaining de $limit gerações restantes',
                style: TextStyle(
                  color: isFull ? Colors.red : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'este mês',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              backgroundColor: Colors.white12,
              color: isFull
                  ? Colors.red
                  : pct > 0.8
                      ? Colors.orange
                      : const Color(0xFF6C63FF),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String   label;
  final String   subtitle;
  final Color    color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.locked = false,
  });

  final IconData icon;
  final String   label;
  final VoidCallback onTap;
  final bool     locked;

  @override
  Widget build(BuildContext context) {
    final color = locked ? Colors.white24 : Colors.white70;

    return Material(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  Icon(icon, color: color, size: 28),
                  if (locked)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: const Icon(Icons.lock_rounded,
                          color: Colors.white24, size: 12),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminStats extends ConsumerWidget {
  const _AdminStats({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync   = ref.watch(allProfilesProvider);
    final personasAsync = ref.watch(personasProvider);
    final contentAsync = ref.watch(contentItemsProvider);

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Usuários',
            value: usersAsync.valueOrNull?.length.toString() ?? '—',
            icon: Icons.people_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            label: 'Personas',
            value: personasAsync.valueOrNull?.length.toString() ?? '—',
            icon: Icons.person_pin_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            label: 'Conteúdos',
            value: contentAsync.valueOrNull?.length.toString() ?? '—',
            icon: Icons.library_books_rounded,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String   label;
  final String   value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFFFD700), size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
