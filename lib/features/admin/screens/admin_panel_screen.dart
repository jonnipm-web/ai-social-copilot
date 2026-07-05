import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/profile.dart';
import '../../../providers/profile_provider.dart';
import '../../../shared/widgets/app_drawer.dart';

class AdminPanelScreen extends ConsumerWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentProfile = ref.watch(currentProfileProvider).valueOrNull;

    // Proteção: só admin acessa
    if (currentProfile != null && !currentProfile.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Acesso Negado')),
        body: const Center(
          child: Text('Você não tem permissão para acessar esta área.',
              style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Painel Admin'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Usuários'),
              Tab(text: 'Personas'),
              Tab(text: 'Visão Geral'),
            ],
          ),
        ),
        drawer: const AppDrawer(),
        body: const TabBarView(
          children: [
            _UsersTab(),
            _PersonasAdminTab(),
            _OverviewTab(),
          ],
        ),
      ),
    );
  }
}

// ── Tab: Usuários ──────────────────────────────────────────────
class _UsersTab extends ConsumerWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allProfilesProvider);

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: Colors.white54))),
      data:    (users) {
        if (users.isEmpty) {
          return const Center(
            child: Text('Nenhum usuário encontrado.',
                style: TextStyle(color: Colors.white54)),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
          itemBuilder: (context, i) => _UserTile(user: users[i], ref: ref),
        );
      },
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.ref});
  final Profile   user;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(user.role);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: roleColor.withOpacity(0.2),
        child: Icon(Icons.person_rounded, color: roleColor, size: 20),
      ),
      title: Text(
        user.email ?? 'Sem e-mail',
        style: const TextStyle(color: Colors.white, fontSize: 14),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${user.roleLabel} · ${user.monthlyLimit} gerações/mês',
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.white38, size: 20),
        color: const Color(0xFF1A1A2E),
        onSelected: (value) async {
          if (value == 'toggle') {
            await ref
                .read(profileAdminNotifierProvider.notifier)
                .setActive(user.id, !user.isActive);
            ref.invalidate(allProfilesProvider);
          } else {
            await ref
                .read(profileAdminNotifierProvider.notifier)
                .updateRole(user.id, value);
            ref.invalidate(allProfilesProvider);
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'free',        child: Text('→ Free',         style: TextStyle(color: Colors.white70))),
          const PopupMenuItem(value: 'pro',         child: Text('→ Pro',          style: TextStyle(color: Colors.white70))),
          const PopupMenuItem(value: 'premium',     child: Text('→ Premium',      style: TextStyle(color: Colors.white70))),
          const PopupMenuItem(value: 'beta_tester', child: Text('→ Beta Tester',  style: TextStyle(color: Colors.white70))),
          const PopupMenuItem(value: 'admin',       child: Text('→ Admin',        style: TextStyle(color: Color(0xFFFFD700)))),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'toggle',
            child: Text(
              user.isActive ? 'Desativar' : 'Ativar',
              style: TextStyle(color: user.isActive ? Colors.red : Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':       return const Color(0xFFFFD700);
      case 'premium':     return const Color(0xFFB44FE8);
      case 'pro':         return const Color(0xFF6C63FF);
      case 'beta_tester': return Colors.teal;
      default:            return Colors.white38;
    }
  }
}

// ── Tab: Personas (admin) ──────────────────────────────────────
class _PersonasAdminTab extends ConsumerWidget {
  const _PersonasAdminTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Gerenciar todas as personas',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => context.push(AppConstants.routePersonaNew),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Nova Persona'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: OutlinedButton(
              onPressed: () => context.go(AppConstants.routePersonas),
              child: const Text('Abrir gestão de Personas'),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tab: Visão Geral ──────────────────────────────────────────
class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allProfilesProvider);
    final users = usersAsync.valueOrNull ?? [];

    final byRole = <String, int>{};
    for (final u in users) {
      byRole[u.role] = (byRole[u.role] ?? 0) + 1;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distribuição de Usuários',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ...['admin', 'premium', 'pro', 'beta_tester', 'free'].map((role) {
            final count = byRole[role] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RoleBar(role: role, count: count, total: users.length),
            );
          }),
          const SizedBox(height: 24),
          const Text(
            'Total de Usuários',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Text(
            '${users.length}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleBar extends StatelessWidget {
  const _RoleBar({required this.role, required this.count, required this.total});
  final String role;
  final int    count;
  final int    total;

  @override
  Widget build(BuildContext context) {
    final labels = {
      'admin': 'Admin', 'premium': 'Premium',
      'pro': 'Pro', 'beta_tester': 'Beta', 'free': 'Free',
    };
    final colors = {
      'admin': const Color(0xFFFFD700), 'premium': const Color(0xFFB44FE8),
      'pro': const Color(0xFF6C63FF), 'beta_tester': Colors.teal, 'free': Colors.white38,
    };
    final color = colors[role] ?? Colors.white38;
    final pct   = total > 0 ? count / total : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(labels[role] ?? role,
              style: TextStyle(color: color, fontSize: 13)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.white12,
              color: color,
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('$count', style: TextStyle(color: color, fontSize: 13)),
      ],
    );
  }
}
