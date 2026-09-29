import '../../l10n/app_localizations.dart';

/// R16 — GLOBAL LANGUAGE CONSISTENCY.
///
/// Several Edge Functions return *fixed-value* fields whose canonical values
/// are Portuguese codes (they are listed in `fixedValueFields` server-side so
/// the model never translates them): e.g. market-analysis
/// `investment_recommendation` ("SIM"/"CONDICIONAL"/"NÃO") and
/// `priority_actions[].impact|effort` ("Alto"/"Médio"/"Baixo").
///
/// Those codes are persisted and compared as-is — they must NEVER be
/// rewritten. These helpers only map a stored code to a DISPLAY label in the
/// presentation language. They are tolerant (case-, accent- and
/// whitespace-insensitive, and accept the English equivalents too) and fall
/// back to the raw value for anything unknown, so a legacy or unexpected
/// value is shown verbatim instead of crashing or disappearing.

/// Normalises an AI enum value for comparison: lower-case, accents stripped,
/// spaces/hyphens collapsed to `_`.
String normalizeAiEnum(String? raw) {
  if (raw == null) return '';
  const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const to   = 'aaaaaeeeeiiiiooooouuuuc';
  final lower = raw.trim().toLowerCase();
  final sb = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    sb.write(i >= 0 ? to[i] : ch);
  }
  return sb
      .toString()
      .replaceAll(RegExp(r'[\s\-]+'), '_');
}

// ── Investment recommendation (market-analysis) ────────────────────────────

enum AiInvestmentVerdict { yes, conditional, no, unknown }

AiInvestmentVerdict aiInvestmentVerdict(String? raw) {
  switch (normalizeAiEnum(raw)) {
    case 'sim':
    case 'yes':
      return AiInvestmentVerdict.yes;
    case 'condicional':
    case 'conditional':
      return AiInvestmentVerdict.conditional;
    case 'nao':
    case 'no':
      return AiInvestmentVerdict.no;
    default:
      return AiInvestmentVerdict.unknown;
  }
}

/// "SIM"/"CONDICIONAL"/"NÃO" → localized label; unknown → raw.
String aiInvestmentRecommendationLabel(String? raw, AppLocalizations l10n) {
  switch (aiInvestmentVerdict(raw)) {
    case AiInvestmentVerdict.yes:         return l10n.uxAiInvestmentYes;
    case AiInvestmentVerdict.conditional: return l10n.uxAiInvestmentConditional;
    case AiInvestmentVerdict.no:          return l10n.uxAiInvestmentNo;
    case AiInvestmentVerdict.unknown:     return raw ?? '';
  }
}

// ── Level scales (impact / effort / potential / risk / priority) ───────────

enum AiLevel { low, medium, high, critical, unknown }

AiLevel aiLevel(String? raw) {
  switch (normalizeAiEnum(raw)) {
    case 'baixo':
    case 'baixa':
    case 'low':
      return AiLevel.low;
    case 'medio':
    case 'media':
    case 'medium':
    case 'moderado':
    case 'moderada':
    case 'moderate':
      return AiLevel.medium;
    case 'alto':
    case 'alta':
    case 'high':
      return AiLevel.high;
    case 'critico':
    case 'critica':
    case 'critical':
      return AiLevel.critical;
    default:
      return AiLevel.unknown;
  }
}

/// Impact / effort / potential / risk level ("Alto"/"Médio"/"Baixo"/"crítico")
/// → localized label (PT masculine form); unknown → raw.
String aiLevelLabel(String? raw, AppLocalizations l10n) {
  switch (aiLevel(raw)) {
    case AiLevel.low:      return l10n.uxAiLevelLow;
    case AiLevel.medium:   return l10n.uxAiLevelMedium;
    case AiLevel.high:     return l10n.uxAiLevelHigh;
    case AiLevel.critical: return l10n.uxAiLevelCritical;
    case AiLevel.unknown:  return raw ?? '';
  }
}

/// Priority ("alta"/"média"/"baixa") → localized label (PT feminine form);
/// unknown → raw.
String aiPriorityLabel(String? raw, AppLocalizations l10n) {
  switch (aiLevel(raw)) {
    case AiLevel.low:      return l10n.uxAiPriorityLow;
    case AiLevel.medium:   return l10n.uxAiPriorityMedium;
    case AiLevel.high:     return l10n.uxAiPriorityHigh;
    case AiLevel.critical: return l10n.uxAiPriorityCritical;
    case AiLevel.unknown:  return raw ?? '';
  }
}

/// decision-simulator `risk_level` ("baixo"/"médio"/"alto"/"crítico").
String aiRiskLevelLabel(String? raw, AppLocalizations l10n) =>
    aiLevelLabel(raw, l10n);

// ── content-cluster ────────────────────────────────────────────────────────

/// `articles[].search_intent` ("informacional"/"navegacional"/"transacional"/
/// "comercial") → localized label; unknown → raw.
String aiSearchIntentLabel(String? raw, AppLocalizations l10n) {
  switch (normalizeAiEnum(raw)) {
    case 'informacional':
    case 'informational':
      return l10n.uxAiSearchIntentInformational;
    case 'navegacional':
    case 'navigational':
      return l10n.uxAiSearchIntentNavigational;
    case 'transacional':
    case 'transactional':
      return l10n.uxAiSearchIntentTransactional;
    case 'comercial':
    case 'commercial':
      return l10n.uxAiSearchIntentCommercial;
    default:
      return raw ?? '';
  }
}

