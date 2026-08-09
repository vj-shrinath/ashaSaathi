enum UserRole {
  asha('asha', 'ASHA Worker', '/dashboard/asha'),
  doctor('doctor', 'Doctor', '/dashboard/doctor'),
  tho('tho', 'THO', '/dashboard/tho'),
  admin('admin', 'Admin', '/admin');

  const UserRole(this.value, this.displayName, this.route);
  
  final String value;
  final String displayName;
  final String route;

  static UserRole fromString(String role) {
    return UserRole.values.firstWhere(
      (r) => r.value == role,
      orElse: () => UserRole.asha,
    );
  }
}