import '../models/executive_relationship.dart';
import '../models/market_analysis.dart';
import '../models/project.dart';

/// Detecta relações entre projetos usando sobreposição de nicho, público e tópicos.
/// Puro Dart — sem I/O.
class ExecutiveRelationshipService {
  List<ExecutiveRelationship> detect({
    required List<Project> projects,
    required List<MarketAnalysis> analyses,
  }) {
    final relationships = <ExecutiveRelationship>[];

    for (var i = 0; i < projects.length; i++) {
      for (var j = i + 1; j < projects.length; j++) {
        final pA = projects[i];
        final pB = projects[j];
        final aA = _analysis(pA, analyses);
        final aB = _analysis(pB, analyses);

        if (aA == null && aB == null) continue;

        final rel = _evaluate(pA, aA, pB, aB);
        if (rel != null) relationships.add(rel);
      }
    }

    // Ordena: duplicatas e conflitos primeiro
    relationships.sort((a, b) {
      final priorityA = _typePriority(a.type);
      final priorityB = _typePriority(b.type);
      return priorityA.compareTo(priorityB);
    });

    return relationships;
  }

  ExecutiveRelationship? _evaluate(
    Project pA, MarketAnalysis? aA,
    Project pB, MarketAnalysis? aB,
  ) {
    final nicheA    = (aA?.niche          ?? '').toLowerCase().trim();
    final nicheB    = (aB?.niche          ?? '').toLowerCase().trim();
    final audienceA = (aA?.targetAudience ?? '').toLowerCase().trim();
    final audienceB = (aB?.targetAudience ?? '').toLowerCase().trim();
    final modelA    = (aA?.monetizationModel ?? '').toLowerCase().trim();
    final modelB    = (aB?.monetizationModel ?? '').toLowerCase().trim();

    final nicheOverlap    = _overlap(nicheA, nicheB);
    final audienceOverlap = _overlap(audienceA, audienceB);
    final modelOverlap    = _overlap(modelA, modelB);
    final contextOverlap  = (nicheOverlap + audienceOverlap + modelOverlap) / 3;

    final sharedTopics = _sharedWords(nicheA + ' ' + audienceA, nicheB + ' ' + audienceB);

    if (contextOverlap >= 0.90) {
      return ExecutiveRelationship(
        projectAId:   pA.id,
        projectAName: pA.name,
        projectBId:   pB.id,
        projectBName: pB.name,
        type:         RelationshipType.duplicate,
        similarity:   contextOverlap,
        description:
            '"${pA.name}" e "${pB.name}" compartilham ${(contextOverlap * 100).round()}% do contexto. '
            'Possível duplicata detectada.',
        sharedTopics: sharedTopics,
        conflicts: [
          'Esforço duplicado de análise de mercado',
          'Divisão de foco e recursos',
        ],
        recommendation:
            'Considere consolidar os dois projetos em um único projeto com escopo expandido.',
      );
    }

    if (nicheOverlap >= 0.80 || contextOverlap >= 0.75) {
      return ExecutiveRelationship(
        projectAId:   pA.id,
        projectAName: pA.name,
        projectBId:   pB.id,
        projectBName: pB.name,
        type:         RelationshipType.conflicting,
        similarity:   nicheOverlap,
        description:
            '"${pA.name}" e "${pB.name}" atuam no mesmo nicho e competem pelos mesmos recursos.',
        sharedTopics: sharedTopics,
        conflicts: [
          'Concorrência interna por audiência',
          'Risco de canibalização de receita',
        ],
        recommendation:
            'Diferencie o posicionamento de cada projeto ou decida qual priorizar.',
      );
    }

    if (nicheOverlap >= 0.40) {
      final synergies = <String>[];
      if (modelOverlap < 0.3) synergies.add('Modelos de monetização complementares');
      if (audienceOverlap > 0.4) synergies.add('Audiência compartilhada pode ser cross-sold');
      synergies.add('Conhecimento de nicho pode ser reutilizado');

      return ExecutiveRelationship(
        projectAId:   pA.id,
        projectAName: pA.name,
        projectBId:   pB.id,
        projectBName: pB.name,
        type:         RelationshipType.synergistic,
        similarity:   nicheOverlap,
        description:
            '"${pA.name}" e "${pB.name}" operam em nichos relacionados com ${(nicheOverlap * 100).round()}% de sobreposição.',
        sharedTopics: sharedTopics,
        synergies:    synergies,
        recommendation:
            'Reutilize documentos e análises entre os projetos para economizar tempo.',
      );
    }

    if (audienceOverlap >= 0.50) {
      return ExecutiveRelationship(
        projectAId:   pA.id,
        projectAName: pA.name,
        projectBId:   pB.id,
        projectBName: pB.name,
        type:         RelationshipType.sharedAudience,
        similarity:   audienceOverlap,
        description:
            '"${pA.name}" e "${pB.name}" atendem ao mesmo público-alvo em nichos diferentes.',
        sharedTopics: sharedTopics,
        synergies: ['Cross-sell para mesma base de clientes', 'Persona unificada possível'],
        recommendation:
            'Crie uma persona unificada para ambos e explore cross-sell.',
      );
    }

    if (nicheOverlap >= 0.20 && audienceOverlap >= 0.20) {
      return ExecutiveRelationship(
        projectAId:   pA.id,
        projectAName: pA.name,
        projectBId:   pB.id,
        projectBName: pB.name,
        type:         RelationshipType.complementary,
        similarity:   (nicheOverlap + audienceOverlap) / 2,
        description:
            '"${pA.name}" e "${pB.name}" se complementam e podem gerar valor combinados.',
        sharedTopics: sharedTopics,
        synergies: ['Portfólio coeso para o mesmo cliente', 'Redução de CAC compartilhado'],
        recommendation:
            'Considere criar uma oferta bundle ou cross-sell entre os dois projetos.',
      );
    }

    return null;
  }

  double _overlap(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final wordsA = a.split(RegExp(r'\s+')).toSet();
    final wordsB = b.split(RegExp(r'\s+')).toSet();
    if (wordsA.isEmpty || wordsB.isEmpty) return 0;
    final intersection = wordsA.intersection(wordsB).length;
    final union = wordsA.union(wordsB).length;
    return union == 0 ? 0 : intersection / union;
  }

  List<String> _sharedWords(String textA, String textB) {
    final wordsA = textA.split(RegExp(r'\s+')).where((w) => w.length > 3).toSet();
    final wordsB = textB.split(RegExp(r'\s+')).where((w) => w.length > 3).toSet();
    return wordsA.intersection(wordsB).take(5).toList();
  }

  MarketAnalysis? _analysis(Project p, List<MarketAnalysis> all) {
    if (all.isEmpty) return null;
    if (p.marketAnalysisId != null) {
      final direct = all.where((a) => a.id == p.marketAnalysisId).toList();
      if (direct.isNotEmpty) return direct.first;
    }
    return null;
  }

  int _typePriority(RelationshipType t) {
    switch (t) {
      case RelationshipType.duplicate:      return 0;
      case RelationshipType.conflicting:    return 1;
      case RelationshipType.synergistic:    return 2;
      case RelationshipType.sharedNiche:    return 3;
      case RelationshipType.sharedAudience: return 4;
      case RelationshipType.complementary:  return 5;
    }
  }
}
