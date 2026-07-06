import 'package:cloud_firestore/cloud_firestore.dart';

enum ShiftStatus {
  draft,
  active,
  inactive,
  archived;

  static ShiftStatus fromString(String val) {
    return ShiftStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => ShiftStatus.draft,
    );
  }
}

class ShiftTime {
  final int hour;
  final int minute;

  const ShiftTime(this.hour, this.minute);

  factory ShiftTime.fromMinutes(int minutes) {
    return ShiftTime((minutes ~/ 60) % 24, minutes % 60);
  }

  factory ShiftTime.fromString(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length < 2) return const ShiftTime(0, 0);
    return ShiftTime(
      int.tryParse(parts[0]) ?? 0,
      int.tryParse(parts[1]) ?? 0,
    );
  }

  int get totalMinutes => hour * 60 + minute;

  String format24h() {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String format12h() {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$h12:${minute.toString().padLeft(2, '0')} $period';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShiftTime &&
          runtimeType == other.runtimeType &&
          hour == other.hour &&
          minute == other.minute;

  @override
  int get hashCode => hour.hashCode ^ minute.hashCode;
}

class Shift {
  final String id;
  final String organizationId;
  final String name;
  final String? code;
  final String description;
  final String color;
  final int version;
  final ShiftStatus status;
  final DateTime effectiveFrom;
  final DateTime? effectiveUntil;

  // Time configurations (in minutes from midnight)
  final int startMinutes;
  final int endMinutes;
  final int breakStartMinutes;
  final int breakEndMinutes;

  // Attendance rules
  final int graceTime;
  final int lateEntryThreshold;
  final int absentAfterMinutes;
  final int halfDayThreshold;
  final double minWorkingHours;
  final bool overtimeAllowed;
  final int overtimeStartsAfter;
  final double maxOvertimeHours;
  final int earlyCheckInWindow;
  final int lateCheckOutWindow;
  final int earlyExitThreshold;
  final int checkInWindowStartMinutes;
  final int checkInWindowEndMinutes;
  final int checkOutWindowStartMinutes;
  final int checkOutWindowEndMinutes;

  // Verification Rules
  final bool requireFaceVerification;
  final bool requireQrVerification;

  // Weekly Schedule
  final List<int> weeklyOffs; // 1 = Monday, 7 = Sunday
  final bool isRotating;
  final int rotationFrequency; // in weeks

  // Capacity Limits
  final int? minEmployees;
  final int? recEmployees;
  final int? maxEmployees;

  const Shift({
    required this.id,
    required this.organizationId,
    required this.name,
    this.code,
    this.description = '',
    this.color = '0xFFD97706',
    this.version = 1,
    this.status = ShiftStatus.draft,
    required this.effectiveFrom,
    this.effectiveUntil,
    required this.startMinutes,
    required this.endMinutes,
    required this.breakStartMinutes,
    required this.breakEndMinutes,
    this.graceTime = 10,
    this.lateEntryThreshold = 15,
    this.absentAfterMinutes = 60,
    this.halfDayThreshold = 240,
    this.minWorkingHours = 8.0,
    this.overtimeAllowed = false,
    this.overtimeStartsAfter = 30,
    this.maxOvertimeHours = 4.0,
    this.earlyCheckInWindow = 30,
    this.lateCheckOutWindow = 60,
    this.earlyExitThreshold = 10,
    required this.checkInWindowStartMinutes,
    required this.checkInWindowEndMinutes,
    required this.checkOutWindowStartMinutes,
    required this.checkOutWindowEndMinutes,
    this.requireFaceVerification = false,
    this.requireQrVerification = false,
    this.weeklyOffs = const [7], // Default Sunday off
    this.isRotating = false,
    this.rotationFrequency = 1,
    this.minEmployees,
    this.recEmployees,
    this.maxEmployees,
  });

  double calculateWorkingHours() {
    final totalDuration = (endMinutes - startMinutes) % 1440;
    final breakDuration = (breakEndMinutes - breakStartMinutes) % 1440;
    final workingMinutes = (totalDuration - breakDuration).clamp(0, 1440);
    return double.parse((workingMinutes / 60.0).toStringAsFixed(2));
  }

  bool isTimeWithinShift(int t) {
    if (startMinutes <= endMinutes) {
      return t >= startMinutes && t <= endMinutes;
    } else {
      // Overnight
      return t >= startMinutes || t <= endMinutes;
    }
  }

  bool isBreakValid() {
    if (!isTimeWithinShift(breakStartMinutes)) return false;
    if (!isTimeWithinShift(breakEndMinutes)) return false;

    if (startMinutes <= endMinutes) {
      return breakStartMinutes <= breakEndMinutes;
    } else {
      // Overnight
      final bsNight = breakStartMinutes >= startMinutes;
      final beNight = breakEndMinutes >= startMinutes;
      final bsMorning = breakStartMinutes <= endMinutes;
      final beMorning = breakEndMinutes <= endMinutes;

      if (bsNight && beNight) {
        return breakStartMinutes <= breakEndMinutes;
      }
      if (bsMorning && beMorning) {
        return breakStartMinutes <= breakEndMinutes;
      }
      if (bsNight && beMorning) {
        return true; // Spans midnight
      }
      return false; // Morning back to night (invalid)
    }
  }

  Shift copyWith({
    String? id,
    String? organizationId,
    String? name,
    String? code,
    String? description,
    String? color,
    int? version,
    ShiftStatus? status,
    DateTime? effectiveFrom,
    DateTime? effectiveUntil,
    int? startMinutes,
    int? endMinutes,
    int? breakStartMinutes,
    int? breakEndMinutes,
    int? graceTime,
    int? lateEntryThreshold,
    int? absentAfterMinutes,
    int? halfDayThreshold,
    double? minWorkingHours,
    bool? overtimeAllowed,
    int? overtimeStartsAfter,
    double? maxOvertimeHours,
    int? earlyCheckInWindow,
    int? lateCheckOutWindow,
    int? earlyExitThreshold,
    int? checkInWindowStartMinutes,
    int? checkInWindowEndMinutes,
    int? checkOutWindowStartMinutes,
    int? checkOutWindowEndMinutes,
    bool? requireFaceVerification,
    bool? requireQrVerification,
    List<int>? weeklyOffs,
    bool? isRotating,
    int? rotationFrequency,
    int? minEmployees,
    int? recEmployees,
    int? maxEmployees,
  }) {
    return Shift(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      color: color ?? this.color,
      version: version ?? this.version,
      status: status ?? this.status,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      effectiveUntil: effectiveUntil ?? this.effectiveUntil,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      breakStartMinutes: breakStartMinutes ?? this.breakStartMinutes,
      breakEndMinutes: breakEndMinutes ?? this.breakEndMinutes,
      graceTime: graceTime ?? this.graceTime,
      lateEntryThreshold: lateEntryThreshold ?? this.lateEntryThreshold,
      absentAfterMinutes: absentAfterMinutes ?? this.absentAfterMinutes,
      halfDayThreshold: halfDayThreshold ?? this.halfDayThreshold,
      minWorkingHours: minWorkingHours ?? this.minWorkingHours,
      overtimeAllowed: overtimeAllowed ?? this.overtimeAllowed,
      overtimeStartsAfter: overtimeStartsAfter ?? this.overtimeStartsAfter,
      maxOvertimeHours: maxOvertimeHours ?? this.maxOvertimeHours,
      earlyCheckInWindow: earlyCheckInWindow ?? this.earlyCheckInWindow,
      lateCheckOutWindow: lateCheckOutWindow ?? this.lateCheckOutWindow,
      earlyExitThreshold: earlyExitThreshold ?? this.earlyExitThreshold,
      checkInWindowStartMinutes: checkInWindowStartMinutes ?? this.checkInWindowStartMinutes,
      checkInWindowEndMinutes: checkInWindowEndMinutes ?? this.checkInWindowEndMinutes,
      checkOutWindowStartMinutes: checkOutWindowStartMinutes ?? this.checkOutWindowStartMinutes,
      checkOutWindowEndMinutes: checkOutWindowEndMinutes ?? this.checkOutWindowEndMinutes,
      requireFaceVerification: requireFaceVerification ?? this.requireFaceVerification,
      requireQrVerification: requireQrVerification ?? this.requireQrVerification,
      weeklyOffs: weeklyOffs ?? this.weeklyOffs,
      isRotating: isRotating ?? this.isRotating,
      rotationFrequency: rotationFrequency ?? this.rotationFrequency,
      minEmployees: minEmployees ?? this.minEmployees,
      recEmployees: recEmployees ?? this.recEmployees,
      maxEmployees: maxEmployees ?? this.maxEmployees,
    );
  }

  factory Shift.fromMap(String id, Map<String, dynamic> map) {
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

    return Shift(
      id: id,
      organizationId: map['organizationId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      code: map['code'] as String?,
      description: map['description'] as String? ?? '',
      color: map['color'] as String? ?? '0xFFD97706',
      version: map['version'] as int? ?? 1,
      status: ShiftStatus.fromString(map['status'] as String? ?? 'draft'),
      effectiveFrom: parseDate(map['effectiveFrom']),
      effectiveUntil: parseDateNullable(map['effectiveUntil']),
      startMinutes: map['startMinutes'] as int? ?? 480,
      endMinutes: map['endMinutes'] as int? ?? 1020,
      breakStartMinutes: map['breakStartMinutes'] as int? ?? 720,
      breakEndMinutes: map['breakEndMinutes'] as int? ?? 780,
      graceTime: map['graceTime'] as int? ?? 10,
      lateEntryThreshold: map['lateEntryThreshold'] as int? ?? 15,
      absentAfterMinutes: map['absentAfterMinutes'] as int? ?? 60,
      halfDayThreshold: map['halfDayThreshold'] as int? ?? 240,
      minWorkingHours: (map['minWorkingHours'] as num? ?? 8.0).toDouble(),
      overtimeAllowed: map['overtimeAllowed'] as bool? ?? false,
      overtimeStartsAfter: map['overtimeStartsAfter'] as int? ?? 30,
      maxOvertimeHours: (map['maxOvertimeHours'] as num? ?? 4.0).toDouble(),
      earlyCheckInWindow: map['earlyCheckInWindow'] as int? ?? 30,
      lateCheckOutWindow: map['lateCheckOutWindow'] as int? ?? 60,
      earlyExitThreshold: map['earlyExitThreshold'] as int? ?? 10,
      checkInWindowStartMinutes: map['checkInWindowStartMinutes'] as int? ?? 450,
      checkInWindowEndMinutes: map['checkInWindowEndMinutes'] as int? ?? 540,
      checkOutWindowStartMinutes: map['checkOutWindowStartMinutes'] as int? ?? 1020,
      checkOutWindowEndMinutes: map['checkOutWindowEndMinutes'] as int? ?? 1080,
      requireFaceVerification: map['requireFaceVerification'] as bool? ?? false,
      requireQrVerification: map['requireQrVerification'] as bool? ?? false,
      weeklyOffs: List<int>.from(map['weeklyOffs'] ?? const [7]),
      isRotating: map['isRotating'] as bool? ?? false,
      rotationFrequency: map['rotationFrequency'] as int? ?? 1,
      minEmployees: map['minEmployees'] as int?,
      recEmployees: map['recEmployees'] as int?,
      maxEmployees: map['maxEmployees'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'name': name,
      'code': code,
      'description': description,
      'color': color,
      'version': version,
      'status': status.name,
      'effectiveFrom': Timestamp.fromDate(effectiveFrom),
      if (effectiveUntil != null) 'effectiveUntil': Timestamp.fromDate(effectiveUntil!),
      'startMinutes': startMinutes,
      'endMinutes': endMinutes,
      'breakStartMinutes': breakStartMinutes,
      'breakEndMinutes': breakEndMinutes,
      'graceTime': graceTime,
      'lateEntryThreshold': lateEntryThreshold,
      'absentAfterMinutes': absentAfterMinutes,
      'halfDayThreshold': halfDayThreshold,
      'minWorkingHours': minWorkingHours,
      'overtimeAllowed': overtimeAllowed,
      'overtimeStartsAfter': overtimeStartsAfter,
      'maxOvertimeHours': maxOvertimeHours,
      'earlyCheckInWindow': earlyCheckInWindow,
      'lateCheckOutWindow': lateCheckOutWindow,
      'earlyExitThreshold': earlyExitThreshold,
      'checkInWindowStartMinutes': checkInWindowStartMinutes,
      'checkInWindowEndMinutes': checkInWindowEndMinutes,
      'checkOutWindowStartMinutes': checkOutWindowStartMinutes,
      'checkOutWindowEndMinutes': checkOutWindowEndMinutes,
      'requireFaceVerification': requireFaceVerification,
      'requireQrVerification': requireQrVerification,
      'weeklyOffs': weeklyOffs,
      'isRotating': isRotating,
      'rotationFrequency': rotationFrequency,
      'minEmployees': minEmployees,
      'recEmployees': recEmployees,
      'maxEmployees': maxEmployees,
    };
  }
}
