import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:printing/printing.dart';

import '../../../../core/widgets/premium_card.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/reports_repository.dart';
import '../../../../core/config/organization_config.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _repository = ReportsRepository();
  ReportRange _range = ReportRange.today;
  DateTimeRange? _customRange;
  bool _loading = false;
  String? _selectedReportType;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthBloc>().state.user;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No active user profile found.')),
      );
    }

    final config = OrganizationConfigRegistry.of(user.organizationType);
    _selectedReportType ??= config.getAvailableReports().first;

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(20.w),
          children: [
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Attendance Reports', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  SizedBox(height: 18.h),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedReportType,
                    decoration: const InputDecoration(labelText: 'Report Type'),
                    items: config.getAvailableReports()
                        .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedReportType = value;
                      });
                    },
                  ),
                  SizedBox(height: 12.h),
                  DropdownButtonFormField<ReportRange>(
                    initialValue: _range,
                    decoration: const InputDecoration(labelText: 'Filter Range'),
                    items: ReportRange.values
                        .map((range) => DropdownMenuItem(value: range, child: Text(range.label)))
                        .toList(),
                    onChanged: (value) async {
                      if (value == ReportRange.custom) {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          initialDateRange: _customRange ??
                              DateTimeRange(
                                start: DateTime.now().subtract(const Duration(days: 7)),
                                end: DateTime.now(),
                              ),
                        );
                        if (picked != null) {
                          setState(() {
                            _range = value!;
                            _customRange = picked;
                          });
                        }
                      } else {
                        setState(() {
                          _range = value ?? _range;
                          _customRange = null;
                        });
                      }
                    },
                  ),
                  SizedBox(height: 18.h),
                  Wrap(
                    spacing: 12.w,
                    runSpacing: 12.h,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: config.primaryColor),
                        onPressed: _loading ? null : () => _exportExcel(user.organizationId, _selectedReportType!),
                        icon: const Icon(Icons.table_view_rounded),
                        label: const Text('Excel Report'),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: config.primaryColor, side: BorderSide(color: config.primaryColor)),
                        onPressed: _loading ? null : () => _exportPdf(user.organizationId, _selectedReportType!),
                        icon: const Icon(Icons.picture_as_pdf_rounded),
                        label: const Text('PDF Report'),
                      ),
                    ],
                  ),
                  if (_loading) ...[
                    SizedBox(height: 18.h),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
            SizedBox(height: 14.h),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Output Schema Preview', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  SizedBox(height: 10.h),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.description_rounded, color: config.primaryColor),
                    title: Text('${_selectedReportType?.replaceAll(" ", "_") ?? "Attendance_Report"}.xlsx'),
                    subtitle: const Text('Columns: ID, Name, Department, Date, Check-In, Check-Out, Status'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.picture_as_pdf_rounded, color: config.primaryColor),
                    title: Text('${_selectedReportType?.replaceAll(" ", "_") ?? "Attendance_Report"}.pdf'),
                    subtitle: const Text('Premium PDF layout formatted with organization headers and timestamp'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportExcel(String organizationId, String reportName) async {
    await _runExport(() async {
      final rows = await _repository.loadRows(
        organizationId: organizationId,
        range: _range,
        customStart: _customRange?.start,
        customEnd: _customRange?.end,
      );
      final bytes = _repository.exportExcel(rows);
      final filename = '${reportName.replaceAll(" ", "_")}.xlsx';
      _message('$filename generated (${bytes.length} bytes).');
    });
  }

  Future<void> _exportPdf(String organizationId, String reportName) async {
    await _runExport(() async {
      final rows = await _repository.loadRows(
        organizationId: organizationId,
        range: _range,
        customStart: _customRange?.start,
        customEnd: _customRange?.end,
      );
      final orgName = await _repository.getOrganizationName(organizationId);
      final bytes = await _repository.exportPdf(
        organizationName: orgName,
        rows: rows,
      );
      final filename = '${reportName.replaceAll(" ", "_")}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: filename);
      _message('$filename generated.');
    });
  }

  Future<void> _runExport(Future<void> Function() action) async {
    setState(() => _loading = true);
    try {
      await action();
    } catch (error) {
      _message('Report generation failed: $error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _message(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}
