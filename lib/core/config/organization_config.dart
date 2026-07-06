import 'package:flutter/material.dart';
import '../enums/organization_type.dart';
import '../enums/user_role.dart';
import '../enums/directory_type.dart';
import 'dashboard_widget.dart';

abstract class OrganizationConfig {
  String get memberLabel;
  String get memberPlural;
  String get teacherManagerLabel;
  String get teacherManagerPlural;
  String get receptionistLabel;
  String get teamLabel;
  String get teamPlural;
  String get departmentLabel;
  String get departmentPlural;
  String get idLabel;

  Color get primaryColor;
  Color get secondaryColor;

  List<String> getEnabledModuleIds();
  List<DashboardWidget> getDashboardWidgets();
  List<String> getAvailableReports();
  List<String> getAvailableCharts();

  List<DirectoryType> getSupportedMasterDataTypes();
  List<DirectoryType> getUserAssignmentTypes();

  String roleLabel(UserRole role) => switch (role) {
    UserRole.admin => 'Admin',
    UserRole.receptionist => receptionistLabel,
    UserRole.teacherManager => teacherManagerLabel,
    UserRole.member => memberLabel,
  };
}

class CorporateConfig extends OrganizationConfig {
  @override
  String get memberLabel => 'Employee';
  @override
  String get memberPlural => 'Employees';
  @override
  String get teacherManagerLabel => 'Manager';
  @override
  String get teacherManagerPlural => 'Managers';
  @override
  String get receptionistLabel => 'HR Admin';
  @override
  String get teamLabel => 'Team';
  @override
  String get teamPlural => 'Teams';
  @override
  String get departmentLabel => 'Department';
  @override
  String get departmentPlural => 'Departments';
  @override
  String get idLabel => 'Employee ID';

  @override
  Color get primaryColor => const Color(0xFF2563EB); // Blue
  @override
  Color get secondaryColor => const Color(0xFF0D9488); // Teal

  @override
  List<String> getEnabledModuleIds() => ['attendance', 'employees', 'leave'];
  @override
  List<DashboardWidget> getDashboardWidgets() => [StatsGridWidget(), QuickActionsGridWidget()];
  @override
  List<String> getAvailableReports() => ['Employee Attendance', 'Leave Report', 'Department Report'];
  @override
  List<String> getAvailableCharts() => ['Leave Split', 'Departmental Attendance', 'Presence Split'];

  @override
  List<DirectoryType> getSupportedMasterDataTypes() => [
        DirectoryType.department,
        DirectoryType.team,
        DirectoryType.location,
        DirectoryType.designation,
      ];
  @override
  List<DirectoryType> getUserAssignmentTypes() => [
        DirectoryType.department,
        DirectoryType.team,
      ];
}

class FactoryConfig extends OrganizationConfig {
  @override
  String get memberLabel => 'Worker';
  @override
  String get memberPlural => 'Workers';
  @override
  String get teacherManagerLabel => 'Supervisor';
  @override
  String get teacherManagerPlural => 'Supervisors';
  @override
  String get receptionistLabel => 'Plant HR';
  @override
  String get teamLabel => 'Line / Section';
  @override
  String get teamPlural => 'Lines & Sections';
  @override
  String get departmentLabel => 'Department';
  @override
  String get departmentPlural => 'Departments';
  @override
  String get idLabel => 'Worker ID';

  @override
  Color get primaryColor => const Color(0xFFEA580C); // Dark Orange
  @override
  Color get secondaryColor => const Color(0xFFD97706); // Amber

  @override
  List<String> getEnabledModuleIds() => ['attendance', 'workers', 'shifts', 'leave'];
  @override
  List<DashboardWidget> getDashboardWidgets() => [StatsGridWidget(), QuickActionsGridWidget()];
  @override
  List<String> getAvailableReports() => ['Shift Report', 'Overtime Report', 'Worker Attendance'];
  @override
  List<String> getAvailableCharts() => ['Shift Analytics', 'Overtime Hours', 'Worker Attendance Trends'];

