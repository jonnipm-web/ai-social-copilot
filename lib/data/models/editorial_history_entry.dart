class EditorialHistoryEntry {
  final String id;
  final String userId;
  final String? brandId;
  final String? personaId;
  final String featureUsed;
  final String platform;
  final String objective;
  final String contentType;
  final String inputText;
  final String outputText;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EditorialHistoryEntry({
    required this.id,
    required this.userId,
    this.brandId,
    this.personaId,
    required this.featureUsed,
    required this.platform,
    required this.objective,
    required this.contentType,
    required this.inputText,
    required this.outputText,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EditorialHistoryEntry.fromMap(Map<String, dynamic> m) =>
      EditorialHistoryEntry(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        brandId: m['brand_id'] as String?,
        personaId: m['persona_id'] as String?,
        featureUsed: m['feature_used'] as String,
        platform: m['platform'] as String? ?? '',
        objective: m['objective'] as String? ?? '',
        contentType: m['content_type'] as String? ?? '',
        inputText: m['input_text'] as String,
        outputText: m['output_text'] as String,
        status: m['status'] as String? ?? 'generated',
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  String get statusLabel => switch (status) {
        'generated' => 'Gerado',
        'approved' => 'Aprovado',
        'needs_edit' => 'Precisa editar',
        'rejected' => 'Rejeitado',
        'published' => 'Publicado',
        _ => status,
      };
}
