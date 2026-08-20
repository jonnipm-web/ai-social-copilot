import 'market_analysis.dart';
import 'opportunity_lab_item.dart';
import 'project.dart';

enum CompetitionLevel { alta, moderada, baixa }
enum MarketMaturity { emergente, crescendo, maduro, saturado }

class MarketProfile {
  final String projectId;
  final String projectName;
  final String market;
  final String niche;
  final String subNiche;
  final String targetAudience;
  final String businessModel;
  final CompetitionLevel competitionLevel;
  final int marketSize;
  final int growthPotential;
  final int globalPotential;
  final int localPotential;
  final MarketMaturity marketMaturity;
  final int marketScore;
  final int confidence;
  final String profileSource;
  final List<String> scoreExplanation;
  final DateTime computedAt;

  const MarketProfile({
    required this.projectId,
    required this.projectName,
    required this.market,
    required this.niche,
    required this.subNiche,
    required this.targetAudience,
    required this.businessModel,
    required this.competitionLevel,
    required this.marketSize,
    required this.growthPotential,
    required this.globalPotential,
    required this.localPotential,
    required this.marketMaturity,
    required this.marketScore,
    required this.confidence,
    required this.profileSource,
    required this.scoreExplanation,
    required this.computedAt,
  });

  String get competitionLabel {
    switch (competitionLevel) {
      case CompetitionLevel.alta:     return 'Alta';
      case CompetitionLevel.moderada: return 'Moderada';
      case CompetitionLevel.baixa:    return 'Baixa';
    }
  }

  String get maturityLabel {
    switch (marketMaturity) {
      case MarketMaturity.emergente:  return 'Emergente';
      case MarketMaturity.crescendo:  return 'Crescendo';
      case MarketMaturity.maduro:     return 'Maduro';
      case MarketMaturity.saturado:   return 'Saturado';
    }
  }

  String get marketScoreLabel {
    if (marketScore >= 80) return 'Excelente';
    if (marketScore >= 60) return 'Bom';
    if (marketScore >= 40) return 'Moderado';
    if (marketScore >= 20) return 'Baixo';
    return 'Insuficiente';
  }

  // ── Factory ────────────────────────────────────────────────────────────────