  @override
  List<DirectoryType> getSupportedMasterDataTypes() => [
        DirectoryType.department,
        DirectoryType.team,
        DirectoryType.productionLine,
        DirectoryType.shift,
        DirectoryType.designation,
      ];
  @override
  List<DirectoryType> getUserAssignmentTypes() => [
        DirectoryType.department,
        DirectoryType.team,
        DirectoryType.shift,
      ];
}

class SchoolConfig extends OrganizationConfig {
  @override
  String get memberLabel => 'Student';
  @override
  String get memberPlural => 'Students';
  @override
  String get teacherManagerLabel => 'Teacher';
  @override
  String get teacherManagerPlural => 'Teachers';
  @override
  String get receptionistLabel => 'Registrar';
  @override
  String get teamLabel => 'Class';
  @override
  String get teamPlural => 'Classes';
  @override
  String get departmentLabel => 'Subject';
  @override
  String get departmentPlural => 'Subjects';
  @override
  String get idLabel => 'Roll Number';

  @override
  Color get primaryColor => const Color(0xFF10B981); // Green
  @override
  Color get secondaryColor => const Color(0xFF3B82F6); // Blue

  @override
  List<String> getEnabledModuleIds() => ['attendance', 'students', 'timetable'];
  @override
  List<DashboardWidget> getDashboardWidgets() => [StatsGridWidget(), QuickActionsGridWidget()];
  @override
  List<String> getAvailableReports() => ['Student Attendance', 'Teacher Attendance', 'Class Attendance'];
  @override
  List<String> getAvailableCharts() => ['Student Attendance Trend', 'Teacher Attendance Summary', 'Class Performance'];

  @override
  List<DirectoryType> getSupportedMasterDataTypes() => [
        DirectoryType.clazz,
        DirectoryType.section,
        DirectoryType.subject,
        DirectoryType.department,
        DirectoryType.academicYear,
      ];
  @override
  List<DirectoryType> getUserAssignmentTypes() => [
        DirectoryType.clazz,
        DirectoryType.section,
        DirectoryType.subject,
      ];
}

class HospitalConfig extends OrganizationConfig {
  @override
  String get memberLabel => 'Nurse / Staff';
  @override
  String get memberPlural => 'Nurses & Staff';
  @override
  String get teacherManagerLabel => 'Doctor';
  @override
  String get teacherManagerPlural => 'Doctors';
  @override
  String get receptionistLabel => 'Duty Officer';
  @override
  String get teamLabel => 'Ward / Unit';
  @override
  String get teamPlural => 'Wards & Units';
  @override
  String get departmentLabel => 'Medical Department';
  @override
  String get departmentPlural => 'Medical Departments';
  @override
  String get idLabel => 'Staff ID';

  @override
  Color get primaryColor => const Color(0xFFE11D48); // Rose / Red
  @override
  Color get secondaryColor => const Color(0xFFBE123C); // Dark Rose

  @override
  List<String> getEnabledModuleIds() => ['attendance', 'staff', 'roster', 'shifts'];
  @override
  List<DashboardWidget> getDashboardWidgets() => [StatsGridWidget(), QuickActionsGridWidget()];
  @override
  List<String> getAvailableReports() => ['Duty Roster', 'Staff Attendance', 'Shift Report'];
  @override
  List<String> getAvailableCharts() => ['Duty Coverage', 'Staff Attendance Trends', 'Shift Performance'];

  @override
  List<DirectoryType> getSupportedMasterDataTypes() => [
        DirectoryType.ward,
        DirectoryType.department,
        DirectoryType.unit,
        DirectoryType.dutyType,
        DirectoryType.designation,
      ];
  @override
  List<DirectoryType> getUserAssignmentTypes() => [
        DirectoryType.department,
        DirectoryType.ward,
        DirectoryType.dutyType,
      ];
}

