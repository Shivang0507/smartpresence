import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/widgets/premium_card.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/data/app_user.dart';
import '../../data/models/shift_assignment_model.dart';
import '../../data/models/shift_model.dart';
import '../../data/repositories/shift_repository.dart';

class EmployeeAssignmentScreen extends StatefulWidget {
  final Shift shift;

  const EmployeeAssignmentScreen({super.key, required this.shift});

  @override
  State<EmployeeAssignmentScreen> createState() => _EmployeeAssignmentScreenState();
}

class _EmployeeAssignmentScreenState extends State<EmployeeAssignmentScreen> with SingleTickerProviderStateMixin {
  final _repository = ShiftRepository();
  late TabController _tabController;

  final _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Selection maps
  final Set<String> _selectedEmployees = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userBloc = context.watch<AuthBloc>().state.user;
    if (userBloc == null) {
      return const Scaffold(body: Center(child: Text('Unauthorized.')));
    }
    final orgId = userBloc.organizationId;

    return Scaffold(
      appBar: AppBar(
        title: Text('Assign: ${widget.shift.name}'),
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() => _selectedEmployees.clear()),
          tabs: const [
            Tab(text: 'Assigned Workers'),
            Tab(text: 'Available / Unassigned'),
          ],
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<AppUser>>(
          stream: _repository.watchUsers(orgId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final users = snapshot.data ?? [];
            final query = _searchQuery.toLowerCase().trim();

            final filteredAllUsers = users.where((u) {
              final matchesQuery = u.name.toLowerCase().contains(query) ||
                  (u.employeeId ?? '').toLowerCase().contains(query);
              return matchesQuery;
            }).toList();

            // Tab 0: Assigned Workers
            final assignedWorkers = filteredAllUsers.where((u) => u.shiftId == widget.shift.id).toList();

            // Tab 1: Available / Unassigned / Other Shifts
            final availableWorkers = filteredAllUsers.where((u) => u.shiftId != widget.shift.id).toList();

            return Column(
              children: [
                // Search bar
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: const InputDecoration(
                      labelText: 'Search by Worker Name or ID',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),

                // Bulk action banner if anything is selected
                if (_selectedEmployees.isNotEmpty)
                  _buildBulkActionBanner(
                    orgId,
                    userBloc.id,
                    userBloc.name,
                    assignedWorkers,
                    availableWorkers,
                  ),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildWorkersList(assignedWorkers, true),
                      _buildWorkersList(availableWorkers, false),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBulkActionBanner(
    String orgId,
    String adminId,
    String adminName,
    List<AppUser> assigned,
    List<AppUser> available,
  ) {
    final count = _selectedEmployees.length;
    final isTabAssigned = _tabController.index == 0;

    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$count Selected',
            style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
          Wrap(
            spacing: 8.w,
            children: [
              if (isTabAssigned) ...[
                TextButton.icon(
                  onPressed: () => _bulkRemove(orgId, adminId, adminName),
                  icon: const Icon(Icons.person_remove_alt_1_rounded, color: Colors.red),
                  label: const Text('Unassign', style: TextStyle(color: Colors.red)),
                ),
                TextButton.icon(
                  onPressed: () => _showTransferDialog(orgId, adminId, adminName),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Transfer'),
                ),
              ] else ...[
                TextButton.icon(
                  onPressed: () => _showAssignmentConfigDialog(orgId, adminId, adminName, ShiftAssignmentType.permanent),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Assign Permanent'),
                ),
                TextButton.icon(
                  onPressed: () => _showAssignmentConfigDialog(orgId, adminId, adminName, ShiftAssignmentType.temporary),
                  icon: const Icon(Icons.date_range_rounded),
                  label: const Text('Assign Temp'),
                ),
              ]
            ],
          )
        ],
      ),
    );
  }

  Widget _buildWorkersList(List<AppUser> workers, bool isAssignedTab) {
    if (workers.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Text(_searchQuery.isEmpty ? 'No workers found.' : 'No workers match search criteria.'),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      itemCount: workers.length,
      itemBuilder: (context, index) {
        final worker = workers[index];
        final isSelected = _selectedEmployees.contains(worker.id);

        return PremiumCard(
          margin: EdgeInsets.only(bottom: 10.h),
          child: CheckboxListTile(
            title: Text(worker.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(worker.employeeId ?? 'ID: N/A'),
                if (!isAssignedTab && worker.shiftId != null && worker.shiftId!.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  FutureBuilder<List<Shift>>(
                    future: _repository.watchShifts(worker.organizationId).first,
                    builder: (context, snap) {
                      final currentShiftName = snap.data?.where((s) => s.id == worker.shiftId).firstOrNull?.name ?? 'Other';
                      return Text(
                        'Current Shift: $currentShiftName',
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ],
                if (worker.temporaryShiftId != null) ...[
                  SizedBox(height: 2.h),
                  Text('On Temp Assignment', style: TextStyle(color: Colors.purple, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                ]
              ],
            ),
            value: isSelected,
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedEmployees.add(worker.id);
                } else {
                  _selectedEmployees.remove(worker.id);
                }
              });
            },
          ),
        );
      },
    );
  }

  void _bulkRemove(String orgId, String adminId, String adminName) async {
    final list = _selectedEmployees.toList();
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Unassign Workers'),
        content: Text('Are you sure you want to remove all $list workers from this shift?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _repository.bulkRemoveEmployees(
                orgId: orgId,
                employeeIds: list,
                shiftId: widget.shift.id,
                adminId: adminId,
                adminName: adminName,
              );
              setState(() => _selectedEmployees.clear());
              messenger.showSnackBar(const SnackBar(content: Text('Workers unassigned successfully.')));
            },
            child: const Text('Unassign'),
          )
        ],
      ),
    );
  }

  void _showTransferDialog(String orgId, String adminId, String adminName) async {
    final allShifts = await _repository.watchShifts(orgId).first;
    final otherShifts = allShifts.where((s) => s.id != widget.shift.id && s.status == ShiftStatus.active).toList();

    if (!mounted) return;

    if (otherShifts.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Alternate Shift'),
          content: const Text('There are no other active shifts to transfer these workers to. Please create one first.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    String selectedShiftId = otherShifts.first.id;
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Transfer Workers'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select the shift you want to transfer the ${_selectedEmployees.length} workers to:'),
                  SizedBox(height: 12.h),
                  DropdownButtonFormField<String>(
                    initialValue: selectedShiftId,
                    items: otherShifts.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                    onChanged: (val) => setDialogState(() => selectedShiftId = val!),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    await _repository.reassignEmployees(
                      orgId: orgId,
                      employeeIds: _selectedEmployees.toList(),
                      oldShiftId: widget.shift.id,
                      newShiftId: selectedShiftId,
                      type: ShiftAssignmentType.permanent,
                      startDate: DateTime.now(),
                      adminId: adminId,
                      adminName: adminName,
                    );
                    setState(() => _selectedEmployees.clear());
                    messenger.showSnackBar(const SnackBar(content: Text('Workers transferred successfully.')));
                  },
                  child: const Text('Transfer'),
                )
              ],
            );
          }
        );
      },
    );
  }

  void _showAssignmentConfigDialog(
    String orgId,
    String adminId,
    String adminName,
    ShiftAssignmentType type,
  ) {
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 7));
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(type == ShiftAssignmentType.permanent ? 'Permanent Assignment' : 'Temporary Assignment'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Start Date'),
                    subtitle: Text('${startDate.year}-${startDate.month}-${startDate.day}'),
                    trailing: const Icon(Icons.calendar_today_rounded),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startDate,
                        firstDate: DateTime(2025),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) setDialogState(() => startDate = picked);
                    },
                  ),
                  if (type == ShiftAssignmentType.temporary)
                    ListTile(
                      title: const Text('End Date'),
                      subtitle: Text('${endDate.year}-${endDate.month}-${endDate.day}'),
                      trailing: const Icon(Icons.calendar_today_rounded),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endDate,
                          firstDate: startDate,
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) setDialogState(() => endDate = picked);
                      },
                    ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    
                    // Conflict Check Validation
                    final assignmentsList = await _repository.watchAllAssignments(orgId).first;
                    final conflictingWorkerNames = <String>[];
                    
                    final usersList = await _repository.watchUsers(orgId).first;
 
                    for (final empId in _selectedEmployees) {
                      final empAssignments = assignmentsList.where((a) => a.employeeId == empId && a.status == ShiftAssignmentStatus.active);
                      for (final a in empAssignments) {
                        // Check date overlapping
                        final overlap = (a.endDate == null || a.endDate!.isAfter(startDate)) && 
                                        (type == ShiftAssignmentType.permanent || endDate.isAfter(a.startDate));
                        if (overlap) {
                          final name = usersList.where((u) => u.id == empId).firstOrNull?.name ?? 'Worker';
                          conflictingWorkerNames.add(name);
                          break;
                        }
                      }
                    }
 
                    if (conflictingWorkerNames.isNotEmpty) {
                      if (!context.mounted) return;
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Assignment Conflict Alert'),
                          content: Text('The following workers have overlapping shift schedules during this period:\n\n'
                              '${conflictingWorkerNames.join(", ")}\n\n'
                              'Please resolve conflicts before assigning.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
                          ],
                        ),
                      );
                      return;
                    }
 
                    // Bulk assign
                    await _repository.bulkAssignEmployees(
                      orgId: orgId,
                      shiftId: widget.shift.id,
                      employeeIds: _selectedEmployees.toList(),
                      type: type,
                      startDate: startDate,
                      endDate: type == ShiftAssignmentType.temporary ? endDate : null,
                      adminId: adminId,
                      adminName: adminName,
                    );
 
                    setState(() => _selectedEmployees.clear());
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Employees assigned successfully.')),
                    );
                  },
                  child: const Text('Save Assignment'),
                )
              ],
            );
          }
        );
      },
    );
  }
}
