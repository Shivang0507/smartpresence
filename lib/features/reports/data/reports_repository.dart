import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/firestore_paths.dart';

class AttendanceReportRow {
  const AttendanceReportRow({
    required this.name,
    required this.userCode,
    required this.department,
    required this.date,
    required this.time,
    required this.status,
  });

  final String name;
  final String userCode;
  final String department;
  final String date;
  final String time;
  final String status;
}

enum ReportRange {
  today('Today', 0),
  yesterday('Yesterday', 1),
  last7Days('Last 7 Days', 7),
  last30Days('Last 30 Days', 30),
  custom('Custom Range', 0);

  const ReportRange(this.label, this.days);

  final String label;
  final int days;
}

class ReportsRepository {
  ReportsRepository() : _firestore = FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<AttendanceReportRow>> loadRows({
    required String organizationId,
    required ReportRange range,
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    final records = await _firestore
        .collection(FirestorePaths.attendanceRecords)
        .where('organizationId', isEqualTo: organizationId)
        .get();
    final users = await _firestore
        .collection(FirestorePaths.users)
        .where('organizationId', isEqualTo: organizationId)
        .get();
    final departments = await _firestore
        .collection(FirestorePaths.organizations)
        .doc(organizationId)
        .collection(FirestorePaths.departments)
        .get();
    final userById = {for (final doc in users.docs) doc.id: doc.data()};
    final departmentById = {
      for (final doc in departments.docs)
        doc.id: doc.data()['name'] as String? ?? doc.id,
    };
    final allowedDates = _datesFor(range, customStart: customStart, customEnd: customEnd);

    return records.docs
        .where(
          (doc) =>
              allowedDates.isEmpty || allowedDates.contains(doc.data()['date']),
        )
        .map((doc) {
          final data = doc.data();
          final user = userById[data['userId']] ?? const <String, dynamic>{};
          final userId = data['userId'] as String? ?? '';
          final departmentId = user['departmentId'] as String?;
          return AttendanceReportRow(
            name: user['name'] as String? ?? 'Unknown User',
            userCode: user['employeeId'] as String? ?? userId,
            department: departmentById[departmentId] ?? departmentId ?? '-',
            date: data['date'] as String? ?? '',
            time: data['time'] as String? ?? '',
            status: data['status'] as String? ?? 'present',
          );
        })
        .toList()
      ..sort((a, b) => '${b.date}${b.time}'.compareTo('${a.date}${a.time}'));
  }

  /// Fetches the organization's real name from Firestore.
  Future<String> getOrganizationName(String organizationId) async {
    final doc = await _firestore
        .collection(FirestorePaths.organizations)
        .doc(organizationId)
        .get();
    if (!doc.exists || doc.data() == null) {
      return 'SmartPresence Organization';
    }
    return doc.data()!['name'] as String? ?? 'SmartPresence Organization';
  }

  Uint8List exportExcel(List<AttendanceReportRow> rows) {
    final excel = Excel.createExcel();
    const sheetName = 'Attendance';
    final sheet = excel[sheetName];
    sheet.appendRow([
      TextCellValue('Name'),
      TextCellValue('ID'),
      TextCellValue('Department'),
      TextCellValue('Date'),
      TextCellValue('Time'),
      TextCellValue('Status'),
    ]);
    for (final row in rows) {
      sheet.appendRow([
        TextCellValue(row.name),
        TextCellValue(row.userCode),
        TextCellValue(row.department),
        TextCellValue(row.date),
        TextCellValue(row.time),
        TextCellValue(row.status),
      ]);
    }
    excel.setDefaultSheet(sheetName);
    return Uint8List.fromList(excel.encode() ?? const <int>[]);
  }

  Future<Uint8List> exportPdf({
    required String organizationName,
    required List<AttendanceReportRow> rows,
  }) async {
    final document = pw.Document();
    final present = rows
        .where((row) => row.status.toLowerCase() == 'present')
        .length;
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            organizationName,
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Attendance_Report.pdf'),
          pw.Text('Generated: ${DateTime.now()}'),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Records: ${rows.length}'),
              pw.Text('Present: $present'),
              pw.Text('Absent: ${rows.length - present}'),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Summary Chart',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            height: 18,
            width: 300,
            color: PdfColors.grey300,
            child: pw.Row(
              children: [
                pw.Container(
                  width: rows.isEmpty ? 0 : 300 * (present / rows.length),
                  color: PdfColors.green600,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Name',
              'ID',
              'Department',
              'Date',
              'Time',
              'Status',
            ],
            data: rows
                .map(
                  (row) => [
                    row.name,
                    row.userCode,
                    row.department,
                    row.date,
                    row.time,
                    row.status,
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
    return document.save();
  }

  Set<String> _datesFor(
    ReportRange range, {
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final now = DateTime.now();
    if (range == ReportRange.custom) {
      if (customStart == null || customEnd == null) return const <String>{};
      final days = customEnd.difference(customStart).inDays + 1;
      return {
        for (var index = 0; index < days; index++)
          _date(customStart.add(Duration(days: index))),
      };
    }
    if (range == ReportRange.yesterday) {
      return {_date(now.subtract(const Duration(days: 1)))};
    }
    final count = range == ReportRange.today ? 1 : range.days;
    return {
      for (var index = 0; index < count; index++)
        _date(now.subtract(Duration(days: index))),
    };
  }

  String _date(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}
