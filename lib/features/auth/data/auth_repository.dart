import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/enums/organization_type.dart';
import '../../../core/enums/user_role.dart';
import 'app_user.dart';

class OrganizationRegistrationInput {
  const OrganizationRegistrationInput({
    required this.organizationName,
    required this.organizationType,
    required this.adminName,
    required this.adminEmail,
    required this.adminPassword,
    required this.phoneNumber,
    required this.address,
  });

  final String organizationName;
  final OrganizationType organizationType;
  final String adminName;
  final String adminEmail;
  final String adminPassword;
  final String phoneNumber;
  final String address;
}

class AuthRepository {
  AuthRepository({required this.firebaseAvailable})
    : _auth = FirebaseAuth.instance,
      _firestore = FirebaseFirestore.instance;

  final bool firebaseAvailable;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<AppUser?> watchSession() {
    if (!firebaseAvailable) {
      return Stream<AppUser?>.value(null);
    }
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) {
        return null;
      }
      return _fetchUser(firebaseUser.uid);
    });
  }

  Future<AppUser> login({required String email, required String password}) async {
    _assertFirebase();
    debugPrint('LOGIN STEP 1: Attempting Firebase Auth Sign In for $email');
    try {
      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final user = credential.user;
      if (user == null) {
        throw StateError('Unable to sign in with the supplied credentials.');
      }
      debugPrint('AUTH SUCCESS');
      debugPrint('LOGIN STEP 2: Firebase Auth Sign In Success. User UID: ${user.uid}');
      
      debugPrint('LOGIN STEP 3: Fetching user profile from Firestore...');
      final appUser = await _fetchUser(user.uid);
      debugPrint('PROFILE FETCH SUCCESS');
      return appUser;
    } catch (e, stack) {
      debugPrint('LOGIN ERROR: $e');
      debugPrint('Stack trace: $stack');
      rethrow;
    }
  }

  Future<AppUser> registerOrganization(OrganizationRegistrationInput input) async {
    _assertFirebase();
    
    final projectId = Firebase.app().options.projectId;
    debugPrint('STEP 0 - Firebase Project ID: $projectId');
    
    debugPrint('STEP 1 - Creating Firebase Auth User for ${input.adminEmail}');
    debugPrint('AUTH START');
    
    final credential = await _auth.createUserWithEmailAndPassword(
      email: input.adminEmail.trim(),
      password: input.adminPassword,
    );
    final firebaseUser = credential.user;
    if (firebaseUser == null) {
      debugPrint('STEP 1 ERROR: Firebase Auth User creation failed');
      throw StateError('Unable to create the administrator account.');
    }
    debugPrint('AUTH SUCCESS');

    // Force Auth token synchronization with Firestore client to prevent race conditions
    debugPrint('SYNCING AUTH TOKEN WITH FIRESTORE...');
    await firebaseUser.getIdToken();
    debugPrint('AUTH TOKEN SYNC COMPLETE');

    final organizationRef = _firestore.collection(FirestorePaths.organizations).doc();
    final userRef = _firestore.collection(FirestorePaths.users).doc(firebaseUser.uid);
    final settingsRef = organizationRef.collection(FirestorePaths.settings).doc('default');
    
    debugPrint('BATCH START');
    debugPrint('Organization ID: ${organizationRef.id}');
    debugPrint('User ID: ${firebaseUser.uid}');
    debugPrint('CreatedBy: ${firebaseUser.uid}');
    debugPrint('Role: ${UserRole.admin.value}');
    debugPrint('Organization Type: ${input.organizationType.label}');
    debugPrint('Target paths:');
    debugPrint('  - organizations/${organizationRef.id}');
    debugPrint('  - users/${firebaseUser.uid}');
    debugPrint('  - ${settingsRef.path}');
    
    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();
    
    batch.set(organizationRef, {
      'name': input.organizationName.trim(),
      'type': input.organizationType.label,
      'organizationType': input.organizationType.name,
      'phone': input.phoneNumber.trim(),
      'address': input.address.trim(),
      'createdBy': firebaseUser.uid,
      'createdAt': now,
      'updatedAt': now,
      'isActive': true,
      'plan': 'starter',
    });
    
    batch.set(userRef, {
      'organizationId': organizationRef.id,
      'name': input.adminName.trim(),
      'email': input.adminEmail.trim(),
      'emailNormalized': input.adminEmail.trim().toLowerCase(),
      'phone': input.phoneNumber.trim(),
      'role': UserRole.admin.value,
      'createdAt': now,
      'updatedAt': now,
      'isActive': true,
    });
    
    batch.set(settingsRef, {
      'attendanceMode': 'face_qr_hybrid',
      'timezone': 'Asia/Kolkata',
      'allowReceptionistReports': true,
      'createdAt': now,
      'updatedAt': now,
    });
    
    debugPrint('STEP 3 - About To Commit Batch');
    try {
      await batch.commit();
      debugPrint('BATCH SUCCESS');
    } catch (e, stack) {
      debugPrint('BATCH COMMIT FAILED');
      debugPrint('ERROR: $e');
      debugPrint('STACK: $stack');
      rethrow;
    }

    debugPrint('STEP 5: Fetching newly created user profile from Firestore...');
    try {
      final user = await _fetchUser(firebaseUser.uid);
      debugPrint('PROFILE FETCH SUCCESS');
      return user;
    } catch (e, stack) {
      debugPrint('STEP 6 ERROR: Fetching user profile failed: $e');
      debugPrint('ERROR: $e');
      debugPrintStack(stackTrace: stack);
      rethrow;
    }
  }

  Future<void> logout() async {
    if (firebaseAvailable) {
      await _auth.signOut();
    }
  }

  /// Creates a Firebase Auth account for a member without disrupting the
  /// admin's active session. Uses a secondary [FirebaseApp] instance so that
  /// [createUserWithEmailAndPassword] does not sign the admin out.
  ///
  /// Returns the new user's UID which should be used as the Firestore doc ID.
  Future<String> createMemberAccount({
    required String email,
    required String temporaryPassword,
  }) async {
    _assertFirebase();
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'memberCreation_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: temporaryPassword,
      );
      final uid = credential.user?.uid;
      if (uid == null) {
        throw StateError('Firebase account was created but no UID was returned.');
      }
      await secondaryAuth.signOut();
      return uid;
    } finally {
      await secondaryApp?.delete();
    }
  }

  /// Sends a password-reset email so the member can set their own password.
  Future<void> sendPasswordReset(String email) async {
    _assertFirebase();
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<AppUser> _fetchUser(String uid) async {
    debugPrint('Fetching User Document');
    debugPrint('UID: $uid');
    final snapshot = await _firestore.collection(FirestorePaths.users).doc(uid).get();
    if (!snapshot.exists || snapshot.data() == null) {
      debugPrint('User exists in Authentication but not in Firestore.');
      throw StateError('Your account exists but no SmartPresence profile was found.');
    }
    
    final userData = snapshot.data()!;
    final orgId = userData['organizationId'] as String? ?? '';
    String? orgType;
    String? orgName;
    if (orgId.isNotEmpty) {
      final orgSnapshot = await _firestore.collection(FirestorePaths.organizations).doc(orgId).get();
      if (orgSnapshot.exists && orgSnapshot.data() != null) {
        final orgData = orgSnapshot.data()!;
        orgType = orgData['organizationType'] as String? ?? orgData['type'] as String?;
        orgName = orgData['name'] as String?;
      }
    }
    
    final mergedData = {
      ...userData,
      'organizationType': ?orgType,
      'organizationName': ?orgName,
    };
    return AppUser.fromMap(snapshot.id, mergedData);
  }

  void _assertFirebase() {
    if (!firebaseAvailable) {
      throw StateError('Firebase is not initialized. Check your Firebase configuration files.');
    }
  }
}
