class AttendanceSession {
  const AttendanceSession({
    required this.id,
    required this.organizationId,
    required this.timestamp,
    required this.securityToken,
    required this.status,
    required this.presentCount,
  });

  final String id;
  final String organizationId;
  final DateTime timestamp;
  final String securityToken;
  final String status;
  final int presentCount;

  factory AttendanceSession.fromMap(String id, Map<String, dynamic> map) {
    final timestamp = map['timestamp'];
    return AttendanceSession(
      id: id,
      organizationId: map['organizationId'] as String? ?? '',
      timestamp: timestamp is DateTime ? timestamp : DateTime.now(),
      securityToken: map['securityToken'] as String? ?? '',
      status: map['status'] as String? ?? 'active',
      presentCount: map['presentCount'] as int? ?? 0,
    );
  }

  String get qrPayload {
    return [
      'sessionId=$id',
      'organizationId=$organizationId',
      'timestamp=${timestamp.toIso8601String()}',
      'token=$securityToken',
    ].join('&');
  }
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.userId,
    required this.organizationId,
    required this.sessionId,
    required this.date,
    required this.time,
    required this.status,
    required this.method,
  });

  final String id;
  final String userId;
  final String organizationId;
  final String sessionId;
  final String date;
  final String time;
  final String status;
  final String method;
}
