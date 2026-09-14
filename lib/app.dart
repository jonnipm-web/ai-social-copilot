import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_lifecycle/profile_resume_policy.dart';
import 'core/constants/app_constants.dart';
import 'core/diagnostics/diagnostic_models.dart';
import 'core/modules/route_policy.dart';
import 'core/theme/app_theme.dart';
import 'data/models/profile.dart';
import 'providers/diagnostic_session_provider.dart';
import 'providers/profile_provider.dart';
import 'l10n/app_localizations.dart';
import 'providers/language_provider.dart';
import 'shared/widgets/ive_overlay.dart';
import 'features/admin/screens/admin_panel_screen.dart';
import 'features/about/screens/about_screen.dart';
import 'features/support/screens/support_screen.dart';
import 'features/account/screens/account_screen.dart';
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
import 'features/opportunity_lab/screens/opportunity_detail_screen.dart';
import 'features/action_engine/screens/action_engine_screen.dart';
import 'features/action_engine/screens/action_detail_screen.dart';
import 'features/dashboard/screens/executive_dashboard_screen.dart';
import 'features/debug/screens/intelligence_debug_hub_screen.dart';

final _iveObserver = IveRouteObserver();

// IVE-COMMERCIAL-TARGETED-REMEDIATION-06R — route-level commercial/plan
// entitlement gate (see lib/core/modules/route_policy.dart for the pure
// policy this wraps). Closes a real bypass: several live V1 screens
// (dashboard_screen.dart's "Personas"/"Biblioteca"/"Calendário" shortcuts,
// among others) already show a `locked` badge for non-PRO users but call
// the exact same `context.go(...)` regardless — the badge never actually
// blocked navigation. This redirect is the first and only place that does.
//
// Deliberately reuses ProviderScope.containerOf(context, listen: false)
// rather than converting `_router` into a Riverpod-managed provider with a
// refreshListenable: this check runs fresh on every navigation ATTEMPT
// (every context.go/push call already re-invokes `redirect`), which is
// exactly the threat model here (a user clicking a button or typing a
// URL) — no reactive re-evaluation of an already-open screen is needed for
// that, so none was added ("do not introduce a new redirect-state
// subsystem for this MVP").
Future<String?> _resolveEntitlementRedirect(BuildContext context, String path) async {
  // Cheap pre-check: the large majority of navigation targets (every free,
  // already-released V1 screen, plus login/splash/upgrade/account/about/
  // support) can never be denied, so most navigation never pays for a
  // profile read at all.
  if (!routeMayBeRestricted(path)) return null;

  bool isAdmin = false;
  bool isPro = false;
  bool profileResolved = false;
  // IVE-COMMERCIAL-TARGETED-REMEDIATION-06R (Codex adversarial review, P1) —
  // a bare `container.read(currentProfileProvider.future)` is not a durable
  // subscription: currentProfileProvider is `FutureProvider.autoDispose`,
  // and nothing here stops Riverpod from disposing it out from under this
  // await if no other widget happens to be watching it at that exact
  // moment (the common case in practice is that app_drawer.dart already
  // holds a real `ref.watch` on it, but this redirect must not depend on
  // some other screen happening to be mounted). `container.listen(...)`
  // opens a REAL keep-alive subscription for exactly the lifetime of this
  // await, guaranteeing the provider cannot be swept mid-fetch, however
  // many navigations happen to race through this function concurrently.
  ProviderSubscription<AsyncValue<Profile?>>? keepAlive;
  try {
    final container = ProviderScope.containerOf(context, listen: false);
    keepAlive = container.listen<AsyncValue<Profile?>>(
      currentProfileProvider,
      (_, __) {},
    );
    final profile = await container
        .read(currentProfileProvider.future)
        .timeout(const Duration(seconds: 8));
    isAdmin = profile?.isAdmin ?? false;
    isPro = profile?.isPro ?? false;
    profileResolved = true;
  } catch (_) {
    // Profile fetch failed or timed out -- fail closed (never grant PRO/
    // admin access) rather than hang navigation forever or guess "yes".
  } finally {
    keepAlive?.close();
  }

  final decision = evaluateRouteAccess(
    path: path,
    isAdmin: isAdmin,
    isPro: isPro,
    profileResolved: profileResolved,
  );
  switch (decision) {
    case RouteDecision.allow:
      return null;
    case RouteDecision.redirectUpgrade:
      return AppConstants.routeUpgrade;
    case RouteDecision.redirectDenied:
      return AppConstants.routeDashboard;
  }
}

