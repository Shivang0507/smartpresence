import 'dart:io' show File;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../../core/constants/firestore_paths.dart';
import '../../../core/enums/user_role.dart';
import '../../auth/data/app_user.dart';
import '../../auth/data/auth_repository.dart';
import 'cloudinary_service.dart';

class UserCreationDraft {
  const UserCreationDraft({
    required this.user,
    required this.profilePhoto,
    required this.faceMetadata,
    required this.temporaryPassword,
    this.faceImagePath,
  });

  final AppUser user;
  final String profilePhoto; // Local file path of profile photo
  final Map<String, dynamic> faceMetadata;
  final String temporaryPassword;
  final String? faceImagePath; // Local file path of face registration photo
}

class UserRepository {
  UserRepository() : _firestore = FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<AppUser>> watchUsers({
    required String organizationId,
    List<UserRole>? roles,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(FirestorePaths.users)
        .where('organizationId', isEqualTo: organizationId);

    return query.snapshots().map((snapshot) {
      final users = snapshot.docs
          .map((doc) => AppUser.fromMap(doc.id, doc.data()))
          .where((user) => user.isActive)
          .where((user) => roles == null || roles.contains(user.role))
          .toList();
      users.sort((a, b) => a.name.compareTo(b.name));
      return users;
    });
  }

  Future<void> saveUser({
    required String organizationId,
    required AppUser user,
  }) async {
    if (user.organizationId != organizationId) {
      throw StateError('User profile does not belong to this organization.');
    }
    final normalizedEmail = _normalizeEmail(user.email);
    final duplicateQuery = await _firestore
        .collection(FirestorePaths.users)
        .where('organizationId', isEqualTo: organizationId)
        .get();
    final hasDuplicate = duplicateQuery.docs.any((doc) {
      final data = doc.data();
      final email = data['emailNormalized'] as String? ??
          _normalizeEmail(data['email'] as String? ?? '');
      final isActive = data['isActive'] as bool? ?? true;
      return doc.id != user.id && isActive && email == normalizedEmail;
    });
    if (hasDuplicate) {
      throw StateError('A user with this email already exists in this organization.');
    }

    final ref = _firestore
        .collection(FirestorePaths.users)
        .doc(user.id.isEmpty ? null : user.id);
    await _firestore.runTransaction((transaction) async {
      if (user.id.isNotEmpty) {
        final existing = await transaction.get(ref);
        final existingOrganizationId = existing.data()?['organizationId'] as String?;
        if (!existing.exists || existingOrganizationId != organizationId) {
          throw StateError('User profile was not found in this organization.');
        }
      }
      transaction.set(ref, {
        ...user.toMap(),
        'emailNormalized': normalizedEmail,
        'updatedAt': FieldValue.serverTimestamp(),
        if (user.id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<String> createUserWithFace({
    required String organizationId,
    required UserCreationDraft draft,
    required AuthRepository authRepository,
    void Function(String status)? onProgress,
  }) async {
    if (draft.user.organizationId != organizationId) {
      throw StateError('User profile does not belong to this organization.');
    }

    final normalizedEmail = _normalizeEmail(draft.user.email);
    if (normalizedEmail.isEmpty) {
      throw StateError('Email is required to create an account for this user.');
    }

    final duplicateQuery = await _firestore
        .collection(FirestorePaths.users)
        .where('organizationId', isEqualTo: organizationId)
        .get();
    final hasDuplicate = duplicateQuery.docs.any((doc) {
      final data = doc.data();
      final email = data['emailNormalized'] as String? ??
          _normalizeEmail(data['email'] as String? ?? '');
      final isActive = data['isActive'] as bool? ?? true;
      return isActive && email == normalizedEmail;
    });
    if (hasDuplicate) {
      throw StateError('A user with this email already exists in this organization.');
    }

    onProgress?.call('Creating credentials...');
    // Create Firebase Auth account using secondary app (does not sign admin out).
    final uid = await authRepository.createMemberAccount(
      email: draft.user.email,
      temporaryPassword: draft.temporaryPassword,
    );

    // Initialize Cloudinary Service
    final cloudinary = CloudinaryService();

    // Upload Profile Photo to Cloudinary
    String? profileImageUrl;
    final profilePhotoLocal = draft.profilePhoto.trim();
    if (profilePhotoLocal.isNotEmpty && File(profilePhotoLocal).existsSync()) {
      onProgress?.call('Uploading profile photo...');
      try {
        profileImageUrl = await cloudinary.uploadProfilePhoto(profilePhotoLocal, organizationId);
      } catch (e) {
        debugPrint('Profile photo upload failed: $e');
        throw Exception('Failed to upload profile photo: $e');
      }
    }

    // Upload Face Registration Image to Cloudinary
    String? faceImageUrl;
    final faceImageLocal = draft.faceImagePath;
    if (faceImageLocal != null && faceImageLocal.isNotEmpty && File(faceImageLocal).existsSync()) {
      onProgress?.call('Uploading face biometrics...');
      try {
        faceImageUrl = await cloudinary.uploadFaceImage(faceImageLocal, organizationId);
      } catch (e) {
        debugPrint('Face image upload failed: $e');
        throw Exception('Failed to upload face registration image: $e');
      }
    }

    onProgress?.call('Saving database profile...');
    final userRef = _firestore.collection(FirestorePaths.users).doc(uid);
    final faceRef = _firestore.collection(FirestorePaths.faceRegistrations).doc(uid);
    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();
    
    final updatedFaceMetadata = {
      ...draft.faceMetadata,
      'faceImageUrl': ?faceImageUrl,
    };

    final user = AppUser(
      id: uid,
      organizationId: organizationId,
      name: draft.user.name,
      email: draft.user.email,
      role: draft.user.role,
      kind: draft.user.kind,
      phone: draft.user.phone,
      employeeId: draft.user.employeeId,
      departmentId: draft.user.departmentId,
      teamId: draft.user.teamId,
      profileImageUrl: profileImageUrl,
      faceImageUrl: faceImageUrl,
      faceMetadata: updatedFaceMetadata,
    );

    batch.set(userRef, {
      ...user.toMap(),
      'emailNormalized': normalizedEmail,
      'createdAt': now,
      'updatedAt': now,
    });
    batch.set(faceRef, {
      'userId': uid,
      'organizationId': organizationId,
      'profileImageUrl': profileImageUrl ?? '',
      'faceImageUrl': faceImageUrl ?? '',
      'faceMetadata': updatedFaceMetadata,
      'createdAt': now,
    });
    await batch.commit();
    return uid;
  }

  Future<void> deactivateUser({
    required String organizationId,
    required String id,
  }) async {
    final ref = _firestore.collection(FirestorePaths.users).doc(id);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final existingOrganizationId = snapshot.data()?['organizationId'] as String?;
      if (!snapshot.exists || existingOrganizationId != organizationId) {
        throw StateError('User profile was not found in this organization.');
      }
      transaction.set(ref, {
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();
}
