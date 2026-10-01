class AppConstants {
  AppConstants._();

  static const appName = 'InsightValues';
  static const minTextLength = 10;
  static const maxTextLength = 5000;

  // IVE-COMMERCIAL-AUTH-IMPORT-GATE — teto de tamanho para conteúdo baixado
  // diretamente como texto (TXT local e TXT/Google Docs exportado do Drive),
  // que não passa pelo process-file e por isso não tinha nenhum limite
  // checado antes desta missão. Mesma ordem de grandeza do teto efetivo já
  // usado no process-file (MAX_BASE64_LENGTH=8MB base64 ≈ 6MB decodificado).
  static const maxLocalImportBytes = 6 * 1024 * 1024;
  // FIX-008: was 9999 (stale placeholder). Mirrors planLimits['free'] = 15
  // below. Used as a UI fallback when quota hasn't loaded yet — a stale
  // 9999 would allow 9999 analyses client-side before the real gate fires.
  static const freeTierLimit = 15;
  static const maxBodyWidth = 700.0;

  // Limites por papel -- deve espelhar exatamente os valores usados pelo
  // servidor (supabase/functions/stripe-webhook/index.ts's PRO_ROLE_LIMIT/
  // FREE_ROLE_LIMIT e a coluna profiles.monthly_limit). Usado por
  // ProfileService.updateRole() no admin, que grava monthly_limit
  // diretamente a partir deste mapa -- um valor desatualizado aqui dá à
  // conta o limite errado quando um admin troca o papel manualmente
  // (achado durante COMMERCIAL-V1-PHYSICAL-QA-RECOVERY PQ-03: 'pro' já
  // estava desatualizado em 100 em vez dos 300 reais).
  // FREE=15 per decisão comercial do Owner (2026-09-30).
  // Migration 20261014000000_free_quota_15.sql aplicada em produção (APPLIED_PRODUCTION).
  // Servidor (profiles.monthly_limit default) espelha 15.
  static const Map<String, int> planLimits = {
    'admin':       99999,
    'premium':     1000,
    'pro':         300,
    'beta_tester': 50,
    'free':        15,
  };

  static int limitForRole(String role) => planLimits[role] ?? 15;

  // Rotas
  static const routeSplash         = '/';
  static const routeLogin          = '/login';
  static const routeDashboard      = '/dashboard';
  static const routeHome           = '/home';
  static const routeGenerate       = '/generate';
  static const routeResult         = '/result';
  static const routeHistory        = '/history';
  static const routeHistoryDetail  = '/history/:id';
  static const routeUpgrade        = '/upgrade';
  static const routePersonas       = '/personas';
  static const routePersonaNew     = '/personas/new';
  static const routePersonaEdit    = '/personas/:id/edit';
  static const routeContent        = '/content';
  static const routeContentNew     = '/content/new';
  static const routeContentEdit    = '/content/:id/edit';
  static const routeCalendar       = '/calendar';
  static const routeAdmin             = '/admin';
  static const routeKnowledge         = '/knowledge';
  static const routeKnowledgeNew      = '/knowledge/new';
  static const routeKnowledgeEdit     = '/knowledge/:id/edit';
  static const routeKnowledgeAnalysis = '/knowledge/:id/analysis';
  static const routeKnowledgeStrategy = '/knowledge/:id/strategy';
  static const routeCampaigns          = '/campaigns';
  static const routeCampaignNew        = '/campaigns/new';
  static const routeCampaignDetail     = '/campaigns/:id';
  static const routeWebsiteAnalyzer       = '/website-analyzer';
  static const routeWebsiteAnalysisResult = '/website-analyzer/:id';
  static const routePerformance           = '/performance';
  static const routePersonaTraining       = '/personas/:id/training';

  // Fase 9 — Market Intelligence
  static const routeMarketIntelligence            = '/market-intelligence';
  static const routeMarketIntelligenceCompetitors = '/market-intelligence/competitors/:id';
  static const routeMarketIntelligenceGaps        = '/market-intelligence/gaps/:id';
  static const routeMarketIntelligenceOpportunities = '/market-intelligence/opportunities/:id';
  static const routeMarketIntelligenceNiches      = '/market-intelligence/niches/:id';
  static const routeMarketIntelligenceCluster     = '/market-intelligence/content-cluster/:id';
  static const routeMarketIntelligenceRevenue     = '/market-intelligence/revenue/:id';
  static const routeMarketIntelligenceHub         = '/market-intelligence/:id';
  static const routeProjects                      = '/projects';
  static const routeRoiTracker                    = '/roi-tracker';

  // Fase 10A — Business Operating System
  static const routeEcosystem            = '/ecosystem';
  static const routeAdvisorOnboarding    = '/advisor-onboarding';
  static const routeOpportunityLab       = '/opportunity-lab';
  static const routeOpportunityDetail    = '/opportunity-lab/:id';
  static const routeActionEngine         = '/action-engine';
  static const routeActionDetail         = '/action-engine/:id';
  static const routeExecutiveDashboard   = '/executive-dashboard';

  // Fase 10B — Ecosystem Intelligence Layer
  static const routeEcosystemResources   = '/ecosystem/resources';
  static const routeEcosystemBriefing    = '/ecosystem/briefing';

  // Fase 10F — Intelligence Debug & Observability
  static const routeIntelligenceDebug    = '/intelligence-debug';

  // IV-IMPACT-I5 — Impact Lab (admin-only: module 'impact' is EXPERIMENTAL)
  static const routeImpact               = '/impact';
  static const routeImpactDossier        = '/impact/:id';

  // ROBOT-BUILDER-MACRO-05 — Strategy Lab (module 'strategy-builder' is COMMERCIAL, free tier)
  static const routeStrategyLab          = '/strategy-lab';

  // IV-QUANT-DATA-PLANE-AND-API-02 — Quant Lab (INTERNAL, admin-only)
  static const routeQuantLab             = '/quant-lab';

  // IVE-COMMERCIAL-RELEASE-CONTROL-PLANE-01
  static const routeAccount              = '/account';
  static const routeAbout                = '/about';
  static const routeSupport              = '/support';

  // Tabelas Supabase
  static const tablePostGenerations   = 'post_generations';
  static const tableProfiles          = 'profiles';
  static const tablePersonas          = 'personas';
  static const tableContentItems      = 'content_items';
  static const tableCalendarItems     = 'calendar_items';
  static const tableKnowledgeItems    = 'knowledge_items';
  static const tableKnowledgeAnalysis  = 'knowledge_analysis';
  static const tableKnowledgeStrategies = 'knowledge_strategies';
  static const tableCampaigns          = 'campaigns';
  static const tableCampaignCalendar   = 'campaign_calendar';
  static const tablePersonaTraining    = 'persona_training';
  static const tablePerformanceMetrics = 'performance_metrics';
  static const tableWebsiteAnalyses    = 'website_analyses';
  static const tableMarketAnalyses     = 'market_analyses';
  static const tableCompetitors        = 'competitors';
  static const tableGapAnalyses        = 'gap_analyses';
  static const tableOpportunities      = 'opportunities';
  static const tableNicheRankings      = 'niche_rankings';
  static const tableContentClusters    = 'content_clusters';
  static const tableRevenuePlans       = 'revenue_plans';
  static const tableProjects           = 'projects';
  static const tableRoiMetrics         = 'roi_metrics';

  // Fase 10A tables
  static const tableBusinessMemory     = 'business_memory';
  static const tableAdvisorProfiles    = 'advisor_profiles';
  static const tableOpportunityLab     = 'opportunity_lab';
  static const tableActionQueue        = 'action_queue';
  static const tableFeatureFlags       = 'feature_flags';
  static const tableCopilotSessions    = 'copilot_sessions';
  static const tableCopilotMessages    = 'copilot_messages';
  static const tableCopilotContext     = 'copilot_context';
  static const tableTrendSignals       = 'trend_signals';
  static const edgeFunctionMarket      = 'market-analysis';
  static const edgeFunctionCompetitor  = 'competitor-discovery';
  static const edgeFunctionGap         = 'gap-analysis';
  static const edgeFunctionOpportunity = 'opportunity-discovery';
  static const edgeFunctionNiche       = 'niche-discovery';
  static const edgeFunctionRevenue     = 'revenue-planner';
  static const edgeFunctionCluster     = 'content-cluster';
  static const edgeFunctionWebsite     = 'analyze-website';
  static const edgeFunctionImprove     = 'improve-post';
  static const edgeFunctionKnowledge   = 'extract-knowledge';
  static const edgeFunctionStrategy    = 'generate-strategy';
  static const edgeFunctionCampaign    = 'generate-campaign';
  static const edgeFunctionProcessFile = 'process-file';

  // Fase 10H — Knowledge → Action Engine
  static const edgeFunctionGenerateOpportunities = 'generate-project-opportunities';
  static const edgeFunctionGenerateActions        = 'generate-project-actions';

  // Fase 10K — Context Copilot
  static const edgeFunctionContextCopilot = 'context-copilot';
  // MODULE-FOUNDATION-AND-ENTITLEMENT-02 — capability discovery (server authority).
  static const edgeFunctionModuleAccess = 'module-access';
  // IVE-INTELLIGENCE-CORE-01 — server IVE Intelligence Core (Module Lab; not deployed).
  static const edgeFunctionIveIntelligence = 'ive-intelligence';

  // Fase 10L — Decision Simulator (IVE v1.1)
  static const edgeFunctionDecisionSimulator = 'decision-simulator';

  // Admin
  static const adminEmail = 'jpaulo.start@gmail.com';

  // IVE-COMMERCIAL-RELEASE-CONTROL-PLANE-01 — informações comerciais/legais.
  // supportEmail: única evidência de contato encontrada no histórico do
  // próprio repositório (commit cf806fa, tela de Upgrade original, usado
  // como canal real de suporte antes do checkout Stripe existir) -- não
  // inventado por esta missão.
  static const supportEmail = 'suporte@insigthvalues.com';
  // Site oficial hoje é o próprio deploy do GitHub Pages -- nenhum domínio
  // próprio foi encontrado configurado em nenhum lugar do repositório.
  static const officialWebsiteUrl = 'https://jonnipm-web.github.io/ai-social-copilot/';
  // Nenhuma página de Política de Privacidade ou Termos de Uso foi
  // encontrada em nenhum lugar do repositório ou configuração conhecida.
  // Deliberadamente null -- ver mission section 12 (não fabricar texto
  // legal). Reportado como OWNER CONTENT REQUIRED no relatório final.
  static const String? privacyPolicyUrl = null;
  static const String? termsOfUseUrl = null;
}
