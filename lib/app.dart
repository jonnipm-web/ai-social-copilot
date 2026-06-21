import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/history/screens/history_detail_screen.dart';
import 'features/history/screens/history_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/result/screens/result_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/upgrade/screens/upgrade_screen.dart';

final _router = GoRouter(
  initialLocation: AppConstants.routeSplash,
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final goingToAuth = state.fullPath == AppConstants.routeLogin;
    final goingToSplash = state.fullPath == AppConstants.routeSplash;

    if (goingToSplash) return null;
    if (session == null && !goingToAuth) return AppConstants.routeLogin;
    if (session != null && goingToAuth) return AppConstants.routeHome;
    return null;
  },
  routes: [
    GoRoute(
      path: AppConstants.routeSplash,
      builder: (_, __) => const SplashScreen(),
    ),
    GoRoute(
      path: AppConstants.routeLogin,
      builder: (_, __) => const LoginScreen(),
    ),
    GoRoute(
      path: AppConstants.routeHome,
      builder: (_, __) => const HomeScreen(),
    ),
    GoRoute(
      path: AppConstants.routeResult,
      builder: (context, state) {
        final extra = state.extra;
        // extra é null quando o usuário atualiza a página no navegador,
        // pois dados em memória não sobrevivem ao F5. Redireciona para home.
        if (extra == null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => context.go(AppConstants.routeHome),
          );
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final map = extra as Map<String, dynamic>;
        return ResultScreen(
          originalText: map['originalText'] as String,
          result: map['result'] as Map<String, dynamic>,
          processingSeconds: map['processingSeconds'] as double?,
        );
      },
    ),
    GoRoute(
      path: AppConstants.routeHistory,
      builder: (_, __) => const HistoryScreen(),
    ),
    GoRoute(
      path: AppConstants.routeUpgrade,
      builder: (_, __) => const UpgradeScreen(),
    ),
    GoRoute(
      path: AppConstants.routeHistoryDetail,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return HistoryDetailScreen(id: id);
      },
    ),
  ],
);

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: _router,
    );
  }
}
