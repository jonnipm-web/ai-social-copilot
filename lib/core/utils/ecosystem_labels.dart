import '../../data/models/priority_recommendation.dart';
import '../../l10n/app_localizations.dart';

/// R16 — display mappers for Ecosystem Intelligence logic codes.
///
/// The verdict strings produced by `EcosystemIntelligenceService`
/// ('ANÁLISE INCOMPLETA' | 'ESCALAR' | 'ACELERAR' | 'MANTER' | 'VALIDAR' |
/// 'PAUSAR') are LOGIC KEYS compared across the app — they are never
/// translated in storage. Anything that DISPLAYS a verdict must go through
/// [ecosystemVerdictLabel] so it renders in the presentation language.
/// Unknown codes are returned unchanged.
String ecosystemVerdictLabel(String code, AppLocalizations l10n) {
  switch (code) {
    case 'ESCALAR':            return l10n.ecoVerdictScale;
    case 'ACELERAR':           return l10n.ecoVerdictAccelerate;
    case 'MANTER':             return l10n.ecoVerdictMaintain;
    case 'VALIDAR':            return l10n.ecoVerdictValidate;
    case 'PAUSAR':             return l10n.ecoVerdictPause;
    case 'ANÁLISE INCOMPLETA': return l10n.ecoVerdictIncomplete;
    default:                   return code;
  }
}

/// Localized label for a [RecommendationType] (replaces the PT-only
/// `PriorityRecommendation.typeLabel` getter for display purposes).
String recommendationTypeLabel(RecommendationType type, AppLocalizations l10n) {
  switch (type) {
    case RecommendationType.investProject:      return l10n.ecoRecTypeInvest;
    case RecommendationType.executeOpportunity: return l10n.ecoRecTypeExecute;
    case RecommendationType.runAction:          return l10n.ecoRecTypeAction;
    case RecommendationType.pauseProject:       return l10n.ecoRecTypePause;
    case RecommendationType.mitigateRisk:       return l10n.ecoRecTypeRisk;
    case RecommendationType.quickWin:           return l10n.ecoRecTypeQuickWin;
    case RecommendationType.waste:              return l10n.ecoRecTypeWaste;
  }
}
