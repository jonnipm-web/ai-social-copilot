import '../../data/models/opportunity_lab_item.dart';
import '../../l10n/app_localizations.dart';

// COMMERCIAL-EXPERIENCE-CLOSURE-16R (mission Section 15/20) — the
// persisted `opportunity_type` values (OpportunityLabItem.types) are
// stable canonical PT-BR strings ('expansão', 'novo produto', ...) used
// as-is throughout the dropdown, the list badge, and the detail badge --
// an English-locale user saw Portuguese words verbatim. Per the mission's
// own instruction ("Prefer: stable canonical persisted value + PT-BR
// display label + EN display label... Do not unnecessarily mutate
// persisted values"), this maps each canonical value to a localized
// DISPLAY string only; nothing written to the database changes.
String opportunityTypeLabel(String canonical, AppLocalizations l10n) {
  switch (canonical) {
    case 'expansão':      return l10n.oppTypeExpansao;
    case 'novo produto':  return l10n.oppTypeNovoProduto;
    case 'novo nicho':    return l10n.oppTypeNovoNicho;
    case 'afiliado':      return l10n.oppTypeAfiliado;
    case 'SaaS':          return l10n.oppTypeSaas;
    case 'ebook':         return l10n.oppTypeEbook;
    case 'curso':         return l10n.oppTypeCurso;
    case 'assinatura':    return l10n.oppTypeAssinatura;
    default:              return canonical; // unmapped/legacy value -- show as-is, never crash
  }
}

// Sanity check this stays exhaustive over OpportunityLabItem.types --
// exercised by test/features/opportunity_lab/opportunity_type_labels_test.dart.
const List<String> kOpportunityTypesCoveredByLabels = OpportunityLabItem.types;

// COMMERCIAL-V1-UX-RECONCILIATION -- opportunity_lab_screen.dart showed the
// raw persisted `status` value (OpportunityLabItem.statusValues) verbatim
// in the list card badge, same class of defect as R2/R8 fixed elsewhere
// this mission (explainable UI, no raw enum values facing the user).
String opportunityStatusLabel(String canonical, AppLocalizations l10n) {
  switch (canonical) {
    case 'pending':    return l10n.oppStatusPending;
    case 'analyzing':  return l10n.oppStatusAnalyzing;
    case 'approved':   return l10n.oppStatusApproved;
    case 'rejected':   return l10n.oppStatusRejected;
    case 'executing':  return l10n.oppStatusExecuting;
    default:           return canonical; // unmapped/legacy value -- show as-is, never crash
  }
}

const List<String> kOpportunityStatusesCoveredByLabels = OpportunityLabItem.statusValues;
