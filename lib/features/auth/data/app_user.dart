import '../../../core/enums/organization_type.dart';
import '../../../core/enums/user_kind.dart';
import '../../../core/enums/user_role.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.email,
    required this.role,
    this.organizationType = OrganizationType.corporate,
    this.organizationName,
    this.kind = UserKind.member,
    this.phone,
    this.employeeId,
    this.departmentId,
    this.teamId,
    this.shiftId,
    this.temporaryShiftId,
    this.temporaryShiftStart,
    this.temporaryShiftEnd,
    this.profileImageUrl,
    this.faceImageUrl,
    this.faceMetadata,
    this.isActive = true,
  });

  final String id;
  final String organizationId;
  final String name;
  final String email;
  final UserRole role;
  final OrganizationType organizationType;
  final String? organizationName;
  final UserKind kind;
  final String? phone;
  final String? employeeId;
  final String? departmentId;
  final String? teamId;
  final String? shiftId;
  final String? temporaryShiftId;
  final String? temporaryShiftStart;
  final String? temporaryShiftEnd;
  final String? profileImageUrl;
  final String? faceImageUrl;
  final Map<String, dynamic>? faceMetadata;
  final bool isActive;

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    final meta = _mapOrNull(map['faceMetadata'] ?? map['faceData']);
    return AppUser(
      id: id,
      organizationId: map['organizationId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: UserRole.fromValue(map['role'] as String? ?? UserRole.member.value),
      organizationType: OrganizationType.fromString(map['organizationType'] as String? ?? 'company'),
      organizationName: map['organizationName'] as String?,
      kind: UserKind.fromValue(map['kind'] as String? ?? UserKind.member.value),
      phone: map['phone'] as String?,
      employeeId: map['employeeId'] as String?,
      departmentId: map['departmentId'] as String?,
      teamId: map['teamId'] as String?,
      shiftId: map['shiftId'] as String?,
      temporaryShiftId: map['temporaryShiftId'] as String?,
      temporaryShiftStart: map['temporaryShiftStart'] as String?,
      temporaryShiftEnd: map['temporaryShiftEnd'] as String?,
      profileImageUrl: map['profileImageUrl'] as String? ?? map['profilePhotoUrl'] as String?,
      faceImageUrl: map['faceImageUrl'] as String? ?? meta?['faceImageUrl'] as String?,
      faceMetadata: meta,
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'name': name,
      'email': email,
      'role': role.value,
      'organizationType': organizationType.name,
      'organizationName': organizationName,
      'kind': kind.value,
      'phone': phone,
      'employeeId': employeeId,
      'departmentId': departmentId,
      'teamId': teamId,
      'shiftId': shiftId,
      'temporaryShiftId': temporaryShiftId,
      'temporaryShiftStart': temporaryShiftStart,
      'temporaryShiftEnd': temporaryShiftEnd,
      'profileImageUrl': profileImageUrl,
      'faceImageUrl': faceImageUrl,
      'faceMetadata': faceMetadata,
      'isActive': isActive,
    };
  }

  static Map<String, dynamic>? _mapOrNull(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }
}
