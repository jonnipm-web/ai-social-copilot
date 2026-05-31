class AppConstants {
  AppConstants._();

  static const appName = 'AI Social Copilot';
  static const minTextLength = 10;
  static const maxTextLength = 5000;
  static const maxBodyWidth = 700.0;

  // Rotas — app principal
  static const routeSplash = '/';
  static const routeLogin = '/login';
  static const routeHome = '/home';
  static const routeResult = '/result';
  static const routeHistory = '/history';
  static const routeHistoryDetail = '/history/:id';

  // Rotas — modo editorial (admin)
  static const routeAdmin = '/admin';
  static const routeAdminBrands = '/admin/brands';
  static const routeAdminBrandsNew = '/admin/brands/new';
  static const routeAdminPersonas = '/admin/personas';
  static const routeAdminPersonasNew = '/admin/personas/new';
  static const routeAdminLibrary = '/admin/library';
  static const routeAdminLibraryNew = '/admin/library/new';
  static const routeAdminExtract = '/admin/extract';
  static const routeAdminRepurpose = '/admin/repurpose';
  static const routeAdminCalendar = '/admin/calendar';
  static const routeAdminHistory = '/admin/history';

  // Supabase
  static const tablePostGenerations = 'post_generations';
  static const edgeFunctionImprove = 'improve-post';
  static const edgeFunctionExtract = 'extract-excerpts';
  static const edgeFunctionRepurpose = 'repurpose-content';
  static const edgeFunctionCalendar = 'generate-calendar';
}
