class AppConstants {
  AppConstants._();

  static const appName = 'AI Social Copilot';
  static const minTextLength = 10;

  // Rotas
  static const routeSplash = '/';
  static const routeLogin = '/login';
  static const routeHome = '/home';
  static const routeResult = '/result';
  static const routeHistory = '/history';
  static const routeHistoryDetail = '/history/:id';
  static const routePaywall = '/paywall';

  // Supabase
  static const tablePostGenerations = 'post_generations';
  static const tableUserProfiles = 'user_profiles';
  static const edgeFunctionImprove = 'improve-post';
}
