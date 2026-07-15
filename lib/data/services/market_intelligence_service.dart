import '../models/action_queue_item.dart';
import '../models/execution_score.dart';
import '../models/market_analysis.dart';
import '../models/market_profile.dart';
import '../models/opportunity_lab_item.dart';
import '../models/project.dart';
import '../models/revenue_intelligence.dart';
import '../models/revenue_plan.dart';
import 'ecosystem_intelligence_service.dart';

class MarketIntelligenceService {
  final _ecoSvc = EcosystemIntelligenceService();

  List<MarketProfile> computeMarketProfiles({
    required List<Project> projects,
    required List<MarketAnalysis> analyses,
    required List<OpportunityLabItem> labItems,
  }) =>
      _ecoSvc.computeMarketProfiles(
        projects: projects,
        analyses: analyses,
        labItems: labItems,
      );

  List<RevenueIntelligence> computeRevenueIntelligence({
    required List<Project> projects,
    required List<MarketAnalysis> analyses,
    required List<RevenuePlan> revenuePlans,
  }) =>
      _ecoSvc.computeRevenueIntelligence(
        projects:      projects,
        analyses:      analyses,
        revenuePlans:  revenuePlans,
      );

  List<ExecutionScore> computeExecutionScores({
    required List<Project> projects,
    required List<ActionQueueItem> actions,
    required List<OpportunityLabItem> labItems,
  }) =>
      _ecoSvc.computeExecutionScores(
        projects:  projects,
        actions:   actions,
        labItems:  labItems,
      );
}
