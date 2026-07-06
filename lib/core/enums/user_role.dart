enum UserRole {
  admin('ADMIN', 'Admin'),
  receptionist('RECEPTIONIST', 'Receptionist'),
  teacherManager('TEACHER_MANAGER', 'Teacher / Manager'),
  member('MEMBER', 'Member');

  const UserRole(this.value, this.label);

  final String value;
  final String label;

  static UserRole fromValue(String value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.member,
    );
  }
}
