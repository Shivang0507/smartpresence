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
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/premium_card.dart';
import '../../../auth/data/app_user.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../core/config/organization_config.dart';

class MemberDashboardStats {
  final int presentCount;
  final int totalSessions;
  final bool markedToday;
  final bool hasActiveSessionToday;

  const MemberDashboardStats({
    this.presentCount = 0,
    this.totalSessions = 0,
    this.markedToday = false,
    this.hasActiveSessionToday = false,
  });
}

Stream<R> combineLatest4<T1, T2, T3, T4, R>(
  Stream<T1> s1,
  Stream<T2> s2,
  Stream<T3> s3,
  Stream<T4> s4,
  R Function(T1, T2, T3, T4) combiner,
) {
  final controller = StreamController<R>.broadcast();
  T1? v1;
  T2? v2;
  T3? v3;
  T4? v4;
  bool has1 = false, has2 = false, has3 = false, has4 = false;

  void emit() {
    if (has1 && has2 && has3 && has4) {
      if (!controller.isClosed) {
        controller.add(combiner(v1 as T1, v2 as T2, v3 as T3, v4 as T4));
      }
    }
  }

  final sub1 = s1.listen((v) { v1 = v; has1 = true; emit(); }, onError: controller.addError);
  final sub2 = s2.listen((v) { v2 = v; has2 = true; emit(); }, onError: controller.addError);
  final sub3 = s3.listen((v) { v3 = v; has3 = true; emit(); }, onError: controller.addError);
  final sub4 = s4.listen((v) { v4 = v; has4 = true; emit(); }, onError: controller.addError);

  controller.onCancel = () async {
    await sub1.cancel();
    await sub2.cancel();
    await sub3.cancel();
    await sub4.cancel();
  };

  return controller.stream;
}

Stream<R> combineLatest2<T1, T2, R>(
  Stream<T1> s1,
  Stream<T2> s2,
  R Function(T1, T2) combiner,
) {
  final controller = StreamController<R>.broadcast();
  T1? v1;
  T2? v2;
  bool has1 = false, has2 = false;

  void emit() {
    if (has1 && has2) {
      if (!controller.isClosed) {
        controller.add(combiner(v1 as T1, v2 as T2));
      }
    }
  }

  final sub1 = s1.listen((v) { v1 = v; has1 = true; emit(); }, onError: controller.addError);
  final sub2 = s2.listen((v) { v2 = v; has2 = true; emit(); }, onError: controller.addError);

  controller.onCancel = () async {
    await sub1.cancel();
    await sub2.cancel();
  };

  return controller.stream;
}

class RoleHomeScreen extends StatefulWidget {
  const RoleHomeScreen({super.key, required this.role});

  final UserRole role;

  @override
  State<RoleHomeScreen> createState() => _RoleHomeScreenState();
}

class _RoleHomeScreenState extends State<RoleHomeScreen> {
  Stream<MemberDashboardStats>? _memberStatsStream;
  Stream<int>? _teamMembersStream;
  Stream<int>? _teamTodayAttendanceStream;
  Stream<int>? _activeSessionsStream;
  Future<String>? _teamNameFuture;
  String? _lastOrgId;
  String? _lastTeamId;

  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Stream<int> _watchTeamTodayAttendance(String orgId, String teamId) {
    final todayStr = _todayDateString();
    
    final usersStream = FirebaseFirestore.instance
        .collection('users')
        .where('organizationId', isEqualTo: orgId)
        .where('teamId', isEqualTo: teamId)
        .snapshots();

    final recordsStream = FirebaseFirestore.instance
        .collection('attendanceRecords')
        .where('organizationId', isEqualTo: orgId)
        .where('date', isEqualTo: todayStr)
        .snapshots();

    return combineLatest2<QuerySnapshot<Map<String, dynamic>>, QuerySnapshot<Map<String, dynamic>>, int>(
      usersStream,
      recordsStream,
      (usersSnap, recordsSnap) {
        final teamUserIds = usersSnap.docs.map((doc) => doc.id).toSet();
        final presentTeamCount = recordsSnap.docs
            .where((doc) => teamUserIds.contains(doc.data()['userId']))
            .length;
        return presentTeamCount;
      },
    );
  }

