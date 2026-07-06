import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/premium_card.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/data/app_user.dart';
import '../../data/models/shift_assignment_model.dart';
import '../../data/models/shift_model.dart';
import '../../data/repositories/shift_repository.dart';
import 'shift_details_screen.dart';
import 'employee_assignment_screen.dart';

class ManageShiftsScreen extends StatefulWidget {
  const ManageShiftsScreen({super.key});

  @override
  State<ManageShiftsScreen> createState() => _ManageShiftsScreenState();
}

class _ManageShiftsScreenState extends State<ManageShiftsScreen> {
  final _repository = ShiftRepository();
  final _searchController = TextEditingController();
  
  String _searchQuery = '';
  String _statusFilter = 'All'; // All, Active, Inactive, Draft
  String _timeFilter = 'All'; // All, Morning, Evening, Night, General
  String _rotationFilter = 'All'; // All, Rotating, Fixed
  String _sortBy = 'Name'; // Name, Start Time, Employees
  bool _isGridView = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthBloc>().state.user;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('User details not loaded.')),
      );
    }
    final orgId = user.organizationId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Shifts'),
        actions: [
          IconButton(
            tooltip: _isGridView ? 'Timeline View' : 'Grid View',
            onPressed: () => setState(() => _isGridView = !_isGridView),
            icon: Icon(_isGridView ? Icons.view_timeline_rounded : Icons.grid_view_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTemplateSelector(context, orgId, user.id, user.name),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Shift'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<Shift>>(
          stream: _repository.watchShifts(orgId),
          builder: (context, shiftsSnap) {
            if (shiftsSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (shiftsSnap.hasError) {
              return Center(child: Text('Error loading shifts: ${shiftsSnap.error}'));
            }

            final shifts = shiftsSnap.data ?? [];

            return StreamBuilder<List<AppUser>>(
              stream: _repository.watchUsers(orgId),
              builder: (context, usersSnap) {
                final users = usersSnap.data ?? [];
                
                // Analytics Calculations
                final totalShifts = shifts.length;
                final activeShifts = shifts.where((s) => s.status == ShiftStatus.active).length;
                final inactiveShifts = shifts.where((s) => s.status == ShiftStatus.inactive).length;
                final draftShifts = shifts.where((s) => s.status == ShiftStatus.draft).length;
                
                final assignedUsers = users.where((u) => u.shiftId != null && u.shiftId!.isNotEmpty).toList();
                final unassignedUsers = users.where((u) => u.shiftId == null || u.shiftId!.isEmpty).toList();
                final tempShiftUsers = users.where((u) => u.temporaryShiftId != null && u.temporaryShiftId!.isNotEmpty).toList();
                
                // Calculate Running Shifts (based on current time)
                final now = DateTime.now();
                final currentMinutes = now.hour * 60 + now.minute;
                final runningShifts = shifts.where((s) {
                  if (s.status != ShiftStatus.active) return false;
                  if (s.startMinutes <= s.endMinutes) {
                    return currentMinutes >= s.startMinutes && currentMinutes <= s.endMinutes;
                  } else {
                    return currentMinutes >= s.startMinutes || currentMinutes <= s.endMinutes;
                  }
                }).toList();

                // Capacity Utilization
                int maxCapacitySum = 0;
                for (final s in shifts) {
                  if (s.status == ShiftStatus.active && s.maxEmployees != null) {
                    maxCapacitySum += s.maxEmployees!;
                  }
                }
                final capacityUtil = maxCapacitySum == 0 
                    ? 0.0 
                    : (assignedUsers.length / maxCapacitySum * 100).clamp(0.0, 100.0);

                return RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  child: ListView(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                    children: [
                      // Dashboard Metrics Grid
                      _buildDashboardMetrics(
                        total: totalShifts,
                        active: activeShifts,
                        inactive: inactiveShifts,
                        draft: draftShifts,
                        running: runningShifts.length,
                        assigned: assignedUsers.length,
                        unassigned: unassignedUsers.length,
                        temporary: tempShiftUsers.length,
                        capacityUtil: capacityUtil,
                      ),
                      SizedBox(height: 24.h),

                      // Filters section
                      _buildSearchAndFilters(),
                      SizedBox(height: 16.h),

                      // List / Grid / Timeline representation
                      if (!_isGridView)
                        _buildTimelineView(shifts, users)
                      else if (shifts.isEmpty)
                        _buildEmptyState()
                      else
                        _buildShiftsGrid(shifts, users, orgId, user.id, user.name),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildDashboardMetrics({
    required int total,
    required int active,
    required int inactive,
    required int draft,
    required int running,
    required int assigned,
    required int unassigned,
    required int temporary,
    required double capacityUtil,
  }) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth > 800 ? 5 : (constraints.maxWidth > 550 ? 3 : 2);
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10.w,
        mainAxisSpacing: 10.h,
        childAspectRatio: 1.45,
        children: [
          _buildMetricCard('Total Shifts', '$total', Icons.dns_rounded, Colors.blue),
          _buildMetricCard('Active Shifts', '$active', Icons.task_alt_rounded, AppColors.success),
          _buildMetricCard('Draft / Inactive', '$draft / $inactive', Icons.lock_reset_rounded, Colors.amber),
          _buildMetricCard('Running Now', '$running', Icons.play_circle_outline_rounded, Colors.purple),
          _buildMetricCard('Assigned Employees', '$assigned', Icons.people_rounded, Colors.teal),
          _buildMetricCard('Without Shift', '$unassigned', Icons.person_off_rounded, Colors.redAccent),
          _buildMetricCard('Temporary Assignments', '$temporary', Icons.edit_calendar_rounded, Colors.indigo),
          _buildMetricCard('Capacity Util.', '${capacityUtil.toStringAsFixed(1)}%', Icons.pie_chart_rounded, Colors.orange),
        ],
      );
    });
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return PremiumCard(
      padding: EdgeInsets.all(12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 20.w, color: color),
              Container(
                width: 4.w,
                height: 4.w,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.3)),
              )
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 2.h),
              Text(
                title,
                style: TextStyle(fontSize: 10.sp, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return PremiumCard(
      padding: EdgeInsets.all(14.w),
      child: Column(
        children: [
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: const InputDecoration(
              labelText: 'Search by Shift Name or Code',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          SizedBox(height: 12.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterDropdown(
                  'Status',
                  _statusFilter,
                  ['All', 'Active', 'Inactive', 'Draft'],
                  (val) => setState(() => _statusFilter = val!),
                ),
                SizedBox(width: 8.w),
                _buildFilterDropdown(
                  'Timings',
                  _timeFilter,
                  ['All', 'Morning', 'Evening', 'Night', 'General'],
                  (val) => setState(() => _timeFilter = val!),
                ),
                SizedBox(width: 8.w),
                _buildFilterDropdown(
                  'Rotation',
                  _rotationFilter,
                  ['All', 'Rotating', 'Fixed'],
                  (val) => setState(() => _rotationFilter = val!),
                ),
                SizedBox(width: 8.w),
                _buildFilterDropdown(
                  'Sort By',
                  _sortBy,
                  ['Name', 'Start Time', 'Employees'],
                  (val) => setState(() => _sortBy = val!),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String currentValue,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold)),
          DropdownButton<String>(
            value: currentValue,
            underline: const SizedBox(),
            style: TextStyle(fontSize: 11.sp, color: Theme.of(context).colorScheme.onSurface),
            items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  List<Shift> _getFilteredShifts(List<Shift> rawShifts, List<AppUser> users) {
    var list = List<Shift>.from(rawShifts);

    // Apply Search
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((s) => s.name.toLowerCase().contains(q) || (s.code ?? '').toLowerCase().contains(q)).toList();
    }

    // Apply Status Filter
    if (_statusFilter != 'All') {
      final target = ShiftStatus.fromString(_statusFilter);
      list = list.where((s) => s.status == target).toList();
    }

    // Apply Timings Filter
    if (_timeFilter != 'All') {
      list = list.where((s) {
        final start = s.startMinutes;
        if (_timeFilter == 'Morning') return start >= 300 && start < 720; // 5:00 - 12:00
        if (_timeFilter == 'Evening') return start >= 720 && start < 1080; // 12:00 - 18:00
        if (_timeFilter == 'Night') return start >= 1080 || start < 300; // 18:00 - 5:00
        if (_timeFilter == 'General') return start >= 480 && start <= 570; // 8:00 - 9:30
        return true;
      }).toList();
    }

    // Apply Rotation Filter
    if (_rotationFilter != 'All') {
      final isRot = _rotationFilter == 'Rotating';
      list = list.where((s) => s.isRotating == isRot).toList();
    }

    // Apply Sorting
    if (_sortBy == 'Name') {
      list.sort((a, b) => a.name.compareTo(b.name));
    } else if (_sortBy == 'Start Time') {
      list.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    } else if (_sortBy == 'Employees') {
      int countFor(String id) => users.where((u) => u.shiftId == id).length;
      list.sort((a, b) => countFor(b.id).compareTo(countFor(a.id)));
    }

    return list;
  }

  Widget _buildShiftsGrid(
    List<Shift> rawShifts,
    List<AppUser> users,
    String orgId,
    String adminId,
    String adminName,
  ) {
    final filtered = _getFilteredShifts(rawShifts, users);

    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 12.w,
          mainAxisSpacing: 12.h,
          mainAxisExtent: 220.h,
        ),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final shift = filtered[index];
          final assignedCount = users.where((u) => u.shiftId == shift.id).length;
          return _buildShiftCard(shift, assignedCount, orgId, adminId, adminName);
        },
      );
    });
  }

  Widget _buildShiftCard(
    Shift shift,
    int employeeCount,
    String orgId,
    String adminId,
    String adminName,
  ) {
    final colorVal = int.tryParse(shift.color) ?? 0xFFD97706;
    final color = Color(colorVal);

    final statusColor = switch (shift.status) {
      ShiftStatus.active => AppColors.success,
      ShiftStatus.inactive => Colors.redAccent,
      ShiftStatus.draft => Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
      ShiftStatus.archived => Colors.blueGrey[200] ?? Colors.blueGrey,
    };

    // Capacity checks
    bool hasCapacityWarning = false;
    String capacityWarningText = '';
    if (shift.status == ShiftStatus.active) {
      if (shift.maxEmployees != null && employeeCount > shift.maxEmployees!) {
        hasCapacityWarning = true;
        capacityWarningText = 'Exceeds maximum capacity of ${shift.maxEmployees}';
      } else if (shift.minEmployees != null && employeeCount < shift.minEmployees!) {
        hasCapacityWarning = true;
        capacityWarningText = 'Below minimum capacity of ${shift.minEmployees}';
      }
    }

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 12.w,
                height: 36.h,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4.r)),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shift.name,
                      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (shift.code != null && shift.code!.isNotEmpty)
                      Text(
                        shift.code!,
                        style: TextStyle(fontSize: 10.sp, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)),
                      ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(100.r),
                ),
                child: Text(
                  shift.status.name.toUpperCase(),
                  style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.bold, color: statusColor),
                ),
              )
            ],
          ),

          // Working times row
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 14.w, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)),
                  SizedBox(width: 4.w),
                  Text(
                    '${ShiftTime.fromMinutes(shift.startMinutes).format24h()} - ${ShiftTime.fromMinutes(shift.endMinutes).format24h()}',
                    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 6.w),
                  if (shift.startMinutes > shift.endMinutes)
                    Text(
                      '(Overnight)',
                      style: TextStyle(fontSize: 10.sp, color: Colors.purple, fontWeight: FontWeight.bold),
                    )
                ],
              ),
              SizedBox(height: 4.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hours: ${shift.calculateWorkingHours()} hrs',
                    style: TextStyle(fontSize: 11.sp, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)),
                  ),
                  Text(
                    'Break: ${((shift.breakEndMinutes - shift.breakStartMinutes) % 1440)} mins',
                    style: TextStyle(fontSize: 11.sp, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)),
                  ),
                ],
              ),
              if (hasCapacityWarning) ...[
                SizedBox(height: 6.h),
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 12.w, color: Colors.orange),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        capacityWarningText,
                        style: TextStyle(fontSize: 10.sp, color: Colors.orange, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  ],
                ),
              ],
            ],
          ),

          // Footer info and action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$employeeCount Workers',
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (action) => _handleCardAction(action, shift, orgId, adminId, adminName),
                itemBuilder: (context) {
                  return [
                    const PopupMenuItem(value: 'view', child: Text('View Details')),
                    if (shift.status == ShiftStatus.draft)
                      const PopupMenuItem(value: 'publish', child: Text('Publish / Activate')),
                    if (shift.status == ShiftStatus.active) ...[
                      const PopupMenuItem(value: 'assign', child: Text('Assign Employees')),
                      const PopupMenuItem(value: 'deactivate', child: Text('Deactivate')),
                    ],
                    if (shift.status == ShiftStatus.inactive)
                      const PopupMenuItem(value: 'publish', child: Text('Activate')),
                    const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                    if (shift.status != ShiftStatus.archived && shift.status != ShiftStatus.draft)
                      const PopupMenuItem(value: 'archive', child: Text('Archive')),
                    if (shift.status == ShiftStatus.draft || shift.status == ShiftStatus.inactive)
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ];
                },
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTimelineView(List<Shift> rawShifts, List<AppUser> users) {
    final activeShifts = rawShifts.where((s) => s.status == ShiftStatus.active).toList();
    if (activeShifts.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.h),
          child: const Text('No active shifts available for timeline representation.'),
        ),
      );
    }

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline_rounded, size: 20.w, color: Theme.of(context).colorScheme.primary),
              SizedBox(width: 6.w),
              Text(
                'Shift Timeline Grid Coverage',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
              )
            ],
          ),
          SizedBox(height: 16.h),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activeShifts.length,
            separatorBuilder: (_, _) => SizedBox(height: 14.h),
            itemBuilder: (context, index) {
              final shift = activeShifts[index];
              final assignedCount = users.where((u) => u.shiftId == shift.id).length;
              final color = Color(int.tryParse(shift.color) ?? 0xFFD97706);

              // Check if running
              bool isRunning = false;
              if (shift.startMinutes <= shift.endMinutes) {
                isRunning = currentMinutes >= shift.startMinutes && currentMinutes <= shift.endMinutes;
              } else {
                isRunning = currentMinutes >= shift.startMinutes || currentMinutes <= shift.endMinutes;
              }

              // Simple cover bar alignment calculation
              final startPct = shift.startMinutes / 1440.0;
              final endPct = shift.endMinutes / 1440.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(width: 8.w, height: 8.w, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                          SizedBox(width: 6.w),
                          Text(shift.name, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold)),
                          SizedBox(width: 8.w),
                          if (isRunning)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(4.r)),
                              child: Text('RUNNING NOW', style: TextStyle(fontSize: 8.sp, color: AppColors.success, fontWeight: FontWeight.bold)),
                            )
                        ],
                      ),
                      Text('$assignedCount Workers Scheduled', style: TextStyle(fontSize: 11.sp, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55))),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Container(
                    width: double.infinity,
                    height: 14.h,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Stack(
                      children: [
                        LayoutBuilder(builder: (context, box) {
                          final totalWidth = box.maxWidth;
                          double left = startPct * totalWidth;
                          double width = 0.0;
                          
                          if (shift.startMinutes <= shift.endMinutes) {
                            width = (endPct - startPct) * totalWidth;
                          } else {
                            // Overnight spans two parts: start to 24h, and 00h to end
                            width = ((1.0 - startPct) + endPct) * totalWidth;
                            // For visualization simplify to a full block from start or overlay
                            left = startPct * totalWidth;
                            width = totalWidth - left + (endPct * totalWidth);
                            if (width > totalWidth) width = totalWidth;
                          }

                          return Positioned(
                            left: left.clamp(0, totalWidth),
                            width: width.clamp(4, totalWidth),
                            top: 0,
                            bottom: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: isRunning ? 0.8 : 0.4),
                                borderRadius: BorderRadius.circular(4.r),
                                border: isRunning ? Border.all(color: color, width: 1.5) : null,
                              ),
                            ),
                          );
                        })
                      ],
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Text(ShiftTime.fromMinutes(shift.startMinutes).format24h(), style: TextStyle(fontSize: 9.sp, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                      Text('12:00 PM', style: TextStyle(fontSize: 9.sp, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3))),
                      Text(ShiftTime.fromMinutes(shift.endMinutes).format24h(), style: TextStyle(fontSize: 9.sp, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                    ],
                  )
                ],
              );
            },
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 20.w),
        child: Column(
          children: [
            Icon(Icons.schedule_rounded, size: 48.w, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
            SizedBox(height: 12.h),
            Text(
              'No Shifts Configured',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6.h),
            Text(
              'Create a shift from templates to start managing factory schedules.',
              style: TextStyle(fontSize: 12.sp, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)),
              textAlign: TextAlign.center,
            )
          ],
        ),
      ),
    );
  }

  void _handleCardAction(
    String action,
    Shift shift,
    String orgId,
    String adminId,
    String adminName,
  ) async {
    if (action == 'view') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ShiftDetailsScreen(shiftId: shift.id),
        ),
      );
    } else if (action == 'assign') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EmployeeAssignmentScreen(shift: shift),
        ),
      );
    } else if (action == 'publish') {
      await _repository.activateShift(orgId, shift.id, adminId, adminName);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Shift "${shift.name}" published successfully.')));
    } else if (action == 'deactivate') {
      await _repository.deactivateShift(orgId, shift.id, adminId, adminName);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Shift "${shift.name}" deactivated.')));
    } else if (action == 'duplicate') {
      final copy = shift.copyWith(
        id: '',
        name: '${shift.name} (Copy)',
        code: shift.code != null ? '${shift.code}-COPY' : null,
        status: ShiftStatus.draft,
        version: 1,
      );
      await _repository.saveShift(orgId, copy, adminId, adminName, reason: 'Duplicated from ${shift.name}');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cloned "${shift.name}" as draft.')));
    } else if (action == 'archive') {
      try {
        await _repository.archiveShift(orgId, shift.id, adminId, adminName);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Shift archived.')));
      } catch (e) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Cannot Archive Shift'),
              content: Text(e.toString()),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
              ],
            ),
          );
        }
      }
    } else if (action == 'delete') {
      _showDeleteConfirmation(shift, orgId, adminId, adminName);
    }
  }

  void _showDeleteConfirmation(Shift shift, String orgId, String adminId, String adminName) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Delete Shift: ${shift.name}'),
          content: const Text('Are you sure you want to permanently delete this shift? This action is irreversible.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  await _repository.deleteShift(orgId, shift.id, adminId, adminName);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Shift deleted successfully.')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    _showReassignmentWarning(shift, orgId, adminId, adminName);
                  }
                }
              },
              child: const Text('Delete'),
            )
          ],
        );
      },
    );
  }

  void _showReassignmentWarning(Shift shift, String orgId, String adminId, String adminName) async {
    // Load other shifts to offer reassignment
    final allShifts = await _repository.watchShifts(orgId).first;
    final otherShifts = allShifts.where((s) => s.id != shift.id && s.status == ShiftStatus.active).toList();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        String selectedAction = otherShifts.isNotEmpty ? 'reassign' : 'unassign';
        String? targetShiftId = otherShifts.isNotEmpty ? otherShifts.first.id : null;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Employees Still Assigned'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cannot delete this shift because workers are currently assigned to it.'),
                  SizedBox(height: 14.h),
                  const Text('Please choose an action below:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8.h),
                  RadioGroup<String>(
                    groupValue: selectedAction,
                    onChanged: (val) => setDialogState(() => selectedAction = val!),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (otherShifts.isNotEmpty) ...[
                          const RadioListTile<String>(
                            title: Text('Reassign all employees to another shift'),
                            value: 'reassign',
                          ),
                          Padding(
                            padding: EdgeInsets.only(left: 32.w),
                            child: DropdownButton<String>(
                              value: targetShiftId,
                              items: otherShifts.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                              onChanged: selectedAction == 'reassign'
                                  ? (val) => setDialogState(() => targetShiftId = val)
                                  : null,
                            ),
                          ),
                        ],
                        const RadioListTile<String>(
                          title: Text('Unassign all employees (clear shift)'),
                          value: 'unassign',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    
                    // Fetch assigned user IDs
                    final usersList = await _repository.watchUsers(orgId).first;
                    final assignedEmpIds = usersList
                        .where((u) => u.shiftId == shift.id || u.temporaryShiftId == shift.id)
                        .map((u) => u.id)
                        .toList();

                    if (selectedAction == 'reassign' && targetShiftId != null) {
                      // Reassign all
                      await _repository.reassignEmployees(
                        orgId: orgId,
                        employeeIds: assignedEmpIds,
                        oldShiftId: shift.id,
                        newShiftId: targetShiftId!,
                        type: ShiftAssignmentType.permanent,
                        startDate: DateTime.now(),
                        adminId: adminId,
                        adminName: adminName,
                      );
                    } else {
                      // Unassign all
                      await _repository.bulkRemoveEmployees(
                        orgId: orgId,
                        employeeIds: assignedEmpIds,
                        shiftId: shift.id,
                        adminId: adminId,
                        adminName: adminName,
                      );
                    }

                    // Try delete again
                    await _repository.deleteShift(orgId, shift.id, adminId, adminName);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Shift removed successfully after reassignment.')),
                      );
                    }
                  },
                  child: const Text('Apply & Delete'),
                )
              ],
            );
          }
        );
      },
    );
  }

  void _showTemplateSelector(BuildContext context, String orgId, String adminId, String adminName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.8,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Choose Shift Template', style: Theme.of(context).textTheme.titleLarge),
                  SizedBox(height: 16.h),
                  _buildTemplateTile('General Shift', '09:00 AM - 05:00 PM • 1 hr Break', Icons.work_outline_rounded, () {
                    Navigator.of(context).pop();
                    _openShiftEditor(context, orgId, adminId, adminName, null, template: 'general');
                  }),
                  _buildTemplateTile('Morning Shift', '06:00 AM - 02:00 PM • 30 mins Break', Icons.wb_sunny_outlined, () {
                    Navigator.of(context).pop();
                    _openShiftEditor(context, orgId, adminId, adminName, null, template: 'morning');
                  }),
                  _buildTemplateTile('Evening Shift', '02:00 PM - 10:00 PM • 30 mins Break', Icons.brightness_medium_rounded, () {
                    Navigator.of(context).pop();
                    _openShiftEditor(context, orgId, adminId, adminName, null, template: 'evening');
                  }),
                  _buildTemplateTile('Night Shift', '10:00 PM - 06:00 AM • 30 mins Break • Overnight', Icons.nights_stay_rounded, () {
                    Navigator.of(context).pop();
                    _openShiftEditor(context, orgId, adminId, adminName, null, template: 'night');
                  }),
                  _buildTemplateTile('12-Hour Shift', '08:00 AM - 08:00 PM • 1 hr Break', Icons.timelapse_rounded, () {
                    Navigator.of(context).pop();
                    _openShiftEditor(context, orgId, adminId, adminName, null, template: '12hour');
                  }),
                  _buildTemplateTile('Rotating Shift', 'Flexible rotating schedule rules', Icons.autorenew_rounded, () {
                    Navigator.of(context).pop();
                    _openShiftEditor(context, orgId, adminId, adminName, null, template: 'rotating');
                  }),
                  _buildTemplateTile('Custom Blank Shift', 'Define timing rules from scratch', Icons.dashboard_customize_rounded, () {
                    Navigator.of(context).pop();
                    _openShiftEditor(context, orgId, adminId, adminName, null, template: 'custom');
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTemplateTile(String title, String desc, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(desc, style: TextStyle(fontSize: 11.sp, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55))),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  void _openShiftEditor(
    BuildContext context,
    String orgId,
    String adminId,
    String adminName,
    Shift? shift, {
    String? template,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _ShiftFormSheet(
          orgId: orgId,
          adminId: adminId,
          adminName: adminName,
          shift: shift,
          template: template,
          repository: _repository,
        );
      },
    );
  }
}

class _ShiftFormSheet extends StatefulWidget {
  final String orgId;
  final String adminId;
  final String adminName;
  final Shift? shift;
  final String? template;
  final ShiftRepository repository;

  const _ShiftFormSheet({
    required this.orgId,
    required this.adminId,
    required this.adminName,
    this.shift,
    this.template,
    required this.repository,
  });

  @override
  State<_ShiftFormSheet> createState() => _ShiftFormSheetState();
}

class _ShiftFormSheetState extends State<_ShiftFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _descController;
  
  ShiftStatus _status = ShiftStatus.draft;
  String _color = '0xFFD97706';
  
  // Timings
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  TimeOfDay _breakStartTime = const TimeOfDay(hour: 13, minute: 0);
  TimeOfDay _breakEndTime = const TimeOfDay(hour: 14, minute: 0);

  // Attendance configs
  int _graceTime = 10;
  int _lateEntry = 15;
  int _absentAfter = 60;
  int _halfDay = 240;
  double _minWorking = 8.0;
  bool _otAllowed = false;
  int _otStartsAfter = 30;
  double _maxOt = 4.0;
  bool _requireFace = false;
  bool _requireQr = false;
  
  List<int> _weeklyOffs = [7]; // Sunday default
  bool _isRotating = false;
  int _rotationFreq = 1;

  int? _minEmployees;
  int? _recEmployees;
  int? _maxEmployees;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _codeController = TextEditingController();
    _descController = TextEditingController();
    _applyTemplate();
  }

  void _applyTemplate() {
    if (widget.shift != null) {
      final s = widget.shift!;
      _nameController.text = s.name;
      _codeController.text = s.code ?? '';
      _descController.text = s.description;
      _status = s.status;
      _color = s.color;
      _startTime = _toTimeOfDay(s.startMinutes);
      _endTime = _toTimeOfDay(s.endMinutes);
      _breakStartTime = _toTimeOfDay(s.breakStartMinutes);
      _breakEndTime = _toTimeOfDay(s.breakEndMinutes);
      _graceTime = s.graceTime;
      _lateEntry = s.lateEntryThreshold;
      _absentAfter = s.absentAfterMinutes;
      _halfDay = s.halfDayThreshold;
      _minWorking = s.minWorkingHours;
      _otAllowed = s.overtimeAllowed;
      _otStartsAfter = s.overtimeStartsAfter;
      _maxOt = s.maxOvertimeHours;
      _requireFace = s.requireFaceVerification;
      _requireQr = s.requireQrVerification;
      _weeklyOffs = List<int>.from(s.weeklyOffs);
      _isRotating = s.isRotating;
      _rotationFreq = s.rotationFrequency;
      _minEmployees = s.minEmployees;
      _recEmployees = s.recEmployees;
      _maxEmployees = s.maxEmployees;
      return;
    }

    final t = widget.template;
    if (t == 'morning') {
      _nameController.text = 'Morning Shift';
      _codeController.text = 'SF-MOR';
      _color = '0xFF3B82F6'; // Blue
      _startTime = const TimeOfDay(hour: 6, minute: 0);
      _endTime = const TimeOfDay(hour: 14, minute: 0);
      _breakStartTime = const TimeOfDay(hour: 10, minute: 0);
      _breakEndTime = const TimeOfDay(hour: 10, minute: 30);
      _graceTime = 5;
    } else if (t == 'evening') {
      _nameController.text = 'Evening Shift';
      _codeController.text = 'SF-EVE';
      _color = '0xFF14B8A6'; // Teal
      _startTime = const TimeOfDay(hour: 14, minute: 0);
      _endTime = const TimeOfDay(hour: 22, minute: 0);
      _breakStartTime = const TimeOfDay(hour: 18, minute: 0);
      _breakEndTime = const TimeOfDay(hour: 18, minute: 30);
      _graceTime = 5;
    } else if (t == 'night') {
      _nameController.text = 'Night Shift';
      _codeController.text = 'SF-NGT';
      _color = '0xFF8B5CF6'; // Purple
      _startTime = const TimeOfDay(hour: 22, minute: 0);
      _endTime = const TimeOfDay(hour: 6, minute: 0);
      _breakStartTime = const TimeOfDay(hour: 2, minute: 0);
      _breakEndTime = const TimeOfDay(hour: 2, minute: 30);
      _graceTime = 5;
    } else if (t == '12hour') {
      _nameController.text = '12-Hour Shift';
      _codeController.text = 'SF-12H';
      _color = '0xFFEA580C'; // Dark Orange
      _startTime = const TimeOfDay(hour: 8, minute: 0);
      _endTime = const TimeOfDay(hour: 20, minute: 0);
      _breakStartTime = const TimeOfDay(hour: 13, minute: 0);
      _breakEndTime = const TimeOfDay(hour: 14, minute: 0);
      _minWorking = 11.0;
    } else if (t == 'rotating') {
      _nameController.text = 'Rotating Shift';
      _codeController.text = 'SF-ROT';
      _color = '0xFFEAB308'; // Yellow
      _isRotating = true;
    } else if (t == 'general') {
      _nameController.text = 'General Shift';
      _codeController.text = 'SF-GEN';
      _color = '0xFF0D9488'; // Teal
      _startTime = const TimeOfDay(hour: 9, minute: 0);
      _endTime = const TimeOfDay(hour: 17, minute: 0);
      _breakStartTime = const TimeOfDay(hour: 13, minute: 0);
      _breakEndTime = const TimeOfDay(hour: 14, minute: 0);
    }
  }

  TimeOfDay _toTimeOfDay(int minutes) {
    return TimeOfDay(hour: (minutes ~/ 60) % 24, minute: minutes % 60);
  }

  int _toMinutes(TimeOfDay tod) {
    return tod.hour * 60 + tod.minute;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.shift == null ? 'Add Shift' : 'Edit Shift';
    
    // Simulate timings on screen
    final workingHours = ((_toMinutes(_endTime) - _toMinutes(_startTime)) % 1440 - 
                          (_toMinutes(_breakEndTime) - _toMinutes(_breakStartTime)) % 1440) / 60.0;
    final workingHoursFormatted = workingHours.toStringAsFixed(2);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20.w,
          right: 20.w,
          top: 8.h,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20.h,
        ),
        child: Form(
          key: _formKey,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.8,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),

              // Basic details card
              Text('Basic Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
              SizedBox(height: 8.h),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Shift Name*'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
              ),
              SizedBox(height: 10.h),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'Shift Code (Optional)'),
              ),
              SizedBox(height: 10.h),
              TextFormField(
                controller: _descController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description / Notes'),
              ),
              SizedBox(height: 16.h),

              // Timings card picker
              Text('Timings Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
              SizedBox(height: 8.h),
              PremiumCard(
                padding: EdgeInsets.all(12.w),
                child: Column(
                  children: [
                    _buildTimePickerRow('Shift Start', _startTime, (val) => setState(() => _startTime = val)),
                    _buildTimePickerRow('Shift End', _endTime, (val) => setState(() => _endTime = val)),
                    _buildTimePickerRow('Break Start', _breakStartTime, (val) => setState(() => _breakStartTime = val)),
                    _buildTimePickerRow('Break End', _breakEndTime, (val) => setState(() => _breakEndTime = val)),
                    SizedBox(height: 10.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Calculated Work Hours:', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text('$workingHoursFormatted hrs', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      ],
                    )
                  ],
                ),
              ),
              SizedBox(height: 16.h),

              // Attendance threshold parameters
              Text('Attendance & Threshold Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
              SizedBox(height: 8.h),
              TextFormField(
                initialValue: _graceTime.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Grace Time (mins)'),
                onChanged: (val) => _graceTime = int.tryParse(val) ?? _graceTime,
              ),
              SizedBox(height: 10.h),
              TextFormField(
                initialValue: _lateEntry.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Late Threshold (mins)'),
                onChanged: (val) => _lateEntry = int.tryParse(val) ?? _lateEntry,
              ),
              SizedBox(height: 10.h),
              TextFormField(
                initialValue: _absentAfter.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Absent After Limit (mins)'),
                onChanged: (val) => _absentAfter = int.tryParse(val) ?? _absentAfter,
              ),
              SizedBox(height: 10.h),
              TextFormField(
                initialValue: _halfDay.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Half-Day Limit (mins)'),
                onChanged: (val) => _halfDay = int.tryParse(val) ?? _halfDay,
              ),
              SizedBox(height: 10.h),
              SwitchListTile(
                title: const Text('Overtime Allowed'),
                value: _otAllowed,
                onChanged: (val) => setState(() => _otAllowed = val),
              ),
              if (_otAllowed) ...[
                SizedBox(height: 10.h),
                TextFormField(
                  initialValue: _otStartsAfter.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'OT Starts After (mins)'),
                  onChanged: (val) => _otStartsAfter = int.tryParse(val) ?? _otStartsAfter,
                ),
                SizedBox(height: 10.h),
                TextFormField(
                  initialValue: _maxOt.toString(),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Max OT Hours Limit'),
                  onChanged: (val) => _maxOt = double.tryParse(val) ?? _maxOt,
                ),
              ],
              SizedBox(height: 16.h),

              // Verification requirements
              Text('Security Verification Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
              SwitchListTile(
                title: const Text('Require Face Biometrics'),
                value: _requireFace,
                onChanged: (val) => setState(() => _requireFace = val),
              ),
              SwitchListTile(
                title: const Text('Require QR Verification'),
                value: _requireQr,
                onChanged: (val) => setState(() => _requireQr = val),
              ),
              SizedBox(height: 16.h),

              // Target Capacity Warnings
              Text('Shift Target Capacity (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _minEmployees?.toString() ?? '',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Min Workers'),
                      onChanged: (val) => _minEmployees = int.tryParse(val),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: TextFormField(
                      initialValue: _recEmployees?.toString() ?? '',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Rec Workers'),
                      onChanged: (val) => _recEmployees = int.tryParse(val),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: TextFormField(
                      initialValue: _maxEmployees?.toString() ?? '',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Max Workers'),
                      onChanged: (val) => _maxEmployees = int.tryParse(val),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),

              // Save Actions
              FilledButton.icon(
                onPressed: _isSaving ? null : _saveShift,
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded),
                label: Text(_isSaving ? 'Saving Shift...' : 'Save Shift Settings'),
              ),
              SizedBox(height: 10.h),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildTimePickerRow(String label, TimeOfDay time, ValueChanged<TimeOfDay> onChanged) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: TextButton.icon(
        icon: const Icon(Icons.edit_calendar_rounded, size: 16),
        label: Text(time.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () async {
          final res = await showTimePicker(context: context, initialTime: time);
          if (res != null) onChanged(res);
        },
      ),
    );
  }

  void _saveShift() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Check break timing bounds
    final s = Shift(
      id: widget.shift?.id ?? '',
      organizationId: widget.orgId,
      name: _nameController.text.trim(),
      code: _codeController.text.trim().isEmpty ? null : _codeController.text.trim(),
      description: _descController.text.trim(),
      color: _color,
      status: _status,
      effectiveFrom: DateTime.now(),
      startMinutes: _toMinutes(_startTime),
      endMinutes: _toMinutes(_endTime),
      breakStartMinutes: _toMinutes(_breakStartTime),
      breakEndMinutes: _toMinutes(_breakEndTime),
      graceTime: _graceTime,
      lateEntryThreshold: _lateEntry,
      absentAfterMinutes: _absentAfter,
      halfDayThreshold: _halfDay,
      minWorkingHours: _minWorking,
      overtimeAllowed: _otAllowed,
      overtimeStartsAfter: _otStartsAfter,
      maxOvertimeHours: _maxOt,
      earlyCheckInWindow: 30,
      lateCheckOutWindow: 60,
      earlyExitThreshold: 10,
      checkInWindowStartMinutes: _toMinutes(_startTime) - 30,
      checkInWindowEndMinutes: _toMinutes(_startTime) + 60,
      checkOutWindowStartMinutes: _toMinutes(_endTime) - 10,
      checkOutWindowEndMinutes: _toMinutes(_endTime) + 60,
      requireFaceVerification: _requireFace,
      requireQrVerification: _requireQr,
      weeklyOffs: _weeklyOffs,
      isRotating: _isRotating,
      rotationFrequency: _rotationFreq,
      minEmployees: _minEmployees,
      recEmployees: _recEmployees,
      maxEmployees: _maxEmployees,
    );

    if (!s.isBreakValid()) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invalid Break Times'),
          content: const Text('Break timings must fall within the shift working duration boundaries.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Adjust Times')),
          ],
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await widget.repository.saveShift(
        widget.orgId,
        s,
        widget.adminId,
        widget.adminName,
        reason: widget.shift == null ? 'Created shift' : 'Modified parameters',
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shift saved successfully.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
