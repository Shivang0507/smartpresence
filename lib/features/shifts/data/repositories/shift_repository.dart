import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../../../auth/data/app_user.dart';
import '../models/shift_assignment_model.dart';
import '../models/shift_model.dart';

class ShiftRepository {
  final FirebaseFirestore _firestore;

  ShiftRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Streams non-archived shifts for the organization
  Stream<List<Shift>> watchShifts(String orgId) {
    return _firestore
        .collection(FirestorePaths.organizations)
        .doc(orgId)
        .collection(FirestorePaths.shifts)
        .snapshots()
        .map((snapshot) {
      final shifts = snapshot.docs
          .map((doc) => Shift.fromMap(doc.id, doc.data()))
          .where((s) => s.status != ShiftStatus.archived)
          .toList();
      shifts.sort((a, b) => a.name.compareTo(b.name));
      return shifts;
    });
  }

  // Streams archived shifts
  Stream<List<Shift>> watchArchivedShifts(String orgId) {
    return _firestore
        .collection(FirestorePaths.organizations)
        .doc(orgId)
        .collection(FirestorePaths.shifts)
        .where('status', isEqualTo: 'archived')
        .snapshots()
        .map((snapshot) {
      final shifts = snapshot.docs
          .map((doc) => Shift.fromMap(doc.id, doc.data()))
          .toList();
      shifts.sort((a, b) => a.name.compareTo(b.name));
      return shifts;
    });
  }

  // Saves or updates a shift, including automatic version snapshotting
  Future<void> saveShift(
    String orgId,
    Shift shift,
    String adminId,
    String adminName, {
    String? reason,
  }) async {
    final docRef = _firestore
        .collection(FirestorePaths.organizations)
        .doc(orgId)
        .collection(FirestorePaths.shifts)
        .doc(shift.id.isEmpty ? null : shift.id);

    final isNew = shift.id.isEmpty;
    final finalId = isNew ? docRef.id : shift.id;

    if (isNew) {
      final newShift = shift.copyWith(id: finalId, version: 1);
      await docRef.set(newShift.toMap());

      await writeAuditLog(
        orgId: orgId,
        shiftId: finalId,
        userId: adminId,
        userName: adminName,
        action: 'CREATED',
        newVersion: 1,
        changeReason: reason ?? 'Initial shift creation',
        newValues: newShift.toMap(),
      );
    } else {
      final snapshot = await docRef.get();
      if (!snapshot.exists || snapshot.data() == null) {
        throw StateError('Shift not found to update.');
      }

      final prevShift = Shift.fromMap(snapshot.id, snapshot.data()!);

      // Check if critical settings changed
      final timingsChanged = prevShift.startMinutes != shift.startMinutes ||
          prevShift.endMinutes != shift.endMinutes ||
          prevShift.breakStartMinutes != shift.breakStartMinutes ||
          prevShift.breakEndMinutes != shift.breakEndMinutes;

      final rulesChanged = prevShift.graceTime != shift.graceTime ||
          prevShift.lateEntryThreshold != shift.lateEntryThreshold ||
          prevShift.absentAfterMinutes != shift.absentAfterMinutes ||
          prevShift.halfDayThreshold != shift.halfDayThreshold ||
          prevShift.requireFaceVerification != shift.requireFaceVerification ||
          prevShift.requireQrVerification != shift.requireQrVerification;

      int newVersion = prevShift.version;
      if (timingsChanged || rulesChanged) {
        // Snapshot the previous version
        await docRef.collection('versions').doc(prevShift.version.toString()).set({
          ...prevShift.toMap(),
          'snapshotAt': FieldValue.serverTimestamp(),
        });
        newVersion = prevShift.version + 1;
      }

      final updatedShift = shift.copyWith(
        id: finalId,
        version: newVersion,
      );

      await docRef.set(updatedShift.toMap(), SetOptions(merge: true));

      await writeAuditLog(
        orgId: orgId,
        shiftId: finalId,
        userId: adminId,
        userName: adminName,
        action: 'UPDATED',
        previousVersion: prevShift.version,
        newVersion: newVersion,
        changeReason: reason ?? 'Shift configuration updated',
        previousValues: prevShift.toMap(),
        newValues: updatedShift.toMap(),
      );
    }
  }

  // Deactivates a shift (sets status = inactive)
  Future<void> deactivateShift(String orgId, String shiftId, String adminId, String adminName) async {
    await _firestore
        .collection(FirestorePaths.organizations)
        .doc(orgId)
        .collection(FirestorePaths.shifts)
        .doc(shiftId)
        .update({'status': 'inactive'});

    await writeAuditLog(
      orgId: orgId,
      shiftId: shiftId,
      userId: adminId,
      userName: adminName,
      action: 'DEACTIVATED',
      changeReason: 'Admin manual deactivation',
    );
  }