/// `articles[].type` ("pillar"/"supporting"/"landing_page"/"comparison").
String aiArticleTypeLabel(String? raw, AppLocalizations l10n) {
  switch (normalizeAiEnum(raw)) {
    case 'pillar':
    case 'pilar':
      return l10n.uxAiArticleTypePillar;
    case 'supporting':
    case 'suporte':
    case 'apoio':
      return l10n.uxAiArticleTypeSupporting;
    case 'landing_page':
    case 'landingpage':
      return l10n.uxAiArticleTypeLandingPage;
    case 'comparison':
    case 'comparacao':
    case 'comparativo':
      return l10n.uxAiArticleTypeComparison;
    default:
      return raw ?? '';
  }
}

// ── opportunity-discovery ──────────────────────────────────────────────────

/// `opportunities[].type` ("content"/"seo"/"product"/"monetization"/
/// "partnership"/"platform"/"audience").
String aiOpportunityTypeLabel(String? raw, AppLocalizations l10n) {
  switch (normalizeAiEnum(raw)) {
    case 'content':
    case 'conteudo':
      return l10n.uxAiOpportunityTypeContent;
    case 'seo':
      return l10n.uxAiOpportunityTypeSeo;
    case 'product':
    case 'produto':
      return l10n.uxAiOpportunityTypeProduct;
    case 'monetization':
    case 'monetizacao':
      return l10n.uxAiOpportunityTypeMonetization;
    case 'partnership':
    case 'parceria':
      return l10n.uxAiOpportunityTypePartnership;
    case 'platform':
    case 'plataforma':
      return l10n.uxAiOpportunityTypePlatform;
    case 'audience':
    case 'audiencia':
    case 'publico':
      return l10n.uxAiOpportunityTypeAudience;
    default:
      return raw ?? '';
  }
}

/// Free-form timeframe such as "3-6 meses", "2 semanas", "30 dias" or
/// "3-6 months": the numeric range is kept and the unit is localized.
/// Anything that doesn't match that shape is returned unchanged.
String aiTimeframeLabel(String? raw, AppLocalizations l10n) {
  final value = (raw ?? '').trim();
  final m = RegExp(
    r'^(\d+(?:\s*(?:-|–|a|to)\s*\d+)?)\s+([A-Za-zÀ-ú]+)$',
  ).firstMatch(value);
  if (m == null) return value;
  final range = m.group(1)!
      .replaceAll(RegExp(r'\s*(?:–|a|to)\s*'), '-')
      .replaceAll(RegExp(r'\s*-\s*'), '-');
  switch (normalizeAiEnum(m.group(2))) {
    case 'meses':
    case 'mes':
    case 'months':
    case 'month':
      return range == '1' ? l10n.uxAiTimeframeOneMonth : l10n.uxAiTimeframeMonths(range);
    case 'semanas':
    case 'semana':
    case 'weeks':
    case 'week':
      return range == '1' ? l10n.uxAiTimeframeOneWeek : l10n.uxAiTimeframeWeeks(range);
    case 'dias':
    case 'dia':
    case 'days':
    case 'day':
      return range == '1' ? l10n.uxAiTimeframeOneDay : l10n.uxAiTimeframeDays(range);
    default:
      return value;
  }
}

// ── Campaign objectives (campaign builder) ─────────────────────────────────

/// Canonical campaign objective values. They are persisted as-is in
/// `campaigns.objective` and sent to generate-campaign — never translate the
/// stored value, only the label shown.
const List<String> kCampaignObjectives = [
  'Venda', 'Autoridade', 'Leads', 'Engajamento',
  'Lançamento', 'Tráfego', 'Venda Hotmart',
  'Venda Shopify', 'Venda Amazon', 'Assinatura',
];

String campaignObjectiveLabel(String? raw, AppLocalizations l10n) {
  switch (normalizeAiEnum(raw)) {
    case 'venda':
    case 'sales':
      return l10n.uxCampaignObjectiveSales;
    case 'autoridade':
    case 'authority':
      return l10n.uxCampaignObjectiveAuthority;
    case 'leads':
      return l10n.uxCampaignObjectiveLeads;
    case 'engajamento':
    case 'engagement':
      return l10n.uxCampaignObjectiveEngagement;
    case 'lancamento':
    case 'launch':
      return l10n.uxCampaignObjectiveLaunch;
    case 'trafego':
    case 'traffic':
      return l10n.uxCampaignObjectiveTraffic;
    case 'venda_hotmart':
      return l10n.uxCampaignObjectiveSalesOn('Hotmart');
    case 'venda_shopify':
      return l10n.uxCampaignObjectiveSalesOn('Shopify');
    case 'venda_amazon':
      return l10n.uxCampaignObjectiveSalesOn('Amazon');
    case 'assinatura':
    case 'subscription':
      return l10n.uxCampaignObjectiveSubscription;
    default:
      return raw ?? '';
  }
}
