import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/firestore_paths.dart';
import 'attendance_models.dart';

class AttendanceRepository {
  AttendanceRepository() : _firestore = FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<String> startSession({required String organizationId}) async {
    final ref = _firestore.collection(FirestorePaths.attendanceSessions).doc();
    await ref.set({
      'organizationId': organizationId,
      'timestamp': FieldValue.serverTimestamp(),
      'securityToken': _token(),
      'status': 'active',
      'presentCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Stream<AttendanceSession> watchSession(String sessionId) {
    return _firestore
        .collection(FirestorePaths.attendanceSessions)
        .doc(sessionId)
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data() ?? const <String, dynamic>{};
      final rawTimestamp = data['timestamp'];
      final timestamp = rawTimestamp is Timestamp ? rawTimestamp.toDate() : DateTime.now();
      return AttendanceSession.fromMap(snapshot.id, {
        ...data,
        'timestamp': timestamp,
      });
    });
  }

  Stream<int> watchLiveCount({required String organizationId, required String sessionId}) {
    return _firestore
        .collection(FirestorePaths.attendanceRecords)
        .where('organizationId', isEqualTo: organizationId)
        .where('sessionId', isEqualTo: sessionId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<void> markAttendance({
    required String userId,
    required String organizationId,
    required String sessionId,
    required String token,
  }) async {
    final sessionRef = _firestore.collection(FirestorePaths.attendanceSessions).doc(sessionId);
    final recordRef = _firestore
        .collection(FirestorePaths.attendanceRecords)
        .doc('${sessionId}_$userId');
    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot<Map<String, dynamic>> session;
      try {
        session = await transaction.get(sessionRef);
      } catch (e) {
        throw StateError('TX_READ_SESSION_DENIED: $e');
      }

      DocumentSnapshot<Map<String, dynamic>> existingRecord;
      try {
        existingRecord = await transaction.get(recordRef);
      } catch (e) {
        throw StateError('TX_READ_RECORD_DENIED: $e');
      }

      final data = session.data();
      if (!session.exists || data == null) {
        throw StateError('Attendance session was not found.');
      }
      if (existingRecord.exists) {
        throw StateError('Attendance is already marked for this session.');
      }
      if (data['securityToken'] != token || data['status'] != 'active') {
        throw StateError('This QR code has expired. Scan the latest code.');
      }

      final now = DateTime.now();
      try {
        transaction.set(recordRef, {
          'attendanceId': recordRef.id,
          'userId': userId,
          'organizationId': organizationId,
          'sessionId': sessionId,
          'date': _date(now),
          'time': _time(now),
          'status': 'present',
          'method': 'QR_FACE',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        throw StateError('TX_WRITE_RECORD_DENIED: $e');
      }

      try {
        transaction.update(sessionRef, {
          'securityToken': _token(),
          'timestamp': FieldValue.serverTimestamp(),
          'presentCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        throw StateError('TX_WRITE_SESSION_DENIED: $e');
      }
    }).catchError((error) {
      debugPrint('MARK ATTENDANCE TRANSACTION FAILED: $error');
      throw error;
    });
  }

  Future<void> endSession(String sessionId) async {
    await _firestore.collection(FirestorePaths.attendanceSessions).doc(sessionId).set({
      'status': 'closed',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _token() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(24, (_) => chars[random.nextInt(chars.length)]).join();
  }

  String _date(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  String _time(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
  }
}
