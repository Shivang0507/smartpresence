import '../../../core/enums/organization_type.dart';

class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.type,
    required this.phone,
    required this.address,
    required this.createdBy,
  });

  final String id;
  final String name;
  final OrganizationType type;
  final String phone;
  final String address;
  final String createdBy;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type.label,
      'phone': phone,
      'address': address,
      'createdBy': createdBy,
      'isActive': true,
      'plan': 'starter',
    };
  }
}
