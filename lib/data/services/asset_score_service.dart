import '../models/asset.dart';
import '../models/asset_score.dart';

// ── AssetScoreService ─────────────────────────────────────────────────────────
// Computa scores por asset de forma puramente in-memory.
// Sem dependência de Supabase — recebe dados já carregados pelos providers.
//
// Fórmula: Asset = Pot×30% + Mat×20% + Str×25% + ROI×15% + Vel×10%
//
// Thresholds de recomendação:
//   >= 75  → ESCALAR
//   >= 60  → ACELERAR
//   >= 45  → MANTER
//   >= 30  → VALIDAR
//   <  30  → PAUSAR

class AssetScoreService {
  // ── Public API ─────────────────────────────────────────────────────────────

  /// Computa score de um único asset.
  /// [metadata] é o conteúdo de Asset.metadata — pode conter sinais externos.
  AssetScore compute(Asset asset) {
    final meta = asset.metadata;

    final potential  = _potentialScore(asset, meta);
    final maturity   = _maturityScore(asset);
    final strategic  = _strategicScore(asset, meta);
    final roi        = _roiScore(meta);
    final velocity   = _velocityScore(asset, meta);

    final assetScore = _weighted(potential, maturity, strategic, roi, velocity);

    final missing   = _missingData(asset, meta);
    final enough    = missing.length <= 2;
    final confidence = _confidence(asset, meta, missing);
    final rec        = _recommend(assetScore, enough);

    return AssetScore(
      asset:          asset,
      potentialScore: potential,
      maturityScore:  maturity,
      strategicScore: strategic,
      roiScore:       roi,
      velocityScore:  velocity,
      assetScore:     assetScore,
      recommendation: rec,
      confidence:     confidence,
      hasEnoughData:  enough,
      strengths:      _strengths(asset, potential, strategic, roi),
      risks:          _risks(asset, maturity, velocity, enough),
      missingData:    missing,
    );
  }

  /// Computa scores para uma lista de assets e ordena por assetScore desc.
  List<AssetScore> computeAll(List<Asset> assets) {
    final scores = assets.map(compute).toList()
      ..sort((a, b) => b.assetScore.compareTo(a.assetScore));
    return scores;
  }

  /// Tenta recuperar score do cache em Asset.metadata['score_cache'].
  /// Retorna null se não houver cache ou estiver malformado.
  AssetScore? fromCache(Asset asset) {
    final cache = asset.metadata['score_cache'];
    if (cache is! Map) return null;
    return AssetScore.fromCache(asset, Map<String, dynamic>.from(cache));
  }

  // ── Score: Potencial (30%) ──────────────────────────────────────────────────
  // Baseado em: niche, targetMarket, targetAudience, metadata['market_size']

  int _potentialScore(Asset asset, Map<String, dynamic> meta) {
    var pts = 0;

    // Dados de segmentação disponíveis
    if (asset.niche?.isNotEmpty == true)           pts += 20;
    if (asset.targetMarket?.isNotEmpty == true)    pts += 15;
    if (asset.targetAudience?.isNotEmpty == true)  pts += 15;

    // Sinais externos via metadata
    final marketSize = (meta['market_size'] as num?)?.toDouble() ?? 0;
    if (marketSize > 0) {
      if (marketSize >= 1_000_000) pts += 30;
      else if (marketSize >= 100_000) pts += 20;
      else if (marketSize >= 10_000)  pts += 10;
      else                            pts +=  5;
    }

    // Modelo de receita definido indica mercado validado
    if (asset.revenueModel?.isNotEmpty == true) pts += 10;
    if (asset.businessModel?.isNotEmpty == true) pts += 10;

    return pts.clamp(0, 100);
  }

  // ── Score: Maturidade (20%) ──────────────────────────────────────────────────
  // Baseado em: status, lifecycleStage, metadata['age_days']

  int _maturityScore(Asset asset) {
    var pts = 0;

    // Status: progresso no ciclo de vida
    pts += switch (asset.status) {
      AssetStatus.idea        => 5,
      AssetStatus.research    => 15,
      AssetStatus.validation  => 30,
      AssetStatus.planned     => 40,
      AssetStatus.active      => 70,
      AssetStatus.completed   => 90,
      AssetStatus.paused      => 35,
      AssetStatus.archived    => 20,
    };

    // lifecycleStage como sinal adicional
    final stage = asset.lifecycleStage?.toLowerCase() ?? '';
    if (stage == 'growth')       pts += 20;
    if (stage == 'maturity')     pts += 15;
    if (stage == 'launch')       pts += 10;
    if (stage == 'introduction') pts +=  5;

    return pts.clamp(0, 100);
  }

  // ── Score: Fit Estratégico (25%) ─────────────────────────────────────────────
  // Baseado em: category, strategicPriority, metadata['strategic_tags']

  int _strategicScore(Asset asset, Map<String, dynamic> meta) {
    var pts = 0;

    // Prioridade estratégica explícita
    final priority = asset.strategicPriority ?? 0;
    if (priority >= 8)      pts += 40;
    else if (priority >= 5) pts += 25;
    else if (priority >= 3) pts += 15;
    else if (priority >= 1) pts +=  5;

    // Categoria e nicho preenchidos
    if (asset.category?.isNotEmpty == true) pts += 20;
    if (asset.niche?.isNotEmpty    == true) pts += 15;

    // Tags estratégicas via metadata
    final tags = meta['strategic_tags'];
    if (tags is List && tags.isNotEmpty) pts += 15;

    // Descrição preenchida (ativo documentado)
    if (asset.description?.isNotEmpty == true) pts += 10;

    return pts.clamp(0, 100);
  }

