import 'asset.dart';

// ── AssetScoreComponent ───────────────────────────────────────────────────────
// Componente individual de score — espelha ScoreComponent de projeto.

class AssetScoreComponent {
  final String name;
  final int    rawValue;
  final int    maxValue;
  final double weight;
  final String explanation;
  final bool   hasData;

  const AssetScoreComponent({
    required this.name,
    required this.rawValue,
    required this.maxValue,
    required this.weight,
    required this.explanation,
    this.hasData = true,
  });

  int    get weightedContribution => (rawValue * weight).round();
  String get displayWeight        => '${(weight * 100).round()}%';
  double get completeness         => maxValue == 0 ? 0 : rawValue / maxValue;
}

// ── AssetScore ────────────────────────────────────────────────────────────────
// Score consolidado de um asset. Computado in-memory pelo AssetScoreService.
// Armazenado opcionalmente em Asset.metadata['score_cache'] para leitura rápida.

class AssetScore {
  final Asset  asset;

  // Componentes individuais
  final int    potentialScore;    // potencial de mercado / crescimento
  final int    maturityScore;     // maturidade do ativo (lifecycle)
  final int    strategicScore;    // fit estratégico com o projeto
  final int    roiScore;          // retorno sobre investimento estimado
  final int    velocityScore;     // velocidade de execução / momentum

  // Score consolidado (0–100)
  // Fórmula: Pot×30% + Mat×20% + Str×25% + ROI×15% + Vel×10%
  final int    assetScore;

  // Metadados de qualidade
  final String recommendation;    // ESCALAR | ACELERAR | MANTER | VALIDAR | PAUSAR
  final int    confidence;        // 0–100: confiança baseada em dados disponíveis
  final bool   hasEnoughData;
  final List<String> strengths;
  final List<String> risks;
  final List<String> missingData;

  const AssetScore({
    required this.asset,
    required this.potentialScore,
    required this.maturityScore,
    required this.strategicScore,
    required this.roiScore,
    required this.velocityScore,
    required this.assetScore,
    required this.recommendation,
    required this.confidence,
    required this.hasEnoughData,
    required this.strengths,
    required this.risks,
    required this.missingData,
  });

  String get recommendationEmoji => switch (recommendation) {
    'ESCALAR'             => '⚡',
    'ACELERAR'            => '🚀',
    'MANTER'              => '✅',
    'VALIDAR'             => '🔍',
    'ANÁLISE INCOMPLETA'  => '📊',
    _                     => '⏸️',
  };

  // Componentes como objetos tipados (para UI de breakdown)
  List<AssetScoreComponent> get components => [
    AssetScoreComponent(
      name:        'Potencial',
      rawValue:    potentialScore,
      maxValue:    100,
      weight:      0.30,
      explanation: 'Potencial de mercado e crescimento do ativo',
    ),
    AssetScoreComponent(
      name:        'Maturidade',
      rawValue:    maturityScore,
      maxValue:    100,
      weight:      0.20,
      explanation: 'Maturidade do ativo no ciclo de vida',
    ),
    AssetScoreComponent(
      name:        'Fit Estratégico',
      rawValue:    strategicScore,
      maxValue:    100,
      weight:      0.25,
      explanation: 'Alinhamento estratégico com o projeto',
    ),
    AssetScoreComponent(
      name:        'ROI',
      rawValue:    roiScore,
      maxValue:    100,
      weight:      0.15,
      explanation: 'Retorno sobre investimento estimado',
    ),
    AssetScoreComponent(
      name:        'Velocidade',
      rawValue:    velocityScore,
      maxValue:    100,
      weight:      0.10,
      explanation: 'Momentum e velocidade de execução',
    ),
  ];

  String get weightedFormula =>
      'Asset = Pot×30% + Mat×20% + Str×25% + ROI×15% + Vel×10%\n'
      '= $potentialScore×0.30 + $maturityScore×0.20'
      ' + $strategicScore×0.25 + $roiScore×0.15'
      ' + $velocityScore×0.10\n'
      '= $assetScore';

  // Converte para JSONB — para cache em Asset.metadata['score_cache']
  Map<String, dynamic> toCacheMap() => {
    'potential_score':  potentialScore,
    'maturity_score':   maturityScore,
    'strategic_score':  strategicScore,
    'roi_score':        roiScore,
    'velocity_score':   velocityScore,
    'asset_score':      assetScore,
    'recommendation':   recommendation,
    'confidence':       confidence,
    'has_enough_data':  hasEnoughData,
    'strengths':        strengths,
    'risks':            risks,
    'missing_data':     missingData,
  };

  // Reconstrói de cache (sem Asset — usado por AssetScoreService.fromCache)
  static AssetScore? fromCache(Asset asset, Map<String, dynamic>? cache) {
    if (cache == null) return null;
    return AssetScore(
      asset:          asset,
      potentialScore:  (cache['potential_score']  as num?)?.toInt() ?? 0,
      maturityScore:   (cache['maturity_score']   as num?)?.toInt() ?? 0,
      strategicScore:  (cache['strategic_score']  as num?)?.toInt() ?? 0,
      roiScore:        (cache['roi_score']         as num?)?.toInt() ?? 0,
      velocityScore:   (cache['velocity_score']   as num?)?.toInt() ?? 0,
      assetScore:      (cache['asset_score']       as num?)?.toInt() ?? 0,
      recommendation:  (cache['recommendation']   as String?) ?? 'VALIDAR',
      confidence:      (cache['confidence']        as num?)?.toInt() ?? 0,
      hasEnoughData:   (cache['has_enough_data']  as bool?) ?? false,
      strengths:       List<String>.from(cache['strengths']    as List? ?? []),
      risks:           List<String>.from(cache['risks']        as List? ?? []),
      missingData:     List<String>.from(cache['missing_data'] as List? ?? []),
    );
  }
}