// IVE-COMMERCIAL-OBSERVABILITY-07A — best-effort NAVIGATION event, covering
// mission section 04's "route requested / route allowed / route denied /
// redirect target". Never throws, never blocks navigation: if there's no
// active diagnostic session (the overwhelming common case for every real
// user) diagnosticLoggerProvider.logEvent is already a same-frame no-op
// (see DiagnosticLoggerService.logEvent), and if the ProviderScope/
// container itself can't be reached for any reason this is swallowed too.
void _logNavigation(BuildContext context, String path, String? redirectTarget) {
  try {
    final container = ProviderScope.containerOf(context, listen: false);
    container.read(diagnosticLoggerProvider).logEvent(
      category: DiagnosticCategory.navigation,
      eventName: redirectTarget == null ? 'route_allowed' : 'route_redirected',
      route: path,
      status: redirectTarget == null ? 'allowed' : 'redirected',
      metadata: {
        'from_route': path,
        if (redirectTarget != null) 'redirect_target': redirectTarget,
      },
    );
  } catch (_) {
    // Diagnostics must never affect real navigation.
  }
}

Future<String?> _computeRedirect(BuildContext context, GoRouterState state) async {
  final session = Supabase.instance.client.auth.currentSession;
  final path = state.fullPath ?? state.matchedLocation;
  final goingToAuth   = path == AppConstants.routeLogin;
  final goingToSplash = path == AppConstants.routeSplash;

  if (goingToSplash) return null;
  if (session == null && !goingToAuth) return AppConstants.routeLogin;
  if (session != null && goingToAuth)  return AppConstants.routeDashboard;
  if (session == null) return null; // goingToAuth, unauthenticated -- let /login render.

  return _resolveEntitlementRedirect(context, path);
}

// IVE-COMMERCIAL-OBSERVABILITY-07B — defense-in-depth only. Investigation
// (mission section 08) found the '/admin' GoRoute correctly registered and
// reachable both via in-app navigation and a genuinely cold, fresh direct
// URL load on the current production build; the owner's "GoException: no
// routes for location: /admin" could not be reproduced under either path,
// pointing to a stale browser-side cache/tab (a session left open across a
// deploy, or a stale cached service worker) rather than a routing defect.
// No routing table change was made for that reason alone. This
// errorBuilder is still added because GoRouter previously had NONE at all:
// any genuinely unmatched location — a typo, a stale bookmark, a future
// removed route — would otherwise surface GoRouter's raw exception text
// directly to the user instead of recovering gracefully.
Widget _errorScreen(BuildContext context, GoRouterState state) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Codex adversarial review — the callback runs on the NEXT frame, by
    // which point this screen may already be gone (a subsequent redirect
    // resolved first, or the whole route stack was replaced); calling
    // context.go on a disposed context throws. Guard with context.mounted.
    if (!context.mounted) return;
    final target = Supabase.instance.client.auth.currentSession == null
        ? AppConstants.routeLogin
        : AppConstants.routeDashboard;
    context.go(target);
  });
  return const Scaffold(body: Center(child: CircularProgressIndicator()));
}

