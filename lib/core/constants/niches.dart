class NicheDefinition {
  const NicheDefinition({
    required this.id,
    required this.label,
    required this.emoji,
    required this.systemPromptHint,
    required this.templates,
  });

  final String id;
  final String label;
  final String emoji;
  final String systemPromptHint;
  final List<String> templates;

  String get displayName => '$emoji  $label';
}

const niches = [
  NicheDefinition(
    id: 'geral',
    label: 'Geral',
    emoji: '🌐',
    systemPromptHint: 'Use tom neutro e versátil, adequado para qualquer público.',
    templates: [
      'Conquista do dia',
      'Dica que mudou minha vida',
      'Reflexão da semana',
      'O que aprendi hoje',
    ],
  ),
  NicheDefinition(
    id: 'fitness',
    label: 'Fitness & Saúde',
    emoji: '💪',
    systemPromptHint:
        'Nicho: Fitness & Saúde. Use tom motivador e energético, linguagem ativa, valorize resultados e consistência. Inclua hashtags de saúde e treino.',
    templates: [
      'Treino de hoje',
      'Receita fit',
      'Dica de saúde',
      'Motivação fitness',
      'Antes e depois',
    ],
  ),
  NicheDefinition(
    id: 'gastronomia',
    label: 'Gastronomia',
    emoji: '🍽️',
    systemPromptHint:
        'Nicho: Gastronomia. Use tom apetitoso e sensorial, valorize ingredientes, sabores e experiências culinárias. Inclua hashtags de comida e receitas.',
    templates: [
      'Receita nova',
      'Restaurante favorito',
      'Prato do dia',
      'Dica culinária',
    ],
  ),
  NicheDefinition(
    id: 'tech',
    label: 'Tech & Inovação',
    emoji: '💻',
    systemPromptHint:
        'Nicho: Tecnologia e Inovação. Use tom informativo e inovador, linguagem técnica porém acessível. Inclua hashtags de tecnologia e inovação.',
    templates: [
      'Novidade tech',
      'Dica de produtividade',
      'Review de produto',
      'Tendência do setor',
    ],
  ),
  NicheDefinition(
    id: 'moda',
    label: 'Moda & Estilo',
    emoji: '👗',
    systemPromptHint:
        'Nicho: Moda e Estilo. Use tom aspiracional e estético, explore tendências, cores e combinações. Inclua hashtags de moda e lifestyle.',
    templates: [
      'Look do dia',
      'Tendência da estação',
      'Dica de estilo',
      'Haul de compras',
    ],
  ),
  NicheDefinition(
    id: 'empreendedorismo',
    label: 'Empreendedorismo',
    emoji: '🚀',
    systemPromptHint:
        'Nicho: Empreendedorismo. Use tom inspirador e estratégico, foque em resultados, aprendizados e bastidores. Inclua hashtags de negócios e empreendedorismo.',
    templates: [
      'Lição aprendida',
      'Bastidores do negócio',
      'Dica para empreendedores',
      'Case de sucesso',
    ],
  ),
  NicheDefinition(
    id: 'educacao',
    label: 'Educação',
    emoji: '📚',
    systemPromptHint:
        'Nicho: Educação. Use tom didático e acessível, compartilhe conhecimento de forma clara e envolvente. Inclua hashtags de aprendizado e educação.',
    templates: [
      'Dica de estudo',
      'Curiosidade do dia',
      'Conteúdo educativo',
      'Aprendi hoje',
    ],
  ),
  NicheDefinition(
    id: 'viagens',
    label: 'Viagens',
    emoji: '✈️',
    systemPromptHint:
        'Nicho: Viagens. Use tom aventureiro e descritivo, desperte o desejo de conhecer lugares. Inclua hashtags de viagem e turismo.',
    templates: [
      'Destino favorito',
      'Dica de viagem',
      'Experiência cultural',
      'Roteiro sugerido',
    ],
  ),
  NicheDefinition(
    id: 'arte',
    label: 'Arte & Design',
    emoji: '🎨',
    systemPromptHint:
        'Nicho: Arte e Design. Use tom criativo e expressivo, valorize o processo criativo e a estética. Inclua hashtags de arte e design.',
    templates: [
      'Processo criativo',
      'Inspiração do dia',
      'Obra em destaque',
      'Dica de design',
    ],
  ),
];

NicheDefinition nicheById(String id) =>
    niches.firstWhere((n) => n.id == id, orElse: () => niches.first);