  Stream<MemberDashboardStats> _watchMemberStats(String orgId, String userId) {
    final todayStr = _todayDateString();

    final presentStream = FirebaseFirestore.instance
        .collection('attendanceRecords')
        .where('organizationId', isEqualTo: orgId)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((s) => s.docs.length);

    final sessionsStream = FirebaseFirestore.instance
        .collection('attendanceSessions')
        .where('organizationId', isEqualTo: orgId)
        .snapshots()
        .map((s) => s.docs.length);

    final todayRecordStream = FirebaseFirestore.instance
        .collection('attendanceRecords')
        .where('organizationId', isEqualTo: orgId)
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: todayStr)
        .snapshots()
        .map((s) => s.docs.isNotEmpty);

    final activeSessionsStream = FirebaseFirestore.instance
        .collection('attendanceSessions')
        .where('organizationId', isEqualTo: orgId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((s) => s.docs.isNotEmpty);

    return combineLatest4<int, int, bool, bool, MemberDashboardStats>(
      presentStream,
      sessionsStream,
      todayRecordStream,
      activeSessionsStream,
      (p, s, r, a) => MemberDashboardStats(
        presentCount: p,
        totalSessions: s,
        markedToday: r,
        hasActiveSessionToday: a,
      ),
    );
  }

  Future<String> _fetchTeamName(String orgId, String? teamId, OrganizationType orgType) async {
    if (teamId == null || teamId.isEmpty) {
      return 'Not Assigned';
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .collection('teams')
          .doc(teamId)
          .get();
      if (doc.exists && doc.data() != null) {
        final config = OrganizationConfigRegistry.of(orgType);
        return doc.data()!['name'] as String? ?? 'Unnamed ${config.teamLabel}';
      }
    } catch (_) {}
    return 'Not Assigned';
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

    final orgType = user.organizationType;
    final config = OrganizationConfigRegistry.of(orgType);
    final roleLabel = config.roleLabel(widget.role);

    // Dynamic setups for streams
    if (_lastOrgId != user.organizationId || _lastTeamId != user.teamId) {
      _lastOrgId = user.organizationId;
      _lastTeamId = user.teamId;

      _teamNameFuture = _fetchTeamName(user.organizationId, user.teamId, orgType);

      if (widget.role == UserRole.member) {
        _memberStatsStream = _watchMemberStats(user.organizationId, user.id);
      } else if (widget.role == UserRole.teacherManager) {
        if (user.teamId != null && user.teamId!.isNotEmpty) {
          _teamMembersStream = FirebaseFirestore.instance
              .collection('users')
              .where('organizationId', isEqualTo: user.organizationId)
              .where('teamId', isEqualTo: user.teamId)
              .where('role', isEqualTo: UserRole.member.value)
              .where('isActive', isEqualTo: true)
              .snapshots()
              .map((s) => s.docs.length);

          _teamTodayAttendanceStream = _watchTeamTodayAttendance(user.organizationId, user.teamId!);
        }
        _activeSessionsStream = FirebaseFirestore.instance
            .collection('attendanceSessions')
            .where('organizationId', isEqualTo: user.organizationId)
            .where('status', isEqualTo: 'active')
            .snapshots()
            .map((s) => s.docs.length);
      }
    }

    // Dynamic Accents
    final theme = Theme.of(context);
    final primaryGradientColor = config.primaryColor;
    final secondaryGradientColor = config.secondaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Text('$roleLabel Workspace'),
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
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(20.w),
          children: [
            // Welcome Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(22.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.r),
                gradient: LinearGradient(
                  colors: [primaryGradientColor, secondaryGradientColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                  color: primaryGradientColor.withValues(alpha: 0.28),
                    blurRadius: 12.r,
                    offset: const Offset(0, 6),
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
                          'Welcome back,',
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                        ),
                        Text(
                          user.name,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '${user.organizationName} • $roleLabel',
                          style: theme.textTheme.labelMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    switch (widget.role) {
                      UserRole.receptionist => Icons.support_agent_rounded,
                      UserRole.teacherManager => Icons.co_present_rounded,
                      UserRole.member => Icons.badge_rounded,
                      UserRole.admin => Icons.admin_panel_settings_rounded,
                    },
                    color: Colors.white,
                    size: 38.w,
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0),
            SizedBox(height: 24.h),

            // Statistics Grid based on Category & Role
            Text(
              'Your Dashboard Summary',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12.h),
             _buildRoleStatsSection(orgType, user),
            SizedBox(height: 24.h),

            // Quick Actions List
            Text(
              'Quick Workflows',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12.h),
            _buildQuickActionsGrid(orgType),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleStatsSection(OrganizationType orgType, AppUser user) {
    final config = OrganizationConfigRegistry.of(orgType);
    if (widget.role == UserRole.member) {
      return StreamBuilder<MemberDashboardStats>(
        stream: _memberStatsStream,
        builder: (context, snapshot) {
          final stats = snapshot.data ?? const MemberDashboardStats();

          // Calculate Dynamic Attendance Ratio
          final percent = stats.totalSessions == 0
              ? 0.0
              : (stats.presentCount / stats.totalSessions * 100).clamp(0, 100);

          // Today Status Color & String
          final todayStatusText = stats.markedToday
              ? 'Present'
              : (stats.hasActiveSessionToday ? 'Attendance Pending' : 'No Active Session');
          final todayStatusColor = stats.markedToday
              ? AppColors.success
              : (stats.hasActiveSessionToday ? Colors.amber : Colors.grey);
          final todayStatusIcon = stats.markedToday
              ? Icons.check_circle_rounded
              : (stats.hasActiveSessionToday ? Icons.qr_code_scanner_rounded : Icons.offline_pin_rounded);

          final absentDays = stats.totalSessions - stats.presentCount;

          return FutureBuilder<String>(
            future: _teamNameFuture,
            builder: (context, teamSnap) {
              final teamName = teamSnap.data ?? 'Loading...';

              if (orgType == OrganizationType.school) {
                // Student: Attendance Percentage, Present Days, Absent Days, Today's Status
                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12.w,
                  mainAxisSpacing: 12.h,
                  childAspectRatio: 1.35,
                  children: [
                    _buildMetricCard("Attendance Rate", '${percent.toStringAsFixed(1)}%', Icons.query_stats_rounded, color: config.primaryColor),
                    _buildMetricCard("Present Days", '${stats.presentCount} Days', Icons.event_available_rounded),
                    _buildMetricCard("Absent Days", '${absentDays < 0 ? 0 : absentDays} Days', Icons.event_busy_rounded, color: Colors.redAccent),
                    _buildMetricCard("Today's Status", todayStatusText, todayStatusIcon, color: todayStatusColor),
                  ],
                );
              } else if (orgType == OrganizationType.corporate) {
                // Employee: Attendance Percentage, Working Days, Current Status
                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12.w,
                  mainAxisSpacing: 12.h,
                  childAspectRatio: 1.35,
                  children: [
                    _buildMetricCard("Attendance Rate", '${percent.toStringAsFixed(1)}%', Icons.query_stats_rounded, color: config.primaryColor),
                    _buildMetricCard("Working Days", '${stats.presentCount} Days', Icons.event_available_rounded),
                    _buildMetricCard("Current Status", todayStatusText, todayStatusIcon, color: todayStatusColor),
                  ],
                );
              } else {
                // Worker: Attendance Percentage, Present Days, Shift Details
                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12.w,
                  mainAxisSpacing: 12.h,
                  childAspectRatio: 1.35,
                  children: [
                    _buildMetricCard("Attendance Rate", '${percent.toStringAsFixed(1)}%', Icons.query_stats_rounded, color: config.primaryColor),
                    _buildMetricCard("Present Days", '${stats.presentCount} Days', Icons.event_available_rounded),
                    _buildMetricCard("${config.teamLabel} Details", teamName, Icons.grid_view_rounded),
                  ],
                );
              }
            },
          );
        },
      ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
    } else if (widget.role == UserRole.teacherManager) {
      return FutureBuilder<String>(
        future: _teamNameFuture,
        builder: (context, teamSnap) {
          final teamName = teamSnap.data ?? 'Loading...';

          return StreamBuilder<int>(
            stream: _teamMembersStream,
            builder: (context, teamMembersSnap) {
              final teamMembersCount = teamMembersSnap.data ?? 0;

              return StreamBuilder<int>(
                stream: _activeSessionsStream,
                builder: (context, activeSessionsSnap) {
                  final activeSessionsCount = activeSessionsSnap.data ?? 0;

                  return StreamBuilder<int>(
                    stream: _teamTodayAttendanceStream,
                    builder: (context, teamAttendanceSnap) {
                      final teamAttendanceCount = teamAttendanceSnap.data ?? 0;
                      final teamAttendanceRate = teamMembersCount == 0
                          ? 0.0
                          : (teamAttendanceCount / teamMembersCount * 100);

                      if (orgType == OrganizationType.school) {
                        // Teacher: Assigned Classes, Today's Schedule, Attendance Statistics
                        return GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12.w,
                          mainAxisSpacing: 12.h,
                          childAspectRatio: 1.35,
                          children: [
                            _buildMetricCard("Assigned Class", teamName, Icons.class_rounded, color: config.primaryColor),
                            _buildMetricCard("Today's Schedule", "Mon-Fri: 9am-3pm", Icons.schedule_rounded),
                            _buildMetricCard("Attendance Stats", '${teamAttendanceRate.toStringAsFixed(1)}% present today', Icons.insights_rounded),
                          ],
                        );
                      } else if (orgType == OrganizationType.corporate) {
                        // Manager: Team Members, Team Attendance, Active Sessions
                        return GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12.w,
                          mainAxisSpacing: 12.h,
                          childAspectRatio: 1.35,
                          children: [
                            _buildMetricCard("Team Members", '$teamMembersCount', Icons.groups_rounded, color: config.primaryColor),
                            _buildMetricCard("Team Attendance", '${teamAttendanceRate.toStringAsFixed(1)}% today', Icons.insights_rounded),
                            _buildMetricCard("Active Sessions", '$activeSessionsCount', Icons.sensors_rounded),
                          ],
                        );
                      } else {
                        // Supervisor: Assigned Workers, Shift Attendance, Active Shift Status
                        final activeShiftStatus = activeSessionsCount > 0 ? "Shift Active" : "No Active Shift";
                        return GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12.w,
                          mainAxisSpacing: 12.h,
                          childAspectRatio: 1.35,
                          children: [
                            _buildMetricCard("Assigned Workers", '$teamMembersCount registered', Icons.engineering_rounded, color: config.primaryColor),
                            _buildMetricCard("Shift Attendance", '$teamAttendanceCount Checked-in', Icons.event_available_rounded),
                            _buildMetricCard("Active Shift Status", activeShiftStatus, Icons.pending_actions_rounded, color: activeSessionsCount > 0 ? AppColors.success : null),
                          ],
                        );
                      }
                    },
                  );
                },
              );
            },
          );
        },
      ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
    } else if (widget.role == UserRole.receptionist) {
      // Receptionist Dashboard stats: simple calendar date card + active sessions running count
      return StreamBuilder<int>(
        stream: _activeSessionsStream,
        builder: (context, activeSessionsSnap) {
          final activeSessionsCount = activeSessionsSnap.data ?? 0;
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 12.h,
            childAspectRatio: 1.35,
            children: [
              _buildMetricCard("Today's Date", _todayDateString(), Icons.calendar_month_rounded, color: config.primaryColor),
              _buildMetricCard("Active Attendance QR", '$activeSessionsCount running', Icons.qr_code_scanner_rounded, color: activeSessionsCount > 0 ? AppColors.success : null),
            ],
          );
        },
      ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
    }

