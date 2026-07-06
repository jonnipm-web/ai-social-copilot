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
  static const edgeFunctionImprove     = 'improve-post';
  static const edgeFunctionKnowledge   = 'extract-knowledge';
  static const edgeFunctionStrategy    = 'generate-strategy';
  static const edgeFunctionCampaign    = 'generate-campaign';
  static const edgeFunctionProcessFile = 'process-file';

  // Admin
  static const adminEmail = 'jpaulo.start@gmail.com';
}
