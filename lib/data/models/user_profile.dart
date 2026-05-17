class UserProfile {
  const UserProfile({
    required this.userId,
    required this.niche,
    this.isPro = false,
  });

  final String userId;
  final String niche;
  final bool isPro;

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        userId: map['user_id'] as String,
        niche: map['niche'] as String,
        isPro: map['is_pro'] as bool? ?? false,
      );

  // is_pro é gerenciado pelo backend (webhook RevenueCat), nunca pelo cliente
  Map<String, dynamic> toUpsertMap() => {
        'user_id': userId,
        'niche': niche,
        'updated_at': DateTime.now().toIso8601String(),
      };

  UserProfile copyWith({String? niche, bool? isPro}) => UserProfile(
        userId: userId,
        niche: niche ?? this.niche,
        isPro: isPro ?? this.isPro,
      );
}
