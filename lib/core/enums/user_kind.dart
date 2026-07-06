enum UserKind {
  student('STUDENT', 'Student'),
  employee('EMPLOYEE', 'Employee'),
  worker('WORKER', 'Worker'),
  trainee('TRAINEE', 'Trainee'),
  member('MEMBER', 'Member');

  const UserKind(this.value, this.label);

  final String value;
  final String label;

  static UserKind fromValue(String value) {
    return UserKind.values.firstWhere(
      (kind) => kind.value == value,
      orElse: () => UserKind.member,
    );
  }
}
