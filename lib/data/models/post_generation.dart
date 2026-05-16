class PostGeneration {
  final String id;
  final String userId;
  final String originalText;
  final String improvedText;
  final String professionalVersion;
  final String casualVersion;
  final String persuasiveVersion;
  final String commentReply;
  final double clarityScore;
  final double impactScore;
  final double engagementScore;
  final DateTime createdAt;

  const PostGeneration({
    required this.id,
    required this.userId,
    required this.originalText,
    required this.improvedText,
    required this.professionalVersion,
    required this.casualVersion,
    required this.persuasiveVersion,
    required this.commentReply,
    required this.clarityScore,
    required this.impactScore,
    required this.engagementScore,
    required this.createdAt,
  });

  factory PostGeneration.fromMap(Map<String, dynamic> map) {
    return PostGeneration(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      originalText: map['original_text'] as String,
      improvedText: map['improved_text'] as String,
      professionalVersion: map['professional_version'] as String,
      casualVersion: map['casual_version'] as String,
      persuasiveVersion: map['persuasive_version'] as String,
      commentReply: map['comment_reply'] as String,
      clarityScore: (map['clarity_score'] as num).toDouble(),
      impactScore: (map['impact_score'] as num).toDouble(),
      engagementScore: (map['engagement_score'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'user_id': userId,
      'original_text': originalText,
      'improved_text': improvedText,
      'professional_version': professionalVersion,
      'casual_version': casualVersion,
      'persuasive_version': persuasiveVersion,
      'comment_reply': commentReply,
      'clarity_score': clarityScore,
      'impact_score': impactScore,
      'engagement_score': engagementScore,
    };
  }

  // Constrói a partir da resposta da Edge Function + texto original
  factory PostGeneration.fromApiResponse({
    required String userId,
    required String originalText,
    required Map<String, dynamic> response,
  }) {
    final scores = response['scores'] as Map<String, dynamic>;
    return PostGeneration(
      id: '',
      userId: userId,
      originalText: originalText,
      improvedText: response['improved_text'] as String,
      professionalVersion: response['professional_version'] as String,
      casualVersion: response['casual_version'] as String,
      persuasiveVersion: response['persuasive_version'] as String,
      commentReply: response['comment_reply'] as String,
      clarityScore: (scores['clarity'] as num).toDouble(),
      impactScore: (scores['impact'] as num).toDouble(),
      engagementScore: (scores['engagement'] as num).toDouble(),
      createdAt: DateTime.now(),
    );
  }
}
