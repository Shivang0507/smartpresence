import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../enums/organization_type.dart';
import '../theme/app_colors.dart';
import '../widgets/premium_card.dart';

class AdminStats {
  final int totalMembers;
  final int totalStaff;
  final int totalDepartments;
  final int totalTeams;
  final int totalSubjects;
  final int presentTodayCount;

  const AdminStats({
    this.totalMembers = 0,
    this.totalStaff = 0,
    this.totalDepartments = 0,
    this.totalTeams = 0,
    this.totalSubjects = 0,
    this.presentTodayCount = 0,
  });
}

abstract class DashboardWidget {
  String get id;
  Widget buildWidget(BuildContext context, AdminStats stats, double attendanceRate, OrganizationType orgType, String orgId);
}

class StatsGridWidget implements DashboardWidget {
  @override
  String get id => 'stats_grid';

  @override
  Widget buildWidget(BuildContext context, AdminStats stats, double attendanceRate, OrganizationType orgType, String orgId) {
    final theme = Theme.of(context);
    final items = _getKPIs(context, orgType, stats, attendanceRate);

    return GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 3 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12.w,
      mainAxisSpacing: 12.h,
      childAspectRatio: 1.35,
      children: items.map((kpi) {
        return PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    kpi.icon,
                    size: 24.w,
                    color: kpi.color ?? theme.colorScheme.primary,
                  ),
                  Container(
                    width: 6.w,
                    height: 6.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kpi.color ?? theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kpi.value,
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    kpi.title,
                    style: theme.textTheme.labelMedium?.copyWith(
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
      }).toList(),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  List<_KPIData> _getKPIs(BuildContext context, OrganizationType orgType, AdminStats stats, double attendanceRate) {
    return switch (orgType) {
      OrganizationType.school => [
          _KPIData('Total Students', '${stats.totalMembers}', Icons.face_rounded),
          _KPIData('Total Teachers', '${stats.totalStaff}', Icons.school_rounded),
          _KPIData("Today's Attendance", '${attendanceRate.toStringAsFixed(1)}%', Icons.fact_check_rounded, color: AppColors.success),
          _KPIData('Subjects', '${stats.totalSubjects}', Icons.auto_stories_rounded),
          _KPIData('Classes', '${stats.totalTeams}', Icons.class_rounded),
        ],
      OrganizationType.hospital => [
          _KPIData('Doctors On Duty', '${stats.totalStaff}', Icons.medical_services_rounded),
          _KPIData('Nurses & Staff', '${stats.totalMembers}', Icons.people_outline_rounded),
          _KPIData("Attendance Today", '${attendanceRate.toStringAsFixed(1)}%', Icons.check_circle_rounded, color: AppColors.success),
          _KPIData('Wards / Units', '${stats.totalTeams}', Icons.local_hospital_rounded),
          _KPIData('Medical Depts', '${stats.totalDepartments}', Icons.business_center_rounded),
        ],
      OrganizationType.factory => [
          _KPIData('Workers Present', '${stats.presentTodayCount}', Icons.engineering_rounded, color: AppColors.success),
          _KPIData('Running Shifts', '${stats.totalSubjects > 0 ? stats.totalSubjects : 3}', Icons.pending_actions_rounded),
          _KPIData('Total Workers', '${stats.totalMembers}', Icons.groups_rounded),
          _KPIData('Production Lines', '${stats.totalTeams}', Icons.view_quilt_rounded),
          _KPIData('Attendance Rate', '${attendanceRate.toStringAsFixed(1)}%', Icons.insights_rounded),
        ],
      OrganizationType.retail => [
          _KPIData('Staff Present', '${stats.presentTodayCount}', Icons.people_rounded, color: AppColors.success),
          _KPIData('Store Branches', '${stats.totalDepartments}', Icons.store_rounded),
          _KPIData('Shifts & Teams', '${stats.totalTeams}', Icons.grid_view_rounded),
          _KPIData('Attendance %', '${attendanceRate.toStringAsFixed(1)}%', Icons.verified_rounded),
        ],
      OrganizationType.warehouse => [
          _KPIData('Workers Present', '${stats.presentTodayCount}', Icons.badge_rounded, color: AppColors.success),
          _KPIData('Active Shifts', '${stats.totalSubjects > 0 ? stats.totalSubjects : 2}', Icons.schedule_rounded),
          _KPIData('Dispatch Crews', '${stats.totalTeams}', Icons.local_shipping_rounded),
          _KPIData('Warehouse Zones', '${stats.totalDepartments}', Icons.warehouse_rounded),
          _KPIData('Attendance %', '${attendanceRate.toStringAsFixed(1)}%', Icons.verified_user_rounded),
        ],
      OrganizationType.corporate => [
          _KPIData('Total Employees', '${stats.totalMembers}', Icons.people_outline_rounded),
          _KPIData('Departments', '${stats.totalDepartments}', Icons.account_tree_rounded),
          _KPIData('Active Teams', '${stats.totalTeams}', Icons.grid_view_rounded),
          _KPIData('Attendance Today', '${attendanceRate.toStringAsFixed(1)}%', Icons.verified_rounded, color: AppColors.success),
        ],
    };
  }
}

class _KPIData {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;

  const _KPIData(this.title, this.value, this.icon, {this.color});
}

class QuickActionsGridWidget implements DashboardWidget {
  @override
  String get id => 'quick_actions_grid';

  @override
  Widget buildWidget(BuildContext context, AdminStats stats, double attendanceRate, OrganizationType orgType, String orgId) {
    final actions = _getActions(context, orgType, orgId);

    return GridView.builder(
      itemCount: actions.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
        childAspectRatio: 1.5,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];
        return PremiumCard(
          onTap: action.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                action.icon,
                size: 26.w,
                color: Theme.of(context).colorScheme.primary,
              ),
              Text(
                action.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  List<_ActionData> _getActions(BuildContext context, OrganizationType orgType, String orgId) {
    return switch (orgType) {
      OrganizationType.school => [
          _ActionData(
            'Add Student',
            Icons.person_add_alt_1_rounded,
            () => context.push('/users/create?role=MEMBER'),
          ),
          _ActionData(
            'Add Teacher',
            Icons.group_add_rounded,
            () => context.push('/users/create?role=TEACHER_MANAGER'),
          ),
          _ActionData(
            'Add Class',
            Icons.add_location_alt_rounded,
            () => context.push('/admin/teams'),
          ),
          _ActionData(
            'Add Subject',
            Icons.library_add_rounded,
            () => _showAddSubjectDialog(context, orgId),
          ),
          _ActionData(
            'View Reports',
            Icons.analytics_rounded,
            () => context.push('/reports'),
          ),
          _ActionData(
            'Analytics Dashboard',
            Icons.query_stats_rounded,
            () => context.push('/analytics'),
          ),
        ],
      OrganizationType.hospital => [
          _ActionData(
            'Add Staff / Nurse',
            Icons.person_add_alt_1_rounded,
            () => context.push('/users/create?role=MEMBER'),
          ),
          _ActionData(
            'Add Doctor',
            Icons.group_add_rounded,
            () => context.push('/users/create?role=TEACHER_MANAGER'),
          ),
          _ActionData(
            'Manage Wards',
            Icons.add_home_work_rounded,
            () => context.push('/admin/teams'),
          ),
          _ActionData(
            'Duty Rosters',
            Icons.schedule_rounded,
            () => context.push('/admin/shifts'),
          ),
          _ActionData(
            'Medical Reports',
            Icons.picture_as_pdf_rounded,
            () => context.push('/reports'),
          ),
          _ActionData(
            'Roster Analytics',
            Icons.query_stats_rounded,
            () => context.push('/analytics'),
          ),
        ],
      OrganizationType.factory => [
          _ActionData(
            'Add Worker',
            Icons.person_add_alt_1_rounded,
            () => context.push('/users/create?role=MEMBER'),
          ),
          _ActionData(
            'Add Supervisor',
            Icons.group_add_rounded,
            () => context.push('/users/create?role=TEACHER_MANAGER'),
          ),
          _ActionData(
            'Production Lines',
            Icons.diversity_3_rounded,
            () => context.push('/admin/teams'),
          ),
          _ActionData(
            'Manage Shifts',
            Icons.schedule_rounded,
            () => context.push('/admin/shifts'),
          ),
          _ActionData(
            'Shift Reports',
            Icons.picture_as_pdf_rounded,
            () => context.push('/reports'),
          ),
          _ActionData(
            'Production Analytics',
            Icons.query_stats_rounded,
            () => context.push('/analytics'),
          ),
        ],
      OrganizationType.retail => [
          _ActionData(
            'Add Associate',
            Icons.person_add_alt_1_rounded,
            () => context.push('/users/create?role=MEMBER'),
          ),
          _ActionData(
            'Add Store Manager',
            Icons.group_add_rounded,
            () => context.push('/users/create?role=TEACHER_MANAGER'),
          ),
          _ActionData(
            'Store Branches',
            Icons.store_rounded,
            () => context.push('/admin/departments'),
          ),
          _ActionData(
            'Shift Management',
            Icons.schedule_rounded,
            () => context.push('/admin/shifts'),
          ),
          _ActionData(
            'Branch Reports',
            Icons.picture_as_pdf_rounded,
            () => context.push('/reports'),
          ),
          _ActionData(
            'Sales Performance',
            Icons.query_stats_rounded,
            () => context.push('/analytics'),
          ),
        ],
      OrganizationType.warehouse => [
          _ActionData(
            'Add Worker / Loader',
            Icons.person_add_alt_1_rounded,
            () => context.push('/users/create?role=MEMBER'),
          ),
          _ActionData(
            'Add Zone Supervisor',
            Icons.group_add_rounded,
            () => context.push('/users/create?role=TEACHER_MANAGER'),
          ),
          _ActionData(
            'Dispatch Crews',
            Icons.diversity_3_rounded,
            () => context.push('/admin/teams'),
          ),
          _ActionData(
            'Shift Roster',
            Icons.schedule_rounded,
            () => context.push('/admin/shifts'),
          ),
          _ActionData(
            'Loading Reports',
            Icons.picture_as_pdf_rounded,
            () => context.push('/reports'),
          ),
          _ActionData(
            'Logistics Analytics',
            Icons.query_stats_rounded,
            () => context.push('/analytics'),
          ),
        ],
      OrganizationType.corporate => [
          _ActionData(
            'Add Employee',
            Icons.person_add_alt_1_rounded,
            () => context.push('/users/create?role=MEMBER'),
          ),
          _ActionData(
            'Add Manager',
            Icons.group_add_rounded,
            () => context.push('/users/create?role=TEACHER_MANAGER'),
          ),
          _ActionData(
            'Manage Departments',
            Icons.account_tree_rounded,
            () => context.push('/admin/departments'),
          ),
          _ActionData(
            'Manage Teams',
            Icons.diversity_3_rounded,
            () => context.push('/admin/teams'),
          ),
          _ActionData(
            'View Reports',
            Icons.picture_as_pdf_rounded,
            () => context.push('/reports'),
          ),
          _ActionData(
            'System Analytics',
            Icons.query_stats_rounded,
            () => context.push('/analytics'),
          ),
        ],
    };
  }

  void _showAddSubjectDialog(BuildContext context, String orgId) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Subject'),
        content: TextFormField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Subject Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(context).pop();
                try {
                  await FirebaseFirestore.instance
                      .collection('organizations')
                      .doc(orgId)
                      .collection('subjects')
                      .add({
                    'name': name,
                    'isActive': true,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Subject "$name" created successfully.')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to create subject: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Add'),
          )
        ],
      ),
    );
  }
}
class _ActionData {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionData(this.title, this.icon, this.onTap);
}
