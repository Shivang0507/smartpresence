import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/premium_card.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/data/app_user.dart';
import '../../data/models/shift_model.dart';
import '../../data/repositories/shift_repository.dart';

class ShiftDetailsScreen extends StatefulWidget {
  final String shiftId;

  const ShiftDetailsScreen({super.key, required this.shiftId});

  @override
  State<ShiftDetailsScreen> createState() => _ShiftDetailsScreenState();
}

class _ShiftDetailsScreenState extends State<ShiftDetailsScreen> with SingleTickerProviderStateMixin {
  final _repository = ShiftRepository();
  late TabController _tabController;

  // Simulator state
  TimeOfDay _simCheckIn = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _simCheckOut = const TimeOfDay(hour: 17, minute: 0);
  Map<String, dynamic>? _simResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _toMinutes(TimeOfDay tod) {
    return tod.hour * 60 + tod.minute;
  }

  void _runSimulation(Shift shift) {
    final inMin = _toMinutes(_simCheckIn);
    final outMin = _toMinutes(_simCheckOut);

    final start = shift.startMinutes;
    final end = shift.endMinutes;

    // Total working duration
    int totalMinutes = (outMin - inMin) % 1440;
    double workingHrs = totalMinutes / 60.0;

    // Late evaluation
    int minutesLate = (inMin - start) % 1440;
    if (minutesLate > 720) {
      minutesLate = 0; // Checked in early
    }
    final isLate = minutesLate > shift.graceTime;
    final isAbsent = minutesLate > shift.absentAfterMinutes;

    // Early exit evaluation
    int minutesEarly = (end - outMin) % 1440;
    if (minutesEarly > 720) {
      minutesEarly = 0; // Checked out late
    }
    final isEarlyExit = minutesEarly > shift.earlyExitThreshold;

    // Half Day evaluation
    final isHalfDay = totalMinutes < shift.halfDayThreshold;

    // Overtime evaluation
    double overtime = 0.0;
    if (shift.overtimeAllowed) {
      int minutesOt = (outMin - end) % 1440;
      if (minutesOt > 720) {
        minutesOt = 0; // Checked out early or on time
      }
      if (minutesOt > shift.overtimeStartsAfter) {
        overtime = double.parse((minutesOt / 60.0).toStringAsFixed(2));
        if (overtime > shift.maxOvertimeHours) {
          overtime = shift.maxOvertimeHours;
        }
      }
    }

    String status = 'Present';
    if (isAbsent) {
      status = 'Absent (Exceeded Limit)';
    } else if (isHalfDay) {
      status = 'Half Day';
    } else if (isLate) {
      status = 'Late';
    }

    setState(() {
      _simResult = {
        'status': status,
        'workingHours': double.parse(workingHrs.toStringAsFixed(2)),
        'earlyExit': isEarlyExit,
        'overtime': overtime,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final userBloc = context.watch<AuthBloc>().state.user;
    if (userBloc == null) {
      return const Scaffold(body: Center(child: Text('Unauthorized.')));
    }
    final orgId = userBloc.organizationId;

    return StreamBuilder<List<Shift>>(
      stream: _repository.watchShifts(orgId),
      builder: (context, shiftsSnap) {
        if (shiftsSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final shifts = shiftsSnap.data ?? [];
        final shiftList = shifts.where((s) => s.id == widget.shiftId).toList();
        if (shiftList.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Shift Details')),
            body: const Center(child: Text('Shift configuration not found or archived.')),
          );
        }
        final shift = shiftList.first;

        // Initialize simulator time based on shift if first time
        if (_simResult == null) {
          _simCheckIn = TimeOfDay(hour: (shift.startMinutes ~/ 60) % 24, minute: shift.startMinutes % 60);
          _simCheckOut = TimeOfDay(hour: (shift.endMinutes ~/ 60) % 24, minute: shift.endMinutes % 60);
          _runSimulation(shift);
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(shift.name),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Settings & Simulator'),
                Tab(text: 'Assigned Workers'),
                Tab(text: 'Audit & Versions'),
              ],
            ),
          ),
          body: SafeArea(
            child: StreamBuilder<List<AppUser>>(
              stream: _repository.watchUsers(orgId),
              builder: (context, usersSnap) {
                final users = usersSnap.data ?? [];
                final assignedUsers = users.where((u) => u.shiftId == shift.id).toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Details & Simulator
                    _buildSettingsTab(shift, assignedUsers.length),

                    // Tab 2: Assigned Workers Table
                    _buildWorkersTab(shift, assignedUsers),

                    // Tab 3: History & Versions
                    _buildHistoryTab(shift, orgId),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsTab(Shift shift, int employeeCount) {

    return ListView(
      padding: EdgeInsets.all(18.w),
      children: [
        // Analytics Cards
        Row(
          children: [
            Expanded(
              child: _buildMiniAnalyticsCard(
                'Assigned Workers',
                '$employeeCount',
                Icons.engineering_rounded,
                Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _buildMiniAnalyticsCard(
                'Average Late %',
                '1.2%',
                Icons.warning_amber_rounded,
                Colors.orange,
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _buildMiniAnalyticsCard(
                'Average Overtime',
                '1.5 hrs',
                Icons.electric_bolt_rounded,
                Colors.purple,
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),

        // Policy Configurations Table
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Shift Policy Details', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
              const Divider(),
              _buildDetailRow('Shift Code', shift.code ?? 'N/A'),
              _buildDetailRow('Shift Version', 'v${shift.version}'),
              _buildDetailRow('Timings', '${ShiftTime.fromMinutes(shift.startMinutes).format24h()} - ${ShiftTime.fromMinutes(shift.endMinutes).format24h()}'),
              _buildDetailRow('Break Duration', '${(shift.breakEndMinutes - shift.breakStartMinutes) % 1440} mins'),
              _buildDetailRow('Grace Period', '${shift.graceTime} minutes'),
              _buildDetailRow('Late Entry Cutoff', 'After ${shift.lateEntryThreshold} mins'),
              _buildDetailRow('Absent Trigger', 'After ${shift.absentAfterMinutes} mins'),
              _buildDetailRow('Weekly Off days', shift.weeklyOffs.map((d) => _dayName(d)).join(', ')),
              _buildDetailRow('Require Face verification', shift.requireFaceVerification ? 'YES' : 'NO'),
              _buildDetailRow('Require QR verification', shift.requireQrVerification ? 'YES' : 'NO'),
            ],
          ),
        ),
        SizedBox(height: 16.h),

        // Simulator panel
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.tune_rounded, size: 20.w, color: Colors.blue),
                  SizedBox(width: 6.w),
                  Text('Attendance Rule Simulator', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(),
              _buildSimulatorTimePicker('Sample Check-In', _simCheckIn, (tod) {
                setState(() => _simCheckIn = tod);
                _runSimulation(shift);
              }),
              _buildSimulatorTimePicker('Sample Check-Out', _simCheckOut, (tod) {
                setState(() => _simCheckOut = tod);
                _runSimulation(shift);
              }),
              SizedBox(height: 14.h),
              if (_simResult != null) ...[
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Simulated Status:', style: TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            _simResult!['status'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _simResult!['status'].toString().contains('Absent')
                                  ? Colors.red
                                  : (_simResult!['status'].toString().contains('Late') ? Colors.orange : AppColors.success),
                            ),
                          )
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Net Working Hours:'),
                          Text('${_simResult!['workingHours']} hrs', style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Overtime Calculated:'),
                          Text('${_simResult!['overtime']} hrs', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.purple)),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Early Exit Alert:'),
                          Text(_simResult!['earlyExit'] ? 'YES' : 'NO', style: TextStyle(fontWeight: FontWeight.w600, color: _simResult!['earlyExit'] ? Colors.red : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                        ],
                      ),
                    ],
                  ),
                )
              ]
            ],
          ),
        )
      ],
    );
  }

  Widget _buildMiniAnalyticsCard(String title, String val, IconData icon, Color color) {
    return PremiumCard(
      padding: EdgeInsets.all(10.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16.w, color: color),
          SizedBox(height: 8.h),
          Text(val, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
          SizedBox(height: 2.h),
          Text(title, style: TextStyle(fontSize: 9.sp, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSimulatorTimePicker(String label, TimeOfDay time, ValueChanged<TimeOfDay> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        TextButton(
          onPressed: () async {
            final res = await showTimePicker(context: context, initialTime: time);
            if (res != null) onChanged(res);
          },
          child: Text(time.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
        )
      ],
    );
  }

  String _dayName(int day) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (day < 1 || day > 7) return '';
    return days[day - 1];
  }

  Widget _buildWorkersTab(Shift shift, List<AppUser> assignedUsers) {
    if (assignedUsers.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: const Text('No workers currently assigned to this shift.'),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: assignedUsers.length,
      itemBuilder: (context, index) {
        final worker = assignedUsers[index];
        return PremiumCard(
          margin: EdgeInsets.only(bottom: 10.h),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              child: Text(worker.name.trim().isEmpty ? '?' : worker.name[0].toUpperCase()),
            ),
            title: Text(worker.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(worker.employeeId ?? 'ID: N/A'),
            trailing: IconButton(
              icon: const Icon(Icons.person_remove_alt_1_rounded, color: Colors.redAccent),
              onPressed: () => _confirmRemoveWorker(shift, worker),
            ),
          ),
        );
      },
    );
  }

  void _confirmRemoveWorker(Shift shift, AppUser worker) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unassign Employee'),
        content: Text('Are you sure you want to remove ${worker.name} from the shift "${shift.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final currentUser = context.read<AuthBloc>().state.user;
              if (currentUser != null) {
                await _repository.bulkRemoveEmployees(
                  orgId: shift.organizationId,
                  employeeIds: [worker.id],
                  shiftId: shift.id,
                  adminId: currentUser.id,
                  adminName: currentUser.name,
                );
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${worker.name} unassigned.')));
              }
            },
            child: const Text('Remove'),
          )
        ],
      ),
    );
  }

  Widget _buildHistoryTab(Shift shift, String orgId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _repository.fetchAuditHistory(orgId, shift.id),
      builder: (context, auditSnap) {
        if (auditSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = auditSnap.data ?? [];
        if (list.isEmpty) {
          return const Center(child: Text('No operation history logged for this shift.'));
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final entry = list[index];
            final action = entry['action'] as String? ?? 'OPERATION';
            final timestamp = entry['timestamp'] as Timestamp?;
            final dateStr = timestamp != null ? timestamp.toDate().toString().split('.')[0] : 'N/A';
            final user = entry['userName'] as String? ?? 'Admin';
            final reason = entry['changeReason'] as String? ?? '';

            return PremiumCard(
              margin: EdgeInsets.only(bottom: 10.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(action, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      Text(dateStr, style: TextStyle(fontSize: 10.sp, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55))),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text('Updated by: $user', style: TextStyle(fontSize: 12.sp)),
                  if (reason.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Text('Reason: $reason', style: TextStyle(fontSize: 11.sp, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55), fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
