import '../../l10n/app_localizations.dart';

// COMMERCIAL-V1-PHYSICAL-QA-RECOVERY (PQ-05) — Owner physically confirmed
// the Competitor Discovery screen renders the raw canonical `type` value
// ('direct'/'indirect'/'aspirational') verbatim, uppercased, regardless of
// locale -- "ASPIRATIONAL"/"DIRECT"/"INDIRECT" showing in a PT-BR screen.
// Same pattern as opportunity_type_labels.dart's opportunityTypeLabel():
// maps the stable persisted value to a localized DISPLAY string only;
// nothing written to the database changes.
const List<String> kCompetitorTypes = ['direct', 'indirect', 'aspirational'];

String competitorTypeLabel(String canonical, AppLocalizations l10n) {
  switch (canonical) {
    case 'direct':       return l10n.miCompetitorTypeDirect;
    case 'indirect':     return l10n.miCompetitorTypeIndirect;
    case 'aspirational': return l10n.miCompetitorTypeAspirational;
    default:              return canonical; // unmapped/legacy value -- show as-is, never crash
  }
}
