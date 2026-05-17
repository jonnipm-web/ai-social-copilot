class UserProfile {
  const UserProfile({required this.userId, required this.niche});

  final String userId;
  final String niche;

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        userId: map['user_id'] as String,
        niche: map['niche'] as String,
      );

  Map<String, dynamic> toUpsertMap() => {
        'user_id': userId,
        'niche': niche,
        'updated_at': DateTime.now().toIso8601String(),
      };

  UserProfile copyWith({String? niche}) =>
      UserProfile(userId: userId, niche: niche ?? this.niche);
}
