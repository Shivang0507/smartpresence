import 'package:flutter/material.dart';

abstract class AppModule {
  String get id;
  String get name;
  IconData get icon;
  String get route;
}

class ShiftModule implements AppModule {
  @override
  String get id => 'shifts';
  @override
  String get name => 'Shift Management';
  @override
  IconData get icon => Icons.schedule_rounded;
  @override
  String get route => '/admin/shifts';
}

class LeaveModule implements AppModule {
  @override
  String get id => 'leave';
  @override
  String get name => 'Leave Management';
  @override
  IconData get icon => Icons.sick_rounded;
  @override
  String get route => '/settings';
}

class TimetableModule implements AppModule {
  @override
  String get id => 'timetable';
  @override
  String get name => 'Timetable';
  @override
  IconData get icon => Icons.calendar_view_week_rounded;
  @override
  String get route => '/settings';
}

class RosterModule implements AppModule {
  @override
  String get id => 'roster';
  @override
  String get name => 'Duty Roster';
  @override
  IconData get icon => Icons.edit_calendar_rounded;
  @override
  String get route => '/admin/shifts';
}

class BranchModule implements AppModule {
  @override
  String get id => 'branch';
  @override
  String get name => 'Branches';
  @override
  IconData get icon => Icons.store_rounded;
  @override
  String get route => '/admin/departments';
}

class WarehouseModule implements AppModule {
  @override
  String get id => 'warehouse';
  @override
  String get name => 'Warehouse Zones';
  @override
  IconData get icon => Icons.warehouse_rounded;
  @override
  String get route => '/admin/departments';
}

class ModuleRegistry {
  static final Map<String, AppModule> _modules = {
    'shifts': ShiftModule(),
    'leave': LeaveModule(),
    'timetable': TimetableModule(),
    'roster': RosterModule(),
    'branch': BranchModule(),
    'warehouse': WarehouseModule(),
  };

  static AppModule? getModule(String id) => _modules[id];
}
