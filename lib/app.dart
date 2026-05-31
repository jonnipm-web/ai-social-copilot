import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/screens/admin_dashboard_screen.dart';
import 'features/admin/screens/brand_studio/brand_form_screen.dart';
import 'features/admin/screens/brand_studio/brand_studio_screen.dart';
import 'features/admin/screens/calendar/calendar_screen.dart';
import 'features/admin/screens/content_library/content_item_form_screen.dart';
import 'features/admin/screens/content_library/content_library_screen.dart';
import 'features/admin/screens/extract/excerpt_extractor_screen.dart';
import 'features/admin/screens/history/advanced_history_screen.dart';
import 'features/admin/screens/personas/persona_form_screen.dart';
import 'features/admin/screens/personas/personas_screen.dart';
import 'features/admin/screens/repurpose/repurposing_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/history/screens/history_detail_screen.dart';
import 'features/history/screens/history_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/result/screens/result_screen.dart';
import 'features/splash/splash_screen.dart';

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
      path: AppConstants.routeHistoryDetail,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return HistoryDetailScreen(id: id);
      },
    ),

    // ── Modo Editorial (Admin) ──────────────────────────────
    GoRoute(
      path: AppConstants.routeAdmin,
      builder: (_, __) => const AdminDashboardScreen(),
    ),

    // Brand Studio
    GoRoute(
      path: AppConstants.routeAdminBrands,
      builder: (_, __) => const BrandStudioScreen(),
    ),
    GoRoute(
      path: AppConstants.routeAdminBrandsNew,
      builder: (_, __) => const BrandFormScreen(),
    ),
    GoRoute(
      path: '/admin/brands/:brandId',
      builder: (_, state) =>
          BrandFormScreen(brandId: state.pathParameters['brandId']),
    ),

    // Personas
    GoRoute(
      path: AppConstants.routeAdminPersonas,
      builder: (_, __) => const PersonasScreen(),
    ),
    GoRoute(
      path: AppConstants.routeAdminPersonasNew,
      builder: (_, __) => const PersonaFormScreen(),
    ),
    GoRoute(
      path: '/admin/personas/:personaId',
      builder: (_, state) =>
          PersonaFormScreen(personaId: state.pathParameters['personaId']),
    ),

    // Biblioteca
    GoRoute(
      path: AppConstants.routeAdminLibrary,
      builder: (_, __) => const ContentLibraryScreen(),
    ),
    GoRoute(
      path: AppConstants.routeAdminLibraryNew,
      builder: (_, __) => const ContentItemFormScreen(),
    ),
    GoRoute(
      path: '/admin/library/:itemId',
      builder: (_, state) =>
          ContentItemFormScreen(itemId: state.pathParameters['itemId']),
    ),

    // Geradores
    GoRoute(
      path: AppConstants.routeAdminExtract,
      builder: (_, __) => const ExcerptExtractorScreen(),
    ),
    GoRoute(
      path: AppConstants.routeAdminRepurpose,
      builder: (_, __) => const RepurposingScreen(),
    ),
    GoRoute(
      path: AppConstants.routeAdminCalendar,
      builder: (_, __) => const CalendarScreen(),
    ),

    // Histórico avançado
    GoRoute(
      path: AppConstants.routeAdminHistory,
      builder: (_, __) => const AdvancedHistoryScreen(),
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
