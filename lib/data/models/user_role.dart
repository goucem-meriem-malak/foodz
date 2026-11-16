/// Roles. The authoritative copy lives in Firestore (users/{uid}.role) and is
/// enforced by firestore.rules. The app only uses this to choose screens.
enum UserRole {
  client,
  admin,
  owner,
  chef,
  delivery;

  /// Unknown or missing values fall back to the least privileged role.
  static UserRole parse(Object? value) {
    for (final role in UserRole.values) {
      if (role.name == value) return role;
    }
    return UserRole.client;
  }

  bool get isStaff => this != UserRole.client;
  bool get canManageMenu => this == UserRole.owner || this == UserRole.admin;
  bool get canManageStaff => this == UserRole.owner;
}