  static MarketProfile compute({
    required Project project,
    required MarketAnalysis? analysis,
    required List<OpportunityLabItem> labItems,
  }) {
    final pLab = labItems.where((l) => l.projectId == project.id).toList();

    String market, niche, subNiche, targetAudience, businessModel;
    int growthPotential, marketSize, globalPotential, localPotential;
    CompetitionLevel competitionLevel;
    MarketMaturity marketMaturity;
    String profileSource;
    int confidence;

    if (analysis != null) {
      // Rich data from market analysis
      market         = _inferMarket(analysis.niche ?? project.name);
      niche          = analysis.niche ?? project.name;
      subNiche       = analysis.subNiche ?? '';
      targetAudience = analysis.targetAudience ?? '';
      businessModel  = analysis.monetizationModel ?? _inferBizModel(project);
      growthPotential = analysis.scoreGrowth;
      marketSize      = _inferMarketSize(analysis);
      globalPotential = _inferGlobalPotential(analysis);
      localPotential  = _inferLocalPotential(analysis);
      competitionLevel = _competitionFromScore(analysis.scoreCompetition);
      marketMaturity   = _maturityFromGrowth(analysis.scoreGrowth);
      profileSource    = 'analysis';
      confidence       = 85;
    } else if (pLab.isNotEmpty) {
      // Derive from opportunity lab items
      market         = _inferMarket(project.name);
      niche          = project.description.isNotEmpty
          ? project.description.split(' ').take(3).join(' ')
          : project.name;
      subNiche       = project.type;
      targetAudience = '';
      businessModel  = _inferBizModel(project);
      final avgMarket   = pLab.map((l) => l.marketScore).fold(0, (a, b) => a + b) ~/ pLab.length;
      final avgRevenue  = pLab.map((l) => l.revenueScore).fold(0, (a, b) => a + b) ~/ pLab.length;
      final avgComp     = pLab.map((l) => l.competitionScore).fold(0, (a, b) => a + b) ~/ pLab.length;
      growthPotential   = ((avgMarket + avgRevenue) ~/ 2).clamp(0, 100);
      marketSize        = avgRevenue.clamp(0, 100);
      globalPotential   = (avgMarket * 0.7).round().clamp(0, 100);
      localPotential    = (avgMarket * 0.9).round().clamp(0, 100);
      competitionLevel  = _competitionFromScore(avgComp);
      marketMaturity    = _maturityFromGrowth(growthPotential);
      profileSource     = 'opportunities';
      confidence        = 60;
    } else {
      // Minimum viable — inferred from project name/type only
      market         = _inferMarket(project.name);
      niche          = project.name;
      subNiche       = project.type;
      targetAudience = '';
      businessModel  = _inferBizModel(project);
      growthPotential = 40;
      marketSize      = 40;
      globalPotential = 30;
      localPotential  = 50;
      competitionLevel = CompetitionLevel.moderada;
      marketMaturity   = MarketMaturity.crescendo;
      profileSource    = 'inferred';
      confidence       = 25;
    }

    // Market Score = composite 0–100
    final compAdv     = competitionLevel == CompetitionLevel.baixa ? 80
                      : competitionLevel == CompetitionLevel.moderada ? 55 : 30;
    final scalability = ((globalPotential + localPotential) ~/ 2).clamp(0, 100);
    final marketScore = (growthPotential * 0.30 + marketSize * 0.20 +
                         compAdv * 0.20 + scalability * 0.15 +
                         globalPotential * 0.15).round().clamp(0, 100);

    final explanation = <String>[
      'Crescimento: $growthPotential pts × 0.30 = ${(growthPotential * 0.30).round()} pts',
      'Tamanho de mercado: $marketSize pts × 0.20 = ${(marketSize * 0.20).round()} pts',
      'Vantagem competitiva ($compAdv pts) × 0.20 = ${(compAdv * 0.20).round()} pts',
      'Escalabilidade: $scalability pts × 0.15 = ${(scalability * 0.15).round()} pts',
      'Alcance global: $globalPotential pts × 0.15 = ${(globalPotential * 0.15).round()} pts',
      'Fonte: $profileSource (confiança $confidence%)',
    ];

    return MarketProfile(
      projectId:       project.id,
      projectName:     project.name,
      market:          market,
      niche:           niche,
      subNiche:        subNiche,
      targetAudience:  targetAudience,
      businessModel:   businessModel,
      competitionLevel: competitionLevel,
      marketSize:       marketSize,
      growthPotential:  growthPotential,
      globalPotential:  globalPotential,
      localPotential:   localPotential,
      marketMaturity:   marketMaturity,
      marketScore:      marketScore,
      confidence:       confidence,
      profileSource:    profileSource,
      scoreExplanation: explanation,
      computedAt:       DateTime.now(),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _inferMarket(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('social') || lower.contains('copilot') || lower.contains('ia') || lower.contains('ai'))
      return 'IA & Automação de Marketing';
    if (lower.contains('rcbo') || lower.contains('elétri') || lower.contains('eletri'))
      return 'Material Elétrico & Infraestrutura';
    if (lower.contains('insight') || lower.contains('inteligência') || lower.contains('dados'))
      return 'Inteligência de Mercado & Dados';
    if (lower.contains('offline') || lower.contains('saas') || lower.contains('software'))
      return 'Software SaaS';
    if (lower.contains('trago'))
      return 'Software SaaS Mobile';
    return 'Tecnologia & Negócios Digitais';
  }

  static String _inferBizModel(Project project) {
    final type = project.type.toLowerCase();
    if (type.contains('saas')) return 'SaaS';
    if (type.contains('ecom')) return 'E-commerce';
    if (type.contains('serv')) return 'Serviço';
    if (type.contains('consul')) return 'Consultoria';
    return 'Produto Digital';
  }

  static int _inferMarketSize(MarketAnalysis a) {
    final score = ((a.scoreMonetization + a.scoreGrowth) ~/ 2).clamp(0, 100);
    return score;
  }

  static int _inferGlobalPotential(MarketAnalysis a) {
    return (a.scoreGrowth * 0.7 + a.scoreMonetization * 0.3).round().clamp(0, 100);
  }

  static int _inferLocalPotential(MarketAnalysis a) {
    return (a.scoreGrowth * 0.5 + a.scoreSeo * 0.5).round().clamp(0, 100);
  }

  static CompetitionLevel _competitionFromScore(int score) {
    if (score >= 70) return CompetitionLevel.alta;
    if (score >= 40) return CompetitionLevel.moderada;
    return CompetitionLevel.baixa;
  }

  static MarketMaturity _maturityFromGrowth(int growth) {
    if (growth >= 70) return MarketMaturity.emergente;
    if (growth >= 45) return MarketMaturity.crescendo;
    if (growth >= 25) return MarketMaturity.maduro;
    return MarketMaturity.saturado;
  }
}