  // Activates a shift (sets status = active)
  Future<void> activateShift(String orgId, String shiftId, String adminId, String adminName) async {
    await _firestore
        .collection(FirestorePaths.organizations)
        .doc(orgId)
        .collection(FirestorePaths.shifts)
        .doc(shiftId)
        .update({'status': 'active'});

    await writeAuditLog(
      orgId: orgId,
      shiftId: shiftId,
      userId: adminId,
      userName: adminName,
      action: 'ACTIVATED',
      changeReason: 'Admin manual activation',
    );
  }

  // Archives a shift (sets status = archived)
  Future<void> archiveShift(String orgId, String shiftId, String adminId, String adminName) async {
    // Check if users are assigned
    final userCheck = await _firestore
        .collection(FirestorePaths.users)
        .where('organizationId', isEqualTo: orgId)
        .where('shiftId', isEqualTo: shiftId)
        .get();

    if (userCheck.docs.isNotEmpty) {
      throw StateError('Cannot archive shift because employees are still permanently assigned.');
    }

    await _firestore
        .collection(FirestorePaths.organizations)
        .doc(orgId)
        .collection(FirestorePaths.shifts)
        .doc(shiftId)
        .update({'status': 'archived'});

    await writeAuditLog(
      orgId: orgId,
      shiftId: shiftId,
      userId: adminId,
      userName: adminName,
      action: 'ARCHIVED',
      changeReason: 'Admin manual archive',
    );
  }

  // Deletes a shift permanently if no employees are assigned
  Future<void> deleteShift(String orgId, String shiftId, String adminId, String adminName) async {
    final assignedUsers = await _firestore
        .collection(FirestorePaths.users)
        .where('organizationId', isEqualTo: orgId)
        .where('shiftId', isEqualTo: shiftId)
        .get();

    final assignedTempUsers = await _firestore
        .collection(FirestorePaths.users)
        .where('organizationId', isEqualTo: orgId)
        .where('temporaryShiftId', isEqualTo: shiftId)
        .get();

    if (assignedUsers.docs.isNotEmpty || assignedTempUsers.docs.isNotEmpty) {
      throw StateError('Cannot delete shift because employees are still assigned.');
    }

    await _firestore
        .collection(FirestorePaths.organizations)
        .doc(orgId)
        .collection(FirestorePaths.shifts)
        .doc(shiftId)
        .delete();
  }