  // ── Score: ROI (15%) ─────────────────────────────────────────────────────────
  // Baseado em: metadata['roi_actual'], metadata['roi_projected']

  int _roiScore(Map<String, dynamic> meta) {
    var pts = 0;

    final roiActual    = (meta['roi_actual']    as num?)?.toDouble() ?? -1;
    final roiProjected = (meta['roi_projected'] as num?)?.toDouble() ?? -1;

    if (roiActual >= 0) {
      // ROI realizado — peso maior
      if (roiActual >= 300)       pts += 80;
      else if (roiActual >= 100)  pts += 60;
      else if (roiActual >= 50)   pts += 40;
      else if (roiActual >= 0)    pts += 20;
    } else if (roiProjected >= 0) {
      // ROI projetado — peso menor
      if (roiProjected >= 300)    pts += 50;
      else if (roiProjected >= 100) pts += 35;
      else if (roiProjected >= 50)  pts += 20;
      else                          pts += 10;
    }

    return pts.clamp(0, 100);
  }

  // ── Score: Velocidade (10%) ──────────────────────────────────────────────────
  // Baseado em: metadata['action_count'], metadata['completed_actions'],
  //             metadata['last_activity_days']

  int _velocityScore(Asset asset, Map<String, dynamic> meta) {
    var pts = 0;

    final actions   = (meta['action_count']     as num?)?.toInt()    ?? 0;
    final completed = (meta['completed_actions'] as num?)?.toInt()    ?? 0;
    final daysSince = (meta['last_activity_days'] as num?)?.toInt()   ?? 999;

    // Taxa de conclusão de ações
    if (actions > 0) {
      final rate = completed / actions;
      if (rate >= 0.8)      pts += 40;
      else if (rate >= 0.5) pts += 25;
      else if (rate >= 0.2) pts += 10;
    }

    // Recência de atividade
    if (daysSince <= 7)       pts += 40;
    else if (daysSince <= 14) pts += 30;
    else if (daysSince <= 30) pts += 15;
    else if (daysSince <= 60) pts +=  5;

    // Status active/paused como sinal de velocidade
    if (asset.status == AssetStatus.active)  pts += 20;
    if (asset.status == AssetStatus.paused)  pts -=  5;

    return pts.clamp(0, 100);
  }

  // ── Consolidação ─────────────────────────────────────────────────────────────

  int _weighted(int pot, int mat, int str, int roi, int vel) {
    return (pot * 0.30 + mat * 0.20 + str * 0.25 + roi * 0.15 + vel * 0.10)
        .round()
        .clamp(0, 100);
  }

  String _recommend(int score, bool enough) {
    if (!enough) return 'ANÁLISE INCOMPLETA';
    if (score >= 75) return 'ESCALAR';
    if (score >= 60) return 'ACELERAR';
    if (score >= 45) return 'MANTER';
    if (score >= 30) return 'VALIDAR';
    return 'PAUSAR';
  }

  int _confidence(
    Asset asset,
    Map<String, dynamic> meta,
    List<String> missing,
  ) {
    // 5 sinais — cada um vale 20 pontos de confiança
    var pts = 0;
    if (asset.niche?.isNotEmpty       == true) pts += 20;
    if (asset.description?.isNotEmpty == true) pts += 20;
    if (meta['roi_actual']    != null)         pts += 20;
    if (meta['action_count']  != null)         pts += 20;
    if (asset.targetMarket?.isNotEmpty == true) pts += 20;
    return pts.clamp(0, 100);
  }

  List<String> _missingData(Asset asset, Map<String, dynamic> meta) {
    final missing = <String>[];
    if (asset.niche?.isEmpty         != false) missing.add('niche');
    if (asset.targetMarket?.isEmpty  != false) missing.add('targetMarket');
    if (asset.description?.isEmpty   != false) missing.add('description');
    if (meta['roi_actual']   == null)          missing.add('roi_actual');
    if (meta['action_count'] == null)          missing.add('action_count');
    return missing;
  }

  List<String> _strengths(
    Asset asset, int potential, int strategic, int roi,
  ) {
    final s = <String>[];
    if (potential >= 60) s.add('Alto potencial de mercado identificado');
    if (strategic >= 60) s.add('Alta prioridade estratégica no projeto');
    if (roi >= 50)       s.add('ROI positivo confirmado ou projetado');
    if (asset.status == AssetStatus.active) s.add('Ativo em execução ativa');
    if (asset.niche?.isNotEmpty == true)    s.add('Nicho definido e segmentado');
    return s;
  }

  List<String> _risks(
    Asset asset, int maturity, int velocity, bool enough,
  ) {
    final r = <String>[];
    if (!enough)                                r.add('Dados insuficientes para análise confiável');
    if (maturity < 30)                          r.add('Ativo em estágio inicial — risco de validação');
    if (velocity < 20)                          r.add('Baixo momentum — risco de abandono');
    if (asset.status == AssetStatus.paused)     r.add('Ativo pausado — revisar motivo da interrupção');
    if (asset.revenueModel == null)             r.add('Modelo de receita não definido');
    return r;
  }
}
