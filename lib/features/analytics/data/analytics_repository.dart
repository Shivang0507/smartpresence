import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';

class AttendanceAnalytics {
  const AttendanceAnalytics({
    required this.totalUsers,
    required this.presentToday,
    required this.absentToday,
    required this.attendancePercent,
    required this.activeSessions,
  });

  final int totalUsers;
  final int presentToday;
  final int absentToday;
  final double attendancePercent;
  final int activeSessions;
}

class ChartPoint {
  const ChartPoint(this.label, this.value);

  final String label;
  final num value;
}

class AnalyticsRepository {
  AnalyticsRepository() : _firestore = FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<AttendanceAnalytics> loadSummary(String organizationId) async {
    final users = await _firestore
        .collection(FirestorePaths.users)
        .where('organizationId', isEqualTo: organizationId)
        .where('isActive', isEqualTo: true)
        .get();
    final records = await _firestore
        .collection(FirestorePaths.attendanceRecords)
        .where('organizationId', isEqualTo: organizationId)
        .where('date', isEqualTo: _today())
        .get();
    final sessions = await _firestore
        .collection(FirestorePaths.attendanceSessions)
        .where('organizationId', isEqualTo: organizationId)
        .where('status', isEqualTo: 'active')
        .get();

    final totalUsers = users.docs.length;
    final present = records.docs.map((doc) => doc.data()['userId']).toSet().length;
    final absent = totalUsers - present;
    return AttendanceAnalytics(
      totalUsers: totalUsers,
      presentToday: present,
      absentToday: absent < 0 ? 0 : absent,
      attendancePercent: totalUsers == 0 ? 0 : (present / totalUsers) * 100,
      activeSessions: sessions.docs.length,
    );
  }

  List<ChartPoint> pie(AttendanceAnalytics analytics) {
    return [
      ChartPoint('Present', analytics.presentToday),
      ChartPoint('Absent', analytics.absentToday),
    ];
  }

  List<ChartPoint> bar(AttendanceAnalytics analytics) {
    return [
      ChartPoint('Users', analytics.totalUsers),
      ChartPoint('Present', analytics.presentToday),
      ChartPoint('Sessions', analytics.activeSessions),
    ];
  }

  /// Loads real attendance trend data from Firestore based on [filter].
  ///
  /// Returns one [ChartPoint] per period (day/week/month) with the
  /// attendance percentage for that period.
  Future<List<ChartPoint>> loadTrend(
    String organizationId,
    String filter, {
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    final dates = _datesForFilter(filter, customStart: customStart, customEnd: customEnd);
    if (dates.isEmpty) return const [];

    // Get total active users (denominator for percentage)
    final usersSnapshot = await _firestore
        .collection(FirestorePaths.users)
        .where('organizationId', isEqualTo: organizationId)
        .where('isActive', isEqualTo: true)
        .get();
    final totalUsers = usersSnapshot.docs.length;
    if (totalUsers == 0) return dates.map((d) => ChartPoint(_shortLabel(d), 0)).toList();

    // Fetch attendance records for the date range
    final dateStrings = dates.map(_formatDate).toSet();
    final recordsSnapshot = await _firestore
        .collection(FirestorePaths.attendanceRecords)
        .where('organizationId', isEqualTo: organizationId)
        .where('date', whereIn: dateStrings.take(30).toList()) // Firestore 'whereIn' limit is 30
        .get();

    // Group records by date and count unique users
    final presentByDate = <String, Set<String>>{};
    for (final doc in recordsSnapshot.docs) {
      final data = doc.data();
      final date = data['date'] as String?;
      final userId = data['userId'] as String?;
      if (date != null && userId != null) {
        presentByDate.putIfAbsent(date, () => {}).add(userId);
      }
    }

    // Build chart points
    if (filter == 'Weekly' || filter == 'Monthly') {
      return _aggregateByPeriod(dates, presentByDate, totalUsers, filter);
    }

    return dates.map((date) {
      final dateStr = _formatDate(date);
      final present = presentByDate[dateStr]?.length ?? 0;
      final percent = (present / totalUsers * 100).roundToDouble();
      return ChartPoint(_shortLabel(date), percent);
    }).toList();
  }

  List<ChartPoint> _aggregateByPeriod(
    List<DateTime> dates,
    Map<String, Set<String>> presentByDate,
    int totalUsers,
    String filter,
  ) {
    final points = <ChartPoint>[];

    if (filter == 'Weekly') {
      // Group into 4 weeks
      for (var week = 0; week < 4; week++) {
        final start = week * 7;
        final end = start + 7;
        final weekDates = dates.skip(start).take(end - start);
        if (weekDates.isEmpty) continue;

        double totalPercent = 0;
        int dayCount = 0;
        for (final date in weekDates) {
          final present = presentByDate[_formatDate(date)]?.length ?? 0;
          totalPercent += present / totalUsers * 100;
          dayCount++;
        }
        final avg = dayCount == 0 ? 0.0 : (totalPercent / dayCount).roundToDouble();
        points.add(ChartPoint('W${week + 1}', avg));
      }
    } else {
      // Monthly: group by month
      final byMonth = <String, List<DateTime>>{};
      for (final date in dates) {
        final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        byMonth.putIfAbsent(key, () => []).add(date);
      }

      for (final entry in byMonth.entries) {
        double totalPercent = 0;
        for (final date in entry.value) {
          final present = presentByDate[_formatDate(date)]?.length ?? 0;
          totalPercent += present / totalUsers * 100;
        }
        final avg = entry.value.isEmpty
            ? 0.0
            : (totalPercent / entry.value.length).roundToDouble();
        final monthName = _monthName(int.parse(entry.key.split('-')[1]));
        points.add(ChartPoint(monthName, avg));
      }
    }

    return points;
  }

  /// Generates the list of dates for a given filter.
  List<DateTime> _datesForFilter(
    String filter, {
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (filter) {
      case 'Daily':
        return List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
      case 'Weekly':
        return List.generate(28, (i) => today.subtract(Duration(days: 27 - i)));
      case 'Monthly':
        final dates = <DateTime>[];
        for (var m = 5; m >= 0; m--) {
          final month = DateTime(now.year, now.month - m, 1);
          final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
          for (var d = 1; d <= daysInMonth; d++) {
            final date = DateTime(month.year, month.month, d);
            if (date.isAfter(today)) break;
            dates.add(date);
          }
        }
        return dates;
      case 'Custom':
        if (customStart == null || customEnd == null) return [];
        final days = customEnd.difference(customStart).inDays + 1;
        return List.generate(
          days > 180 ? 180 : days, // cap at 180 days
          (i) => customStart.add(Duration(days: i)),
        );
      default:
        return List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    }
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _today() => _formatDate(DateTime.now());

  String _shortLabel(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]} ${d.day}';
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[(month - 1) % 12];
  }
}
