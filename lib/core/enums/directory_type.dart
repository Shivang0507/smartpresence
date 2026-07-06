import 'package:flutter/material.dart';

enum DirectoryType {
  department('Department', 'departments', Icons.account_tree_rounded),
  team('Team', 'teams', Icons.diversity_3_rounded),
  location('Office Location', 'locations', Icons.place_rounded),
  designation('Designation', 'designations', Icons.badge_rounded),
  productionLine('Production Line', 'productionLines', Icons.linear_scale_rounded),
  shift('Shift', 'shifts', Icons.schedule_rounded),
  clazz('Class', 'classes', Icons.school_rounded),
  section('Section', 'sections', Icons.grid_view_rounded),
  subject('Subject', 'subjects', Icons.auto_stories_rounded),
  academicYear('Academic Year', 'academicYears', Icons.date_range_rounded),
  ward('Ward', 'wards', Icons.local_hospital_rounded),
  unit('Unit', 'units', Icons.domain_rounded),
  dutyType('Duty Type', 'dutyTypes', Icons.assignment_ind_rounded),
  branch('Branch', 'branches', Icons.store_rounded),
  store('Store', 'stores', Icons.storefront_rounded),
  zone('Warehouse Zone', 'zones', Icons.warehouse_rounded),
  crew('Crew', 'crews', Icons.groups_rounded),
  loadingTeam('Loading Team', 'loadingTeams', Icons.badge_rounded),
  dispatchTeam('Dispatch Team', 'dispatchTeams', Icons.local_shipping_rounded);

  const DirectoryType(this.label, this.collection, this.icon);

  final String label;
  final String collection;
  final IconData icon;

  String? get userField => switch (this) {
    DirectoryType.department ||
    DirectoryType.subject ||
    DirectoryType.branch ||
    DirectoryType.zone => 'departmentId',
    
    DirectoryType.team ||
    DirectoryType.clazz ||
    DirectoryType.ward ||
    DirectoryType.crew ||
    DirectoryType.loadingTeam ||
    DirectoryType.dispatchTeam ||
    DirectoryType.store ||
    DirectoryType.section ||
    DirectoryType.unit => 'teamId',
    
    DirectoryType.shift ||
    DirectoryType.dutyType => 'shiftId',
    
    _ => null,
  };
}
