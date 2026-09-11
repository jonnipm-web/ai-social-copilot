import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/modules/module_definition.dart';
import '../../../core/modules/module_registry.dart';
import '../../../data/models/profile.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/profile_provider.dart';
import '../../../shared/widgets/app_drawer.dart';

class AdminPanelScreen extends ConsumerWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    // IVE-COMMERCIAL-RELEASE-CONTROL-PLANE-01 (Codex Gate, P1) — a checagem
    // anterior (`currentProfile != null && !currentProfile.isAdmin`) falhava
    // ABERTA: enquanto o FutureProvider ainda não resolveu (ou se falha),
    // `currentProfile` é null, a condição inteira é false, e o conteúdo
    // protegido renderiza (e as abas disparam suas próprias buscas de dados)
    // ANTES de qualquer confirmação de que o usuário é admin. Correção:
    // exigir positivamente `hasValue && isAdmin == true` -- loading/erro/
    // não-admin caem todos no mesmo estado "negado por padrão".
    if (profileAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final isAdmin = profileAsync.valueOrNull?.isAdmin ?? false;
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Acesso Negado')),
        body: const Center(
          child: Text('Você não tem permissão para acessar esta área.',
              style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppConstants.routeHome);
              }
            },
          ),
          title: const Text('Painel Admin'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Usuários'),
              Tab(text: 'Personas'),
              Tab(text: 'Visão Geral'),
              Tab(text: 'Módulos'),
            ],
          ),
        ),
        drawer: const AppDrawer(),
        body: const TabBarView(
          children: [
            _UsersTab(),
            _PersonasAdminTab(),
            _OverviewTab(),
            _ModulesAdminTab(),
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

// ── Tab: Módulos (Admin Module Control Plane) ──────────────────────────
// IVE-COMMERCIAL-RELEASE-CONTROL-PLANE-01 — inventário COMPLETO de
// módulos (não filtrado por commercialEnabled/plano como a navegação
// comercial normal). Admin vê tudo, sempre, com status visível, e pode
// abrir o detalhe de qualquer módulo tecnicamente seguro
// (adminClickable). Nunca expõe segredos/tokens/service_role -- só
// metadados de produto já públicos no próprio código.
class _ModulesAdminTab extends StatelessWidget {
  const _ModulesAdminTab();

  @override
  Widget build(BuildContext context) {
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    // Codex Gate (P3): antes filtrava por índice bruto sem checar
    // adminVisible -- hoje todo módulo tem adminVisible=true (então isto
    // era latente, não uma exposição ativa), mas o campo existe
    // exatamente para este filtro e deve ser respeitado de verdade.
    final visibleModules = kModuleRegistry.where((m) => m.adminVisible).toList();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: visibleModules.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
      itemBuilder: (context, i) {
        final module = visibleModules[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  isEnglish ? module.nameEn : module.namePt,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              _StatusBadge(status: module.status, isEnglish: isEnglish),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(
                  module.commercialEnabled ? Icons.check_circle_outline_rounded : Icons.remove_circle_outline_rounded,
                  size: 13,
                  color: module.commercialEnabled ? Colors.tealAccent : Colors.white24,
                ),
                const SizedBox(width: 4),
                Text(
                  module.commercialEnabled
                      ? (isEnglish ? 'Commercial' : 'Comercial')
                      : (isEnglish ? 'Not commercial' : 'Não comercial'),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(width: 10),
                Text(
                  isEnglish ? module.minimumPlan.labelEn : module.minimumPlan.labelPt,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          trailing: module.adminClickable
              ? const Icon(Icons.chevron_right_rounded, color: Colors.white38)
              : const Icon(Icons.block_rounded, color: Colors.white12, size: 18),
          onTap: module.adminClickable
              ? () => showModalBottomSheet(
                    context: context,
                    backgroundColor: const Color(0xFF141425),
                    isScrollControlled: true,
                    builder: (_) => _ModuleDetailSheet(module: module, isEnglish: isEnglish),
                  )
              : null,
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.isEnglish});
  final ModuleStatus status;
  final bool isEnglish;

  Color get _color => switch (status) {
        ModuleStatus.active => Colors.tealAccent,
        ModuleStatus.beta => const Color(0xFF6C63FF),
        ModuleStatus.inDevelopment => Colors.amber,
        ModuleStatus.disabled => Colors.white38,
        ModuleStatus.planned => Colors.white24,
        ModuleStatus.internal => const Color(0xFFFFD700),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _color.withOpacity(0.4)),
      ),
      child: Text(
        isEnglish ? status.labelEn : status.labelPt,
        style: TextStyle(color: _color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ModuleDetailSheet extends StatelessWidget {
  const _ModuleDetailSheet({required this.module, required this.isEnglish});
  final ModuleDefinition module;
  final bool isEnglish;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isEnglish ? module.nameEn : module.namePt,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                _StatusBadge(status: module.status, isEnglish: isEnglish),
              ],
            ),
            const SizedBox(height: 4),
            Text(module.moduleId, style: const TextStyle(color: Colors.white24, fontSize: 11, fontFamily: 'monospace')),
            const Divider(color: Colors.white12, height: 28),
            _DetailRow(label: t.adminModulesCommercial, value: module.commercialEnabled ? t.adminModulesYes : t.adminModulesNo),
            _DetailRow(label: t.adminModulesPlan, value: isEnglish ? module.minimumPlan.labelEn : module.minimumPlan.labelPt),
            _DetailRow(label: t.adminModulesRoute, value: module.route ?? t.adminModulesNoRoute),
            _DetailRow(label: t.adminModulesAi, value: module.aiDependency ? t.adminModulesYes : t.adminModulesNo),
            if (module.edgeFunctions.isNotEmpty)
              _DetailRow(label: 'Edge Functions', value: module.edgeFunctions.join(', ')),
            if (module.databaseDependencies.isNotEmpty)
              _DetailRow(label: isEnglish ? 'Tables' : 'Tabelas', value: module.databaseDependencies.join(', ')),
            const SizedBox(height: 12),
            Text(t.adminModulesReadiness, style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(isEnglish ? module.readinessEn : module.readinessPt, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            if (module.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(t.adminModulesNotes, style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(module.notes, style: const TextStyle(color: Colors.amber, fontSize: 13)),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12))),
        ],
      ),
    );
  }
}