class RetailConfig extends OrganizationConfig {
  @override
  String get memberLabel => 'Associate / Cashier';
  @override
  String get memberPlural => 'Associates & Cashiers';
  @override
  String get teacherManagerLabel => 'Store Manager';
  @override
  String get teacherManagerPlural => 'Store Managers';
  @override
  String get receptionistLabel => 'Assistant Manager';
  @override
  String get teamLabel => 'Shift / Team';
  @override
  String get teamPlural => 'Shifts & Teams';
  @override
  String get departmentLabel => 'Store Branch';
  @override
  String get departmentPlural => 'Store Branches';
  @override
  String get idLabel => 'Associate ID';

  @override
  Color get primaryColor => const Color(0xFF7C3AED); // Violet
  @override
  Color get secondaryColor => const Color(0xFFC026D3); // Fuchsia

  @override
  List<String> getEnabledModuleIds() => ['attendance', 'staff', 'branch', 'shifts'];
  @override
  List<DashboardWidget> getDashboardWidgets() => [StatsGridWidget(), QuickActionsGridWidget()];
  @override
  List<String> getAvailableReports() => ['Branch Attendance', 'Staff Shift Report'];
  @override
  List<String> getAvailableCharts() => ['Branch Performance', 'Staff Attendance Trends'];

  @override
  List<DirectoryType> getSupportedMasterDataTypes() => [
        DirectoryType.branch,
        DirectoryType.store,
        DirectoryType.department,
        DirectoryType.team,
      ];
  @override
  List<DirectoryType> getUserAssignmentTypes() => [
        DirectoryType.branch,
        DirectoryType.store,
      ];
}

class WarehouseConfig extends OrganizationConfig {
  @override
  String get memberLabel => 'Loader / Operator';
  @override
  String get memberPlural => 'Loaders & Operators';
  @override
  String get teacherManagerLabel => 'Floor Supervisor';
  @override
  String get teacherManagerPlural => 'Floor Supervisors';
  @override
  String get receptionistLabel => 'Dispatcher';
  @override
  String get teamLabel => 'Crew / Shift';
  @override
  String get teamPlural => 'Crews & Shifts';
  @override
  String get departmentLabel => 'Warehouse Zone';
  @override
  String get departmentPlural => 'Warehouse Zones';
  @override
  String get idLabel => 'Operator ID';

  @override
  Color get primaryColor => const Color(0xFF4F46E5); // Indigo
  @override
  Color get secondaryColor => const Color(0xFF06B6D4); // Cyan

  @override
  List<String> getEnabledModuleIds() => ['attendance', 'workers', 'warehouse', 'shifts'];
  @override
  List<DashboardWidget> getDashboardWidgets() => [StatsGridWidget(), QuickActionsGridWidget()];
  @override
  List<String> getAvailableReports() => ['Loading Team Attendance', 'Dispatch Attendance', 'Shift Report'];
  @override
  List<String> getAvailableCharts() => ['Loading Team Performance', 'Dispatch Analytics', 'Shift Roster Stats'];

  @override
  List<DirectoryType> getSupportedMasterDataTypes() => [
        DirectoryType.zone,
        DirectoryType.crew,
        DirectoryType.loadingTeam,
        DirectoryType.dispatchTeam,
      ];
  @override
  List<DirectoryType> getUserAssignmentTypes() => [
        DirectoryType.zone,
        DirectoryType.crew,
      ];
}

class OrganizationConfigRegistry {
  static final Map<OrganizationType, OrganizationConfig> _configs = {
    OrganizationType.corporate: CorporateConfig(),
    OrganizationType.factory: FactoryConfig(),
    OrganizationType.school: SchoolConfig(),
    OrganizationType.hospital: HospitalConfig(),
    OrganizationType.retail: RetailConfig(),
    OrganizationType.warehouse: WarehouseConfig(),
  };

  static OrganizationConfig of(OrganizationType type) {
    return _configs[type] ?? CorporateConfig();
  }
}
