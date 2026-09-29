import '../models/action_queue_item.dart';
import '../models/execution_score.dart';
import '../models/market_analysis.dart';
import '../models/market_profile.dart';
import '../models/opportunity_lab_item.dart';
import '../models/project.dart';
import '../models/revenue_intelligence.dart';
import '../models/revenue_plan.dart';
import '../../l10n/app_localizations.dart';
import 'ecosystem_intelligence_service.dart';

class MarketIntelligenceService {
  /// R16 — [l10n] is the presentation language; it is forwarded to the
  /// ecosystem engine so user-facing text it produces (e.g. execution-score
  /// signals) follows the selected UI language. Omitting it keeps legacy PT.
  MarketIntelligenceService({AppLocalizations? l10n})
      : _ecoSvc = EcosystemIntelligenceService(l10n: l10n);

  final EcosystemIntelligenceService _ecoSvc;

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
