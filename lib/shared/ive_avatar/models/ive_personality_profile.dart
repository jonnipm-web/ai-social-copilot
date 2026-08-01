// ── IvePersonalityProfile — behavioral persona within IVE identity ────────────
//
// Personalities are communication styles of the same IVE entity.
// They do NOT create different avatars — IVE's visual identity is singular.

enum IveCommunicationStyle {
  concise,
  analytical,
  coaching,
  narrative,
  technical
}

class IvePersonalityProfile {
  final String id;
  final String displayName;
  final String role;
  final IveCommunicationStyle communicationStyle;
  final List<String> expertise;
  final double animationBias; // 0.0 subtle … 1.0 expressive
  final double expressionBias; // 0.0 neutral … 1.0 reactive
  final bool enabled;
  final bool defaultProfile;

  const IvePersonalityProfile({
    required this.id,
    required this.displayName,
    required this.role,
    required this.communicationStyle,
    required this.expertise,
    this.animationBias = 0.5,
    this.expressionBias = 0.5,
    this.enabled = true,
    this.defaultProfile = false,
  });

  // ── Built-in profiles ─────────────────────────────────────────────────────

  static const executive = IvePersonalityProfile(
    id: 'executive',
    displayName: 'IVE',
    role: 'Insight Value Engine',
    communicationStyle: IveCommunicationStyle.analytical,
    expertise: ['strategy', 'execution', 'analytics'],
    animationBias: 0.4,
    expressionBias: 0.5,
    enabled: true,
    defaultProfile: true,
  );

  static const aurora = IvePersonalityProfile(
    id: 'aurora',
    displayName: 'IVE Aurora',
    role: 'Consultora Criativa',
    communicationStyle: IveCommunicationStyle.narrative,
    expertise: ['content', 'branding', 'creativity'],
    animationBias: 0.7,
    expressionBias: 0.8,
  );

  static const professor = IvePersonalityProfile(
    id: 'professor',
    displayName: 'IVE Professora',
    role: 'Mentora Didática',
    communicationStyle: IveCommunicationStyle.coaching,
    expertise: ['education', 'onboarding', 'explanation'],
    animationBias: 0.5,
    expressionBias: 0.6,
  );

  static const monetization = IvePersonalityProfile(
    id: 'monetization',
    displayName: 'IVE Monetização',
    role: 'Especialista em Receita',
    communicationStyle: IveCommunicationStyle.concise,
    expertise: ['revenue', 'pricing', 'roi'],
    animationBias: 0.3,
    expressionBias: 0.4,
  );

  static const strategy = IvePersonalityProfile(
    id: 'strategy',
    displayName: 'IVE Estratégia',
    role: 'Consultora Estratégica',
    communicationStyle: IveCommunicationStyle.analytical,
    expertise: ['strategy', 'market', 'competition'],
    animationBias: 0.4,
    expressionBias: 0.45,
  );

  static const research = IvePersonalityProfile(
    id: 'research',
    displayName: 'IVE Pesquisa',
    role: 'Analista de Mercado',
    communicationStyle: IveCommunicationStyle.technical,
    expertise: ['research', 'data', 'intelligence'],
    animationBias: 0.3,
    expressionBias: 0.35,
  );

  static const allProfiles = [
    executive,
    aurora,
    professor,
    monetization,
    strategy,
    research,
  ];
}
