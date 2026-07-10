class AppConstants {
  AppConstants._();

  static const appName = 'AI Social Copilot';
  static const minTextLength = 10;
  static const maxTextLength = 5000;
  static const freeTierLimit = 9999;
  static const maxBodyWidth = 700.0;

  // Limites por papel
  static const Map<String, int> planLimits = {
    'admin':       99999,
    'premium':     1000,
    'pro':         100,
    'beta_tester': 50,
    'free':        5,
  };

  static int limitForRole(String role) => planLimits[role] ?? 5;

  // Rotas
  static const routeSplash         = '/';
  static const routeLogin          = '/login';
  static const routeDashboard      = '/dashboard';
  static const routeHome           = '/home';
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

  // Admin
  static const adminEmail = 'jpaulo.start@gmail.com';
}
