import 'user_role.dart';

enum OrganizationType {
  corporate('Corporate'),
  factory('Factory / Manufacturing'),
  school('School / College'),
  hospital('Hospital'),
  retail('Retail'),
  warehouse('Warehouse');

  const OrganizationType(this.label);

  final String label;

  static OrganizationType fromString(String value) {
    final lower = value.toLowerCase().trim();
    if (lower.contains('school') || lower.contains('college') || lower.contains('university') || lower.contains('training') || lower.contains('education')) {
      return OrganizationType.school;
    }
    if (lower.contains('factory') || lower.contains('industrial') || lower.contains('manufacturing') || lower.contains('plant')) {
      return OrganizationType.factory;
    }
    if (lower.contains('company') || lower.contains('startup') || lower.contains('office') || lower.contains('corporate')) {
      return OrganizationType.corporate;
    }
    if (lower.contains('hospital') || lower.contains('clinic') || lower.contains('medical')) {
      return OrganizationType.hospital;
    }
    if (lower.contains('retail') || lower.contains('store') || lower.contains('shop') || lower.contains('commercial')) {
      return OrganizationType.retail;
    }
    if (lower.contains('warehouse') || lower.contains('logistics') || lower.contains('distribution')) {
      return OrganizationType.warehouse;
    }

    return OrganizationType.values.firstWhere(
      (type) => type.name.toLowerCase() == lower || type.label.toLowerCase().replaceAll(' ', '').replaceAll('/', '').toLowerCase() == lower.replaceAll(' ', '').replaceAll('/', ''),
      orElse: () => OrganizationType.corporate,
    );
  }
}

enum OrganizationCategory {
  education,
  corporate,
  industrial,
  medical,
  commercial,
  logistics;
}

extension OrganizationTypeExtension on OrganizationType {
  OrganizationCategory get category {
    return switch (this) {
      OrganizationType.school => OrganizationCategory.education,
      OrganizationType.corporate => OrganizationCategory.corporate,
      OrganizationType.factory => OrganizationCategory.industrial,
      OrganizationType.hospital => OrganizationCategory.medical,
      OrganizationType.retail => OrganizationCategory.commercial,
      OrganizationType.warehouse => OrganizationCategory.logistics,
    };
  }
}

extension OrganizationCategoryLabels on OrganizationCategory {
  String get memberLabel => switch (this) {
    OrganizationCategory.education => 'Student',
    OrganizationCategory.corporate => 'Employee',
    OrganizationCategory.industrial => 'Worker',
    OrganizationCategory.medical => 'Nurse / Staff',
    OrganizationCategory.commercial => 'Associate / Cashier',
    OrganizationCategory.logistics => 'Loader / Operator',
  };

  String get memberPlural => switch (this) {
    OrganizationCategory.education => 'Students',
    OrganizationCategory.corporate => 'Employees',
    OrganizationCategory.industrial => 'Workers',
    OrganizationCategory.medical => 'Nurses & Staff',
    OrganizationCategory.commercial => 'Associates & Cashiers',
    OrganizationCategory.logistics => 'Loaders & Operators',
  };

  String get teacherManagerLabel => switch (this) {
    OrganizationCategory.education => 'Teacher',
    OrganizationCategory.corporate => 'Manager',
    OrganizationCategory.industrial => 'Supervisor',
    OrganizationCategory.medical => 'Doctor',
    OrganizationCategory.commercial => 'Store Manager',
    OrganizationCategory.logistics => 'Floor Supervisor',
  };

  String get teacherManagerPlural => switch (this) {
    OrganizationCategory.education => 'Teachers',
    OrganizationCategory.corporate => 'Managers',
    OrganizationCategory.industrial => 'Supervisors',
    OrganizationCategory.medical => 'Doctors',
    OrganizationCategory.commercial => 'Store Managers',
    OrganizationCategory.logistics => 'Floor Supervisors',
  };

  String get receptionistLabel => switch (this) {
    OrganizationCategory.education => 'Registrar',
    OrganizationCategory.corporate => 'HR Administrator',
    OrganizationCategory.industrial => 'Plant HR',
    OrganizationCategory.medical => 'Duty Officer',
    OrganizationCategory.commercial => 'Assistant Manager',
    OrganizationCategory.logistics => 'Dispatcher',
  };

  String get teamLabel => switch (this) {
    OrganizationCategory.education => 'Class',
    OrganizationCategory.corporate => 'Team',
    OrganizationCategory.industrial => 'Line / Section',
    OrganizationCategory.medical => 'Ward / Unit',
    OrganizationCategory.commercial => 'Shift / Team',
    OrganizationCategory.logistics => 'Crew / Shift',
  };

  String get teamPlural => switch (this) {
    OrganizationCategory.education => 'Classes',
    OrganizationCategory.corporate => 'Teams',
    OrganizationCategory.industrial => 'Lines & Sections',
    OrganizationCategory.medical => 'Wards & Units',
    OrganizationCategory.commercial => 'Shifts & Teams',
    OrganizationCategory.logistics => 'Crews & Shifts',
  };

  String roleLabel(UserRole role) => switch (role) {
    UserRole.admin => 'Admin',
    UserRole.receptionist => receptionistLabel,
    UserRole.teacherManager => teacherManagerLabel,
    UserRole.member => memberLabel,
  };
}
