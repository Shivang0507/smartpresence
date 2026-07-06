import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_router.dart';
import '../../../../core/enums/organization_type.dart';
import '../../../../core/enums/user_role.dart';
import '../../../../core/widgets/sp_logo.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../core/config/organization_config.dart';
import '../../../../core/config/dashboard_widget.dart';

Stream<R> combineLatest6<T1, T2, T3, T4, T5, T6, R>(
  Stream<T1> s1,
  Stream<T2> s2,
  Stream<T3> s3,
  Stream<T4> s4,
  Stream<T5> s5,
  Stream<T6> s6,
  R Function(T1, T2, T3, T4, T5, T6) combiner,
) {
  final controller = StreamController<R>.broadcast();
  T1? v1;
  T2? v2;
  T3? v3;
  T4? v4;
  T5? v5;
  T6? v6;
  bool has1 = false, has2 = false, has3 = false, has4 = false, has5 = false, has6 = false;

  void emit() {
    if (has1 && has2 && has3 && has4 && has5 && has6) {
      if (!controller.isClosed) {
        controller.add(combiner(v1 as T1, v2 as T2, v3 as T3, v4 as T4, v5 as T5, v6 as T6));
      }
    }
  }

  final sub1 = s1.listen((v) { v1 = v; has1 = true; emit(); }, onError: controller.addError);
  final sub2 = s2.listen((v) { v2 = v; has2 = true; emit(); }, onError: controller.addError);
  final sub3 = s3.listen((v) { v3 = v; has3 = true; emit(); }, onError: controller.addError);
  final sub4 = s4.listen((v) { v4 = v; has4 = true; emit(); }, onError: controller.addError);
  final sub5 = s5.listen((v) { v5 = v; has5 = true; emit(); }, onError: controller.addError);
  final sub6 = s6.listen((v) { v6 = v; has6 = true; emit(); }, onError: controller.addError);

  controller.onCancel = () async {
    await sub1.cancel();
    await sub2.cancel();
    await sub3.cancel();
    await sub4.cancel();
    await sub5.cancel();
    await sub6.cancel();
  };

  return controller.stream;
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Stream<AdminStats>? _statsStream;
  String? _lastOrgId;

  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Stream<AdminStats> _watchStats(String orgId) {
    final todayStr = _todayDateString();

    final membersStream = FirebaseFirestore.instance
        .collection('users')
        .where('organizationId', isEqualTo: orgId)
        .where('role', isEqualTo: UserRole.member.value)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.length);

    final staffStream = FirebaseFirestore.instance
        .collection('users')
        .where('organizationId', isEqualTo: orgId)
        .where('role', isEqualTo: UserRole.teacherManager.value)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.length);

    final deptsStream = FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId)
        .collection('departments')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.length);

    final teamsStream = FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId)
        .collection('teams')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.length);

    final subjectsStream = FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId)
        .collection('subjects')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.length);

    final attendanceStream = FirebaseFirestore.instance
        .collection('attendanceRecords')
        .where('organizationId', isEqualTo: orgId)
        .where('date', isEqualTo: todayStr)
        .snapshots()
        .map((s) => s.docs.length);

    return combineLatest6<int, int, int, int, int, int, AdminStats>(
      membersStream,
      staffStream,
      deptsStream,
      teamsStream,
      subjectsStream,
      attendanceStream,
      (m, st, d, t, sub, a) => AdminStats(
        totalMembers: m,
        totalStaff: st,
        totalDepartments: d,
        totalTeams: t,
        totalSubjects: sub,
        presentTodayCount: a,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthBloc>().state.user;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No active session.')),
      );
    }

    // Dynamic Debug Logs verification
    debugPrint('ORGANIZATION NAME FROM FIRESTORE: ${user.organizationName}');

    if (_lastOrgId != user.organizationId) {
      _lastOrgId = user.organizationId;
      _statsStream = _watchStats(user.organizationId);
    }

    final orgType = user.organizationType;
    final config = OrganizationConfigRegistry.of(orgType);

    // Define colors & branding based on configuration
    final theme = Theme.of(context);

    final primaryGradientColor = config.primaryColor;
    final secondaryGradientColor = config.secondaryColor;

    final brandingTitle = user.organizationName ?? '';
    final brandingSubtitle = 'Workspace Type: ${orgType.label}';

    final navigationItems = [
      _ActionModule(
        'Home',
        Icons.dashboard_rounded,
        () => context.go(AppRouter.adminDashboard),
      ),
      _ActionModule(
        config.memberPlural,
        Icons.groups_rounded,
        () => context.push(AppRouter.users),
      ),
      if (config.getEnabledModuleIds().contains('shifts') || config.getEnabledModuleIds().contains('roster'))
        _ActionModule(
          orgType == OrganizationType.hospital ? 'Roster' : 'Shifts',
          Icons.schedule_rounded,
          () => context.push(AppRouter.shifts),
        ),
      _ActionModule(
        config.departmentPlural,
        Icons.domain_rounded,
        () => context.push(AppRouter.departments),
      ),
      _ActionModule(
        config.teamPlural,
        Icons.diversity_3_rounded,
        () => context.push(AppRouter.teams),
      ),
      _ActionModule(
        'Attendance',
        Icons.fact_check_rounded,
        () => context.push(AppRouter.attendance),
      ),
      _ActionModule(
        'Reports',
        Icons.assessment_rounded,
        () => context.push(AppRouter.reports),
      ),
      _ActionModule(
        'Analytics',
        Icons.query_stats_rounded,
        () => context.push(AppRouter.analytics),
      ),
      _ActionModule(
        'Settings',
        Icons.tune_rounded,
        () => context.push(AppRouter.settings),
      ),
    ];

    final bottomNavigationItems = [
      navigationItems[0], // Home
      navigationItems[1], // Users (Employees/Students)
      navigationItems.firstWhere((item) => item.title == 'Attendance', orElse: () => navigationItems[2]),
      navigationItems.firstWhere((item) => item.title == 'Reports', orElse: () => navigationItems[3]),
      navigationItems.last, // Settings
    ];

    return Scaffold(
      appBar: AppBar(
        title: const SpLogo(size: 40, showWordmark: true),
        actions: [
          IconButton(
            tooltip: 'Profile',
            onPressed: () => context.push(AppRouter.profile),
            icon: const Icon(Icons.account_circle_rounded),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () => context.read<AuthBloc>().add(AuthLogoutRequested()),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width >= 700
          ? null
          : NavigationBar(
              selectedIndex: 0,
              onDestinationSelected: (index) => bottomNavigationItems[index].onTap?.call(),
              destinations: [
                for (final item in bottomNavigationItems)
                  NavigationDestination(
                    icon: Icon(item.icon),
                    label: item.title,
                  ),
              ],
            ),
      body: SafeArea(
        child: Row(
          children: [
            if (MediaQuery.sizeOf(context).width >= 700)
              NavigationRail(
                selectedIndex: 0,
                onDestinationSelected: (index) => navigationItems[index].onTap?.call(),
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final item in navigationItems)
                    NavigationRailDestination(
                      icon: Icon(item.icon),
                      label: Text(item.title),
                    ),
                ],
              ),
            Expanded(
              child: StreamBuilder<AdminStats>(
                stream: _statsStream,
                builder: (context, snapshot) {
                  final stats = snapshot.data ?? const AdminStats();
                  final attendancePercentage = stats.totalMembers == 0
                      ? 0.0
                      : (stats.presentTodayCount / stats.totalMembers * 100);

                  return ListView(
                    padding: EdgeInsets.all(20.w),
                    children: [
                      // Header card with custom dynamic gradient branding
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(24.w),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16.r),
                          gradient: LinearGradient(
                            colors: [primaryGradientColor, secondaryGradientColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryGradientColor.withValues(alpha: 0.35),
                              blurRadius: 16.r,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    brandingTitle,
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 6.h),
                                  Text(
                                    brandingSubtitle,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.85),
                                    ),
                                  ),
                                  SizedBox(height: 12.h),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(100.r),
                                    ),
                                    child: Text(
                                      '${user.name} • Administrator',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.verified_user_rounded,
                              color: Colors.white,
                              size: 40.w,
                            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                                  duration: 1.seconds,
                                  begin: const Offset(0.95, 0.95),
                                  end: const Offset(1.05, 1.05),
                                ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
                      SizedBox(height: 24.h),

                      // Centralized configuration layer dashboard widgets loop
                      for (final widget in config.getDashboardWidgets()) ...[
                        Text(
                          widget.id == 'stats_grid' ? 'Live System Statistics' : 'Administrative Tasks',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 12.h),
                        widget.buildWidget(context, stats, attendancePercentage, orgType, user.organizationId),
                        SizedBox(height: 24.h),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionModule {
  const _ActionModule(this.title, this.icon, this.onTap);

  final String title;
  final IconData icon;
  final VoidCallback? onTap;
}
