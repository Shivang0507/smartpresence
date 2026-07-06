import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:syncfusion_flutter_charts/charts.dart' hide ChartPoint;

import '../../../../core/widgets/premium_card.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/analytics_repository.dart';
import '../../../../core/config/organization_config.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  final _repository = AnalyticsRepository();
  String _filter = 'Daily';
  DateTimeRange? _customRange;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthBloc>().state.user;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No active user profile found.')),
      );
    }

    final config = OrganizationConfigRegistry.of(user.organizationType);

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: SafeArea(
        child: FutureBuilder<AttendanceAnalytics>(
          future: _repository.loadSummary(user.organizationId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final analytics =
                snapshot.data ??
                const AttendanceAnalytics(
                  totalUsers: 0,
                  presentToday: 0,
                  absentToday: 0,
                  attendancePercent: 0,
                  activeSessions: 0,
                );

            final chartConfigs = config.getAvailableCharts();
            final pieTitle = chartConfigs.isNotEmpty ? chartConfigs[0] : 'Presence Split';
            final barTitle = chartConfigs.length > 1 ? chartConfigs[1] : 'Operational Snapshot';
            final lineTitle = chartConfigs.length > 2 ? chartConfigs[2] : 'Attendance Trend';

            return ListView(
              padding: EdgeInsets.all(20.w),
              children: [
                _FilterTabs(
                  value: _filter,
                  onChanged: (value) => _onFilterChanged(value),
                  config: config,
                ),
                SizedBox(height: 14.h),
                _MetricsGrid(analytics: analytics, config: config),
                SizedBox(height: 14.h),
                _ChartCard(
                  title: pieTitle,
                  child: SfCircularChart(
                    series: [
                      PieSeries<ChartPoint, String>(
                        dataSource: _repository.pie(analytics),
                        xValueMapper: (point, _) => point.label,
                        yValueMapper: (point, _) => point.value,
                        dataLabelSettings: const DataLabelSettings(
                          isVisible: true,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14.h),
                _ChartCard(
                  title: barTitle,
                  child: SfCartesianChart(
                    primaryXAxis: const CategoryAxis(),
                    series: [
                      ColumnSeries<ChartPoint, String>(
                        dataSource: _repository.bar(analytics),
                        xValueMapper: (point, _) => point.label,
                        yValueMapper: (point, _) => point.value,
                        color: config.primaryColor,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14.h),
                _ChartCard(
                  title: lineTitle,
                  child: FutureBuilder<List<ChartPoint>>(
                    future: _repository.loadTrend(
                      user.organizationId,
                      _filter,
                      customStart: _customRange?.start,
                      customEnd: _customRange?.end,
                    ),
                    builder: (context, trendSnapshot) {
                      if (trendSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final trendData = trendSnapshot.data ?? const [];
                      if (trendData.isEmpty) {
                        return SizedBox(
                          height: 200.h,
                          child: Center(
                            child: Text(
                              'No attendance data for the selected period.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        );
                      }
                      return SfCartesianChart(
                        primaryXAxis: const CategoryAxis(),
                        primaryYAxis: const NumericAxis(
                          minimum: 0,
                          maximum: 100,
                        ),
                        series: [
                          LineSeries<ChartPoint, String>(
                            dataSource: trendData,
                            xValueMapper: (point, _) => point.label,
                            yValueMapper: (point, _) => point.value,
                            color: config.primaryColor,
                            markerSettings: MarkerSettings(
                              isVisible: true,
                              color: config.secondaryColor,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _onFilterChanged(String value) async {
    if (value == 'Custom') {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDateRange: _customRange ??
            DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 30)),
              end: DateTime.now(),
            ),
      );
      if (picked != null) {
        setState(() {
          _filter = value;
          _customRange = picked;
        });
      }
    } else {
      setState(() {
        _filter = value;
        _customRange = null;
      });
    }
  }
}

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({required this.value, required this.onChanged, required this.config});

  final String value;
  final ValueChanged<String> onChanged;
  final OrganizationConfig config;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: config.primaryColor.withValues(alpha: 0.15),
        selectedForegroundColor: config.primaryColor,
      ),
      segments: const [
        ButtonSegment(value: 'Daily', label: Text('Daily')),
        ButtonSegment(value: 'Weekly', label: Text('Weekly')),
        ButtonSegment(value: 'Monthly', label: Text('Monthly')),
        ButtonSegment(value: 'Custom', label: Text('Custom')),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.analytics, required this.config});

  final AttendanceAnalytics analytics;
  final OrganizationConfig config;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Total ${config.memberPlural}', analytics.totalUsers.toString(), Icons.groups_rounded),
      (
        'Present Today',
        analytics.presentToday.toString(),
        Icons.how_to_reg_rounded,
      ),
      (
        'Absent Today',
        analytics.absentToday.toString(),
        Icons.person_off_rounded,
      ),
      (
        'Attendance %',
        '${analytics.attendancePercent.toStringAsFixed(1)}%',
        Icons.percent_rounded,
      ),
      (
        'Active Sessions',
        analytics.activeSessions.toString(),
        Icons.sensors_rounded,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.sizeOf(context).width > 760 ? 5 : 2,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
        childAspectRatio: 1.25,
      ),
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(metric.$3, color: config.primaryColor),
              Text(metric.$2, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              Text(metric.$1, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
            ],
          ),
        );
      },
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          SizedBox(height: 12.h),
          SizedBox(height: 280.h, child: child),
        ],
      ),
    );
  }
}
