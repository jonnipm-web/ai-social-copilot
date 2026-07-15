import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/screens/admin_panel_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/calendar/screens/calendar_screen.dart';
import 'features/content/screens/content_form_screen.dart';
import 'features/content/screens/content_library_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/history/screens/history_detail_screen.dart';
import 'features/history/screens/history_screen.dart';
import 'features/home/screens/content_generation_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/personas/screens/persona_form_screen.dart';
import 'features/personas/screens/personas_screen.dart';
import 'features/result/screens/result_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/campaigns/screens/campaign_builder_screen.dart';
import 'features/campaigns/screens/campaign_detail_screen.dart';
import 'features/campaigns/screens/campaigns_screen.dart';
import 'features/knowledge/screens/knowledge_analysis_screen.dart';
import 'features/knowledge/screens/knowledge_item_form_screen.dart';
import 'features/knowledge/screens/knowledge_vault_screen.dart';
import 'features/knowledge/screens/strategy_screen.dart';
import 'features/upgrade/screens/upgrade_screen.dart';
import 'features/website_analyzer/screens/website_analyzer_screen.dart';
import 'features/website_analyzer/screens/website_analysis_result_screen.dart';
import 'features/performance/screens/performance_screen.dart';
import 'features/personas/screens/persona_training_screen.dart';
import 'features/market_intelligence/screens/market_intelligence_screen.dart';
import 'features/market_intelligence/screens/market_intelligence_hub_screen.dart';
import 'features/market_intelligence/screens/competitor_discovery_screen.dart';
import 'features/market_intelligence/screens/gap_analysis_screen.dart';
import 'features/market_intelligence/screens/opportunity_discovery_screen.dart';
import 'features/market_intelligence/screens/niche_discovery_screen.dart';
import 'features/market_intelligence/screens/content_cluster_screen.dart';
import 'features/market_intelligence/screens/revenue_planner_screen.dart';
import 'features/projects/screens/project_command_center_screen.dart';
import 'features/roi_tracker/screens/roi_tracker_screen.dart';
import 'features/ecosystem/screens/executive_decision_center_screen.dart';
import 'features/ecosystem/screens/resource_allocation_screen.dart';
import 'features/ecosystem/screens/weekly_briefing_screen.dart';
import 'features/advisor/screens/advisor_onboarding_screen.dart';
import 'features/opportunity_lab/screens/opportunity_lab_screen.dart';
import 'features/action_engine/screens/action_engine_screen.dart';
import 'features/dashboard/screens/executive_dashboard_screen.dart';

