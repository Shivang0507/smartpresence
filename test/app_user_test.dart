import 'package:flutter_test/flutter_test.dart';
import 'package:smartpresence/core/enums/user_role.dart';
import 'package:smartpresence/features/auth/data/app_user.dart';

void main() {
  test('AppUser maps Firestore data with member fallback role', () {
    final user = AppUser.fromMap('user-1', {
      'organizationId': 'org-1',
      'name': 'Asha Rao',
      'email': 'asha@example.com',
      'role': 'LEGACY_UNKNOWN',
      'phone': '5550101',
      'isActive': false,
    });

    expect(user.id, 'user-1');
    expect(user.organizationId, 'org-1');
    expect(user.role, UserRole.member);
    expect(user.isActive, isFalse);
  });
}