  // Streams active assignments for a shift
  Stream<List<ShiftAssignment>> watchAssignments(String orgId, String shiftId) {
    return _firestore
        .collection(FirestorePaths.organizations)
        .doc(orgId)
        .collection(FirestorePaths.shiftAssignments)
        .where('shiftId', isEqualTo: shiftId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ShiftAssignment.fromMap(doc.id, doc.data()))
            .toList());
  }

  // Streams all assignments
  Stream<List<ShiftAssignment>> watchAllAssignments(String orgId) {
    return _firestore
        .collection(FirestorePaths.organizations)
        .doc(orgId)
        .collection(FirestorePaths.shiftAssignments)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ShiftAssignment.fromMap(doc.id, doc.data()))
            .toList());
  }

  // Bulk assigns employees to a shift
  Future<void> bulkAssignEmployees({
    required String orgId,
    required String shiftId,
    required List<String> employeeIds,
    required ShiftAssignmentType type,
    required DateTime startDate,
    DateTime? endDate,
    required String adminId,
    required String adminName,
  }) async {
    final batch = _firestore.batch();
    final now = DateTime.now();

    for (final empId in employeeIds) {
      final assignRef = _firestore
          .collection(FirestorePaths.organizations)
          .doc(orgId)
          .collection(FirestorePaths.shiftAssignments)
          .doc();

      final assignment = ShiftAssignment(
        id: assignRef.id,
        employeeId: empId,
        organizationId: orgId,
        shiftId: shiftId,
        assignmentType: type,
        startDate: startDate,
        endDate: endDate,
        status: ShiftAssignmentStatus.active,
        createdBy: adminId,
        createdAt: now,
      );

      batch.set(assignRef, assignment.toMap());

      // Update cached values on User document
      final userRef = _firestore.collection(FirestorePaths.users).doc(empId);
      final userUpdates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (type == ShiftAssignmentType.permanent) {
        userUpdates['shiftId'] = shiftId;
      } else {
        userUpdates['temporaryShiftId'] = shiftId;
        userUpdates['temporaryShiftStart'] =
            '${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
        if (endDate != null) {
          userUpdates['temporaryShiftEnd'] =
              '${endDate.year.toString().padLeft(4, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
        }
      }

      batch.update(userRef, userUpdates);

      // Audit logs
      final logRef = _firestore
          .collection(FirestorePaths.organizations)
          .doc(orgId)
          .collection(FirestorePaths.shifts)
          .doc(shiftId)
          .collection('history')
          .doc();

      batch.set(logRef, {
        'userId': adminId,
        'userName': adminName,
        'timestamp': FieldValue.serverTimestamp(),
        'action': 'EMPLOYEE_ASSIGNED',
        'details': 'Assigned employee $empId to shift (Type: ${type.name})',
        'employeeId': empId,
      });
    }

    await batch.commit();
  }

  // Bulk removes employees from a shift
  Future<void> bulkRemoveEmployees({
    required String orgId,
    required List<String> employeeIds,
    required String shiftId,
    required String adminId,
    required String adminName,
  }) async {
    final batch = _firestore.batch();

    // Query active assignments for these employees and shift
    final assignmentsQuery = await _firestore
        .collection(FirestorePaths.organizations)
        .doc(orgId)
        .collection(FirestorePaths.shiftAssignments)
        .where('shiftId', isEqualTo: shiftId)
        .where('status', isEqualTo: 'active')
        .get();

    for (final empId in employeeIds) {
      // Find matching assignments in snapshot
      final matchedDocs = assignmentsQuery.docs.where((doc) => doc.data()['employeeId'] == empId);
      for (final doc in matchedDocs) {
        batch.update(doc.reference, {
          'status': ShiftAssignmentStatus.completed.name,
          'endDate': Timestamp.fromDate(DateTime.now()),
        });
      }

      // Update cached values on User document
      final userRef = _firestore.collection(FirestorePaths.users).doc(empId);
      
      // We will perform a merge update, deleting/clearing fields if they match
      // For safety, we can retrieve the user first, or just clear them since we unassign them from this shift.
      batch.update(userRef, {
        'shiftId': FieldValue.delete(),
        'temporaryShiftId': FieldValue.delete(),
        'temporaryShiftStart': FieldValue.delete(),
        'temporaryShiftEnd': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Audit Log
      final logRef = _firestore
          .collection(FirestorePaths.organizations)
          .doc(orgId)
          .collection(FirestorePaths.shifts)
          .doc(shiftId)
          .collection('history')
          .doc();

      batch.set(logRef, {
        'userId': adminId,
        'userName': adminName,
        'timestamp': FieldValue.serverTimestamp(),
        'action': 'EMPLOYEE_REMOVED',
        'details': 'Removed employee $empId from shift',
        'employeeId': empId,
      });
    }

    await batch.commit();
  }

  // Reassigns / Transfers employees from old shift to new shift
  Future<void> reassignEmployees({
    required String orgId,
    required List<String> employeeIds,
    required String oldShiftId,
    required String newShiftId,
    required ShiftAssignmentType type,
    required DateTime startDate,
    DateTime? endDate,
    required String adminId,
    required String adminName,
  }) async {
    // 1. Unassign from old shift
    await bulkRemoveEmployees(
      orgId: orgId,
      employeeIds: employeeIds,
      shiftId: oldShiftId,
      adminId: adminId,
      adminName: adminName,
    );

    // 2. Assign to new shift
    await bulkAssignEmployees(
      orgId: orgId,
      shiftId: newShiftId,
      employeeIds: employeeIds,
      type: type,
      startDate: startDate,
      endDate: endDate,
      adminId: adminId,
      adminName: adminName,
    );
  }

  // Writes a shift operation audit log entry
  Future<void> writeAuditLog({
    required String orgId,
    required String shiftId,
    required String userId,
    required String userName,
    required String action,
    int? previousVersion,
    int? newVersion,
    String? changeReason,
    Map<String, dynamic>? previousValues,
    Map<String, dynamic>? newValues,
  }) async {
    await _firestore
        .collection(FirestorePaths.organizations)
        .doc(orgId)
        .collection(FirestorePaths.shifts)
        .doc(shiftId)
        .collection('history')
        .add({
      'userId': userId,
      'userName': userName,
      'timestamp': FieldValue.serverTimestamp(),
      'action': action,
      'previousVersion': previousVersion,
      'newVersion': newVersion,
      'changeReason': changeReason,
      'previousValues': previousValues,
      'newValues': newValues,
      'device': kIsWeb ? 'Web Browser' : 'Mobile Application',
      'ipAddress': 'Unavailable',
    });
  }

  // Stream of users for assignments
  Stream<List<AppUser>> watchUsers(String orgId) {
    return _firestore
        .collection(FirestorePaths.users)
        .where('organizationId', isEqualTo: orgId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppUser.fromMap(doc.id, doc.data()))
            .where((user) => user.isActive)
            .toList());
  }

  // Fetch shift details historical versions
  Future<List<Map<String, dynamic>>> fetchVersionHistory(String orgId, String shiftId) async {
    final snap = await _firestore
        .collection(FirestorePaths.organizations)
        .doc(orgId)
        .collection(FirestorePaths.shifts)
        .doc(shiftId)
        .collection('versions')
        .get();

    return snap.docs.map((doc) => doc.data()).toList();
  }

  // Fetch shift operation audit trail
  Future<List<Map<String, dynamic>>> fetchAuditHistory(String orgId, String shiftId) async {
    final snap = await _firestore
        .collection(FirestorePaths.organizations)
        .doc(orgId)
        .collection(FirestorePaths.shifts)
        .doc(shiftId)
        .collection('history')
        .orderBy('timestamp', descending: true)
        .get();

    return snap.docs.map((doc) => doc.data()).toList();
  }
}