final _router = GoRouter(
  initialLocation: AppConstants.routeSplash,
  observers: [_iveObserver],
  errorBuilder: _errorScreen,
  redirect: (context, state) async {
    final path = state.fullPath ?? state.matchedLocation;
    final redirectTarget = await _computeRedirect(context, state);
    if (path != AppConstants.routeSplash) {
      _logNavigation(context, path, redirectTarget);
    }
    return redirectTarget;
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

    // ── Conta / Sobre / Suporte (IVE-COMMERCIAL-RELEASE-CONTROL-PLANE-01) ──
    GoRoute(
      path: AppConstants.routeAccount,
      builder: (_, __) => const AccountScreen(),
    ),
    GoRoute(
      path: AppConstants.routeAbout,
      builder: (_, __) => const AboutScreen(),
    ),
    GoRoute(
      path: AppConstants.routeSupport,
      builder: (_, __) => const SupportScreen(),
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
      path: AppConstants.routeOpportunityDetail,
      builder: (_, state) => OpportunityDetailScreen(
        itemId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: AppConstants.routeActionEngine,
      builder: (_, __) => const ActionEngineScreen(),
    ),
    GoRoute(
      path: AppConstants.routeActionDetail,
      builder: (_, state) => ActionDetailScreen(
        itemId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: AppConstants.routeExecutiveDashboard,
      builder: (_, __) => const ExecutiveDashboardScreen(),
    ),

    // ── Fase 10F — Intelligence Debug & Observability ────────────────────
    GoRoute(
      path: AppConstants.routeIntelligenceDebug,
      builder: (_, __) => const IntelligenceDebugHubScreen(),
    ),
  ],
);

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

// IVE-COMMERCIAL-TARGETED-REMEDIATION-06S — paid-state refresh. See
// core/app_lifecycle/profile_resume_policy.dart for the pure decision this
// wraps. WidgetsBindingObserver.didChangeAppLifecycleState fires
// AppLifecycleState.resumed on Flutter web when the browser tab regains
// visibility/focus (the engine maps the Page Visibility API to it) — the
// existing, standard cross-platform Flutter mechanism the mission asked to
// prefer over any dart:html-specific code, and it needed nothing new:
// converting App to a State is the only structural change.
class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  Timer? _boundedRecheck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _boundedRecheck?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isAuthenticated = Supabase.instance.client.auth.currentSession != null;
    if (!shouldRefreshProfileOnResume(state: state, isAuthenticated: isAuthenticated)) {
      return;
    }
    ref.invalidate(currentProfileProvider);

    // Mission section 11's named timing race: Stripe Checkout runs in a
    // separate tab, so a user can complete payment and switch back to this
    // tab BEFORE the webhook has finished updating profiles.role — the
    // immediate invalidate above would then still (correctly, given the
    // server state at that exact moment) refetch FREE. Rather than poll
    // continuously (explicitly forbidden), this schedules exactly ONE
    // bounded follow-up refetch a few seconds later, covering the common
    // case where the webhook finishes shortly after the user returns.
    // Cancelled and rescheduled fresh on every new resume so rapid focus
    // changes never stack up multiple pending timers. If the webhook takes
    // longer than this window, the residual gap is real and NOT silently
    // claimed closed here (see the mission report) — any subsequent
    // navigation that needs a resolved profile still fails safe (never
    // fabricates PRO), and the next natural remount of Account/Upgrade
    // (or another resume) resolves it.
    _boundedRecheck?.cancel();
    _boundedRecheck = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      if (Supabase.instance.client.auth.currentSession == null) return;
      ref.invalidate(currentProfileProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(languageProvider);
    return MaterialApp.router(
      title:                      AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme:                      AppTheme.dark,
      routerConfig:               _router,
      locale:                     locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // Global safe area: evita que conteúdo fique atrás da barra de navegação
      // do Android (edge-to-edge mode). top: false pois o AppBar já cuida do topo.
      builder: (context, child) => SafeArea(
        top: false,
        left: false,
        right: false,
        child: Consumer(
          builder: (ctx, ref, _) => Stack(
            children: [
              child!,
              const IveOverlay(),
            ],
          ),
        ),
      ),
    );
  }
}
