enum UserRole { admin, tester, user }

extension UserRoleX on UserRole {
  static UserRole fromString(String? s) => switch (s) {
        'admin' => UserRole.admin,
        'tester' => UserRole.tester,
        _ => UserRole.user,
      };

  bool get isAdmin => this == UserRole.admin;
  bool get isTesterOrAbove => this == UserRole.tester || this == UserRole.admin;

  String get label => switch (this) {
        UserRole.admin => 'Admin',
        UserRole.tester => 'Tester',
        UserRole.user => 'Usuário',
      };
}

class UserPermission {
  final UserRole role;
  final Map<String, bool> flags;

  const UserPermission({required this.role, this.flags = const {}});

  static const UserPermission defaultUser = UserPermission(role: UserRole.user);

  bool hasFeature(String flag) {
    if (role == UserRole.admin) return true;
    return flags[flag] ?? false;
  }

  bool get canAccessEditorial => hasFeature('editorial_mode');
  bool get canAccessBrandStudio => hasFeature('brand_studio');
  bool get canAccessLibrary => hasFeature('content_library');
  bool get canAccessExtractor => hasFeature('excerpt_extractor');
  bool get canAccessRepurposing => hasFeature('chapter_repurposing');
  bool get canAccessCalendar => hasFeature('editorial_calendar');
  bool get canAccessAdvancedHistory => hasFeature('advanced_history');
}
