class AppConstants {
  AppConstants._();

  static const appName = 'AI Social Copilot';
  static const minTextLength = 10;
  static const maxTextLength = 5000;
  static const freeTierLimit = 5;
  static const maxBodyWidth = 700.0;

  // Rotas
  static const routeSplash = '/';
  static const routeLogin = '/login';
  static const routeHome = '/home';
  static const routeResult = '/result';
  static const routeHistory = '/history';
  static const routeHistoryDetail = '/history/:id';
  static const routeUpgrade = '/upgrade';

  // Supabase
  static const tablePostGenerations = 'post_generations';
  static const edgeFunctionImprove = 'improve-post';
}
