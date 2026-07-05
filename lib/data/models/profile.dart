class Profile {
  final String id;
  final String? email;
  final String? fullName;
  final String role;
  final int monthlyLimit;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Profile({
    required this.id,
    this.email,
    this.fullName,
    required this.role,
    required this.monthlyLimit,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAdmin      => role == 'admin';
  bool get isPro        => role == 'pro' || role == 'premium' || role == 'admin';
  bool get isPremium    => role == 'premium' || role == 'admin';
  bool get isBetaTester => role == 'beta_tester' || isAdmin;
  bool get canUseCalendar   => isPro;
  bool get canUseLibrary    => isPro;
  bool get canCreatePersonas => isPro;

  String get roleLabel {
    switch (role) {
      case 'admin':       return 'Admin';
      case 'premium':     return 'Premium';
      case 'pro':         return 'Pro';
      case 'beta_tester': return 'Beta';
      default:            return 'Free';
    }
  }

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id:           map['id'] as String,
      email:        map['email'] as String?,
      fullName:     map['full_name'] as String?,
      role:         map['role'] as String? ?? 'free',
      monthlyLimit: map['monthly_limit'] as int? ?? 5,
      isActive:     map['is_active'] as bool? ?? true,
      createdAt:    map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      updatedAt:    map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toUpdateMap() => {
    'full_name':     fullName,
    'role':          role,
    'monthly_limit': monthlyLimit,
    'is_active':     isActive,
  };

  Profile copyWith({
    String? role,
    String? fullName,
    int?    monthlyLimit,
    bool?   isActive,
  }) {
    return Profile(
      id:           id,
      email:        email,
      fullName:     fullName     ?? this.fullName,
      role:         role         ?? this.role,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      isActive:     isActive     ?? this.isActive,
      createdAt:    createdAt,
      updatedAt:    DateTime.now(),
    );
  }
}
