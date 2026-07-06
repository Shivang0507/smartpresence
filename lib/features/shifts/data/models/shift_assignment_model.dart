import 'package:cloud_firestore/cloud_firestore.dart';

enum ShiftAssignmentType {
  permanent,
  temporary,
  rotation;

  static ShiftAssignmentType fromString(String val) {
    return ShiftAssignmentType.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => ShiftAssignmentType.permanent,
    );
  }
}

enum ShiftAssignmentStatus {
  active,
  inactive,
  completed;

  static ShiftAssignmentStatus fromString(String val) {
    return ShiftAssignmentStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => ShiftAssignmentStatus.active,
    );
  }
}

class ShiftAssignment {
  final String id;
  final String employeeId;
  final String organizationId;
  final String shiftId;
  final ShiftAssignmentType assignmentType;
  final DateTime startDate;
  final DateTime? endDate;
  final ShiftAssignmentStatus status;
  final String createdBy;
  final DateTime createdAt;

  const ShiftAssignment({
    required this.id,
    required this.employeeId,
    required this.organizationId,
    required this.shiftId,
    required this.assignmentType,
    required this.startDate,
    this.endDate,
    this.status = ShiftAssignmentStatus.active,
    required this.createdBy,
    required this.createdAt,
  });

  ShiftAssignment copyWith({
    String? id,
    String? employeeId,
    String? organizationId,
    String? shiftId,
    ShiftAssignmentType? assignmentType,
    DateTime? startDate,
    DateTime? endDate,
    ShiftAssignmentStatus? status,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return ShiftAssignment(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      organizationId: organizationId ?? this.organizationId,
      shiftId: shiftId ?? this.shiftId,
      assignmentType: assignmentType ?? this.assignmentType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory ShiftAssignment.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseDateNullable(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return ShiftAssignment(
      id: id,
      employeeId: map['employeeId'] as String? ?? '',
      organizationId: map['organizationId'] as String? ?? '',
      shiftId: map['shiftId'] as String? ?? '',
      assignmentType: ShiftAssignmentType.fromString(map['assignmentType'] as String? ?? 'permanent'),
      startDate: parseDate(map['startDate']),
      endDate: parseDateNullable(map['endDate']),
      status: ShiftAssignmentStatus.fromString(map['status'] as String? ?? 'active'),
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'organizationId': organizationId,
      'shiftId': shiftId,
      'assignmentType': assignmentType.name,
      'startDate': Timestamp.fromDate(startDate),
      if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
      'status': status.name,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