    return const SizedBox();
  }

  Widget _buildMetricCard(String title, String value, IconData icon, {Color? color}) {
    final theme = Theme.of(context);
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 24.w, color: color ?? theme.colorScheme.primary),
              Container(
                width: 6.w,
                height: 6.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color ?? theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 2.h),
              Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(OrganizationType orgType) {
    final category = orgType.category;
    final features = switch (widget.role) {
      UserRole.receptionist => [
          _RoleFeature(
            'Register ${category.memberLabel}',
            Icons.person_add_alt_1_rounded,
            '${AppRouter.createUser}?role=${UserRole.member.value}',
          ),
          _RoleFeature(
            'Start Attendance QR',
            Icons.qr_code_2_rounded,
            AppRouter.attendance,
          ),
          _RoleFeature(
            'Generate Reports',
            Icons.picture_as_pdf_rounded,
            AppRouter.reports,
          ),
          _RoleFeature(
            'View Analytics',
            Icons.query_stats_rounded,
            AppRouter.analytics,
          ),
          _RoleFeature(
            'My Profile',
            Icons.account_circle_rounded,
            AppRouter.profile,
          ),
        ],
      UserRole.teacherManager => switch (category) {
          OrganizationCategory.education => [
              _RoleFeature(
                'Start Attendance',
                Icons.qr_code_2_rounded,
                AppRouter.attendance,
              ),
              _RoleFeature(
                'View ${category.memberPlural}',
                Icons.groups_rounded,
                AppRouter.users,
              ),
              _RoleFeature(
                'View Reports',
                Icons.picture_as_pdf_rounded,
                AppRouter.reports,
              ),
              _RoleFeature(
                'My Profile',
                Icons.account_circle_rounded,
                AppRouter.profile,
              ),
            ],
          OrganizationCategory.corporate => [
              _RoleFeature(
                'Start Attendance',
                Icons.qr_code_2_rounded,
                AppRouter.attendance,
              ),
              _RoleFeature(
                'Team Reports',
                Icons.picture_as_pdf_rounded,
                AppRouter.reports,
              ),
              _RoleFeature(
                'Team Analytics',
                Icons.query_stats_rounded,
                AppRouter.analytics,
              ),
              _RoleFeature(
                'My Profile',
                Icons.account_circle_rounded,
                AppRouter.profile,
              ),
            ],
          OrganizationCategory.industrial ||
          OrganizationCategory.medical ||
          OrganizationCategory.commercial ||
          OrganizationCategory.logistics => [
              _RoleFeature(
                'Start Attendance',
                Icons.qr_code_2_rounded,
                AppRouter.attendance,
              ),
              _RoleFeature(
                'Verify Attendance',
                Icons.qr_code_scanner_rounded,
                AppRouter.scanner,
              ),
              _RoleFeature(
                'Reports',
                Icons.picture_as_pdf_rounded,
                AppRouter.reports,
              ),
              _RoleFeature(
                'My Profile',
                Icons.account_circle_rounded,
                AppRouter.profile,
              ),
            ],
        },
      UserRole.member => [
          _RoleFeature(
            'Mark Attendance',
            Icons.qr_code_scanner_rounded,
            AppRouter.scanner,
          ),
          _RoleFeature(
            'Attendance History',
            Icons.query_stats_rounded,
            AppRouter.analytics,
          ),
          _RoleFeature(
            'My Profile',
            Icons.account_circle_rounded,
            AppRouter.profile,
          ),
        ],
      UserRole.admin => [
          _RoleFeature(
            'Admin Dashboard',
            Icons.admin_panel_settings_rounded,
            AppRouter.adminDashboard,
          ),
          _RoleFeature(
            'My Profile',
            Icons.account_circle_rounded,
            AppRouter.profile,
          ),
        ],
    };

    return GridView.builder(
      itemCount: features.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 3 : 1,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
        mainAxisExtent: 72.h,
      ),
      itemBuilder: (context, index) {
        final feature = features[index];
        return PremiumCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(feature.icon, color: Theme.of(context).colorScheme.primary),
            title: Text(feature.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: feature.route == null ? null : () => context.push(feature.route!),
          ),
        );
      },
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

}

class _RoleFeature {
  const _RoleFeature(this.title, this.icon, this.route);

  final String title;
  final IconData icon;
  final String? route;
}
