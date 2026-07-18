import '../../../core/constants/app_constants.dart';

abstract final class IveRouteContext {
  static const names = <String, String>{
    AppConstants.routeExecutiveDashboard: 'Executive Dashboard',
    AppConstants.routeProjects: 'Projetos',
    AppConstants.routeKnowledge: 'Knowledge Base',
    AppConstants.routeContent: 'Library',
    AppConstants.routeOpportunityLab: 'Opportunity Lab',
    AppConstants.routeActionEngine: 'Action Engine',
    AppConstants.routeEcosystem: 'Decisões',
    AppConstants.routeEcosystemBriefing: 'Briefing',
    AppConstants.routeEcosystemResources: 'Recursos',
    AppConstants.routePersonas: 'Personas',
    AppConstants.routeIntelligenceDebug: 'Debug Hub',
    AppConstants.routeMarketIntelligence: 'Inteligência de Mercado',
    AppConstants.routeRoiTracker: 'ROI Tracker',
  };

  static String normalize(String location) {
    final path = Uri.tryParse(location)?.path ?? location.split('?').first;
    String best = '';
    for (final candidate in names.keys) {
      if ((path == candidate || path.startsWith('$candidate/')) &&
          candidate.length > best.length) {
        best = candidate;
      }
    }
    return best.isEmpty ? path : best;
  }

  static String displayName(String location) {
    final normalized = normalize(location);
    return names[normalized] ?? normalized;
  }
}
