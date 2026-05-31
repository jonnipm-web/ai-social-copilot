class ContentItem {
  final String id;
  final String userId;
  final String? brandId;
  final String title;
  final String baseText;
  final String notes;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ContentItem({
    required this.id,
    required this.userId,
    this.brandId,
    required this.title,
    required this.baseText,
    required this.notes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ContentItem.fromMap(Map<String, dynamic> m) => ContentItem(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        brandId: m['brand_id'] as String?,
        title: m['title'] as String,
        baseText: m['base_text'] as String,
        notes: m['notes'] as String? ?? '',
        status: m['status'] as String? ?? 'draft',
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'brand_id': brandId,
        'title': title,
        'base_text': baseText,
        'notes': notes,
        'status': status,
      };

  String get statusLabel => switch (status) {
        'draft' => 'Rascunho',
        'in_use' => 'Em uso',
        'used' => 'Utilizado',
        'archived' => 'Arquivado',
        _ => status,
      };
}
