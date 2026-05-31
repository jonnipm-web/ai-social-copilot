import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/role_provider.dart';

class FeatureGate extends ConsumerWidget {
  final Widget child;
  final Widget? fallback;

  const FeatureGate({
    super.key,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permAsync = ref.watch(userPermissionProvider);

    return permAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => fallback ?? const SizedBox.shrink(),
      data: (perm) {
        if (!perm.canAccessEditorial) {
          return fallback ??
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 48, color: Colors.white24),
                      SizedBox(height: 16),
                      Text(
                        'Acesso restrito',
                        style: TextStyle(color: Colors.white38, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              );
        }
        return child;
      },
    );
  }
}

class AdminGuard extends ConsumerWidget {
  final Widget child;

  const AdminGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permAsync = ref.watch(userPermissionProvider);

    return permAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(
        body: Center(
          child: Text('Erro ao verificar permissões',
              style: TextStyle(color: Colors.white54)),
        ),
      ),
      data: (perm) {
        if (!perm.role.isAdmin) {
          return Scaffold(
            appBar: AppBar(title: const Text('Acesso Negado')),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, size: 64, color: Colors.white24),
                  SizedBox(height: 16),
                  Text(
                    'Esta área é exclusiva para administradores.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),
          );
        }
        return child;
      },
    );
  }
}
