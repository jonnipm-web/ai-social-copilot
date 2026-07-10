class FeatureFlag {
  final String featureName;
  final bool enabled;
  final String planRequired;
  final DateTime createdAt;

  const FeatureFlag({
    required this.featureName,
    this.enabled = false,
    this.planRequired = 'free',
    required this.createdAt,
  });

  factory FeatureFlag.fromMap(Map<String, dynamic> map) => FeatureFlag(
        featureName:  map['feature_name'] as String,
        enabled:      map['enabled'] as bool? ?? false,
        planRequired: map['plan_required'] as String? ?? 'free',
        createdAt:    DateTime.parse(map['created_at'] as String),
      );

  static const advisorEnabled        = 'advisor_enabled';
  static const businessMemoryEnabled = 'business_memory_enabled';
  static const ecosystemViewEnabled  = 'ecosystem_view_enabled';
  static const opportunityLabEnabled = 'opportunity_lab_enabled';
  static const actionEngineEnabled   = 'action_engine_enabled';
  static const copilotEnabled        = 'copilot_enabled';
}