final _router = GoRouter(
  initialLocation: AppConstants.routeSplash,
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final goingToAuth   = state.fullPath == AppConstants.routeLogin;
    final goingToSplash = state.fullPath == AppConstants.routeSplash;

    if (goingToSplash) return null;
    if (session == null && !goingToAuth) return AppConstants.routeLogin;
    if (session != null && goingToAuth)  return AppConstants.routeDashboard;
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
      path: AppConstants.routeDashboard,
      builder: (_, __) => const DashboardScreen(),
    ),
    GoRoute(
      path: AppConstants.routeHome,
      builder: (_, __) => const HomeScreen(),
    ),
    GoRoute(
      path: AppConstants.routeGenerate,
      builder: (_, __) => const ContentGenerationScreen(),
    ),
    GoRoute(
      path: AppConstants.routeResult,
      builder: (context, state) {
        final extra = state.extra;
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
          originalText:      map['originalText'] as String,
          result:            map['result'] as Map<String, dynamic>,
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
    GoRoute(
      path: AppConstants.routeUpgrade,
      builder: (_, __) => const UpgradeScreen(),
    ),

    // ── Personas ───────────────────────────────────────────────
    GoRoute(
      path: AppConstants.routePersonas,
      builder: (_, __) => const PersonasScreen(),
    ),
    GoRoute(
      path: AppConstants.routePersonaNew,
      builder: (_, __) => const PersonaFormScreen(),
    ),
    GoRoute(
      path: AppConstants.routePersonaEdit,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return PersonaFormScreen(personaId: id);
      },
    ),

    // ── Biblioteca ─────────────────────────────────────────────
    GoRoute(
      path: AppConstants.routeContent,
      builder: (_, __) => const ContentLibraryScreen(),
    ),
    GoRoute(
      path: AppConstants.routeContentNew,
      builder: (_, __) => const ContentFormScreen(),
    ),
    GoRoute(
      path: AppConstants.routeContentEdit,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ContentFormScreen(itemId: id);
      },
    ),

    // ── Calendário ─────────────────────────────────────────────
    GoRoute(
      path: AppConstants.routeCalendar,
      builder: (_, __) => const CalendarScreen(),
    ),

    // ── Admin ──────────────────────────────────────────────────
    GoRoute(
      path: AppConstants.routeAdmin,
      builder: (_, __) => const AdminPanelScreen(),
    ),

    // ── Knowledge Vault ────────────────────────────────────────
    GoRoute(
      path: AppConstants.routeKnowledge,
      builder: (_, __) => const KnowledgeVaultScreen(),
    ),
    GoRoute(
      path: AppConstants.routeKnowledgeNew,
      builder: (_, __) => const KnowledgeItemFormScreen(),
    ),
    GoRoute(
      path: AppConstants.routeKnowledgeEdit,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return KnowledgeItemFormScreen(itemId: id);
      },
    ),
    GoRoute(
      path: AppConstants.routeKnowledgeAnalysis,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return KnowledgeAnalysisScreen(itemId: id);
      },
    ),
    GoRoute(
      path: AppConstants.routeKnowledgeStrategy,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return StrategyScreen(itemId: id);
      },
    ),

    // ── Campaigns ──────────────────────────────────────────────
    GoRoute(
      path: AppConstants.routeCampaigns,
      builder: (_, __) => const CampaignsScreen(),
    ),
    GoRoute(
      path: AppConstants.routeCampaignNew,
      builder: (context, state) {
        final itemId = state.extra as String? ?? '';
        return CampaignBuilderScreen(itemId: itemId);
      },
    ),
    GoRoute(
      path: AppConstants.routeCampaignDetail,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return CampaignDetailScreen(campaignId: id);
      },
    ),

    // ── Website Analyzer ───────────────────────────────────────
    GoRoute(
      path: AppConstants.routeWebsiteAnalyzer,
      builder: (_, __) => const WebsiteAnalyzerScreen(),
    ),
    GoRoute(
      path: AppConstants.routeWebsiteAnalysisResult,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return WebsiteAnalysisResultScreen(analysisId: id);
      },
    ),

    // ── Performance ────────────────────────────────────────────
    GoRoute(
      path: AppConstants.routePerformance,
      builder: (_, __) => const PerformanceScreen(),
    ),

    // ── Persona Training ───────────────────────────────────────
    GoRoute(
      path: AppConstants.routePersonaTraining,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final personaName = state.extra as String? ?? 'Persona';
        return PersonaTrainingScreen(personaId: id, personaName: personaName);
      },
    ),

    // ── Market Intelligence (Fase 9) ───────────────────────────
    GoRoute(
      path: AppConstants.routeMarketIntelligence,
      builder: (_, __) => const MarketIntelligenceScreen(),
    ),
    // Specific sub-routes MUST come before the :id catch-all
    GoRoute(
      path: AppConstants.routeMarketIntelligenceCompetitors,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return CompetitorDiscoveryScreen(analysisId: id);
      },
    ),
    GoRoute(
      path: AppConstants.routeMarketIntelligenceGaps,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return GapAnalysisScreen(analysisId: id);
      },
    ),
    GoRoute(
      path: AppConstants.routeMarketIntelligenceOpportunities,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return OpportunityDiscoveryScreen(analysisId: id);
      },
    ),
    GoRoute(
      path: AppConstants.routeMarketIntelligenceNiches,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return NicheDiscoveryScreen(analysisId: id);
      },
    ),
    GoRoute(
      path: AppConstants.routeMarketIntelligenceCluster,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ContentClusterScreen(analysisId: id);
      },
    ),
    GoRoute(
      path: AppConstants.routeMarketIntelligenceRevenue,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return RevenuePlannerScreen(analysisId: id);
      },
    ),
    // Hub :id catch-all MUST come last among /market-intelligence/* routes
    GoRoute(
      path: AppConstants.routeMarketIntelligenceHub,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return MarketIntelligenceHubScreen(analysisId: id);
      },
    ),

    // ── Projects ────────────────────────────────────────────────
    GoRoute(
      path: AppConstants.routeProjects,
      builder: (_, __) => const ProjectCommandCenterScreen(),
    ),

    // ── ROI Tracker ─────────────────────────────────────────────
    GoRoute(
      path: AppConstants.routeRoiTracker,
      builder: (_, __) => const RoiTrackerScreen(),
    ),

    // ── Fase 10A — Business Operating System ────────────────────
    GoRoute(
      path: AppConstants.routeEcosystem,
      builder: (_, __) => const ExecutiveDecisionCenterScreen(),
    ),

    // ── Fase 10B — Ecosystem Intelligence Layer ──────────────────
    GoRoute(
      path: AppConstants.routeEcosystemResources,
      builder: (_, __) => const ResourceAllocationScreen(),
    ),
    GoRoute(
      path: AppConstants.routeEcosystemBriefing,
      builder: (_, __) => const WeeklyBriefingScreen(),
    ),
    GoRoute(
      path: AppConstants.routeAdvisorOnboarding,
      builder: (_, __) => const AdvisorOnboardingScreen(),
    ),
    GoRoute(
      path: AppConstants.routeOpportunityLab,
      builder: (_, __) => const OpportunityLabScreen(),
    ),
    GoRoute(
      path: AppConstants.routeActionEngine,
      builder: (_, __) => const ActionEngineScreen(),
    ),
    GoRoute(
      path: AppConstants.routeExecutiveDashboard,
      builder: (_, __) => const ExecutiveDashboardScreen(),
    ),
  ],
);

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title:                      AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme:                      AppTheme.dark,
      routerConfig:               _router,
      // Global safe area: evita que conteúdo fique atrás da barra de navegação
      // do Android (edge-to-edge mode). top: false pois o AppBar já cuida do topo.
      builder: (context, child) => SafeArea(
        top: false,
        left: false,
        right: false,
        child: child!,
      ),
    );
  }
}
