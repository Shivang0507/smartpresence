import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import 'directory_item.dart';

class DirectoryRepository {
  DirectoryRepository() : _firestore = FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<DirectoryItem>> watchItems({
    required String organizationId,
    required String collection,
    bool includeInactive = false,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(FirestorePaths.organizations)
        .doc(organizationId)
        .collection(collection);

    if (!includeInactive) {
      query = query.where('isActive', isEqualTo: true);
    }

    return query.snapshots().map((snapshot) {
      final items = snapshot.docs.map((doc) => DirectoryItem.fromMap(doc.id, doc.data())).toList();
      items.sort((a, b) => a.name.compareTo(b.name));
      return items;
    });
  }

  Future<void> saveItem({
    required String organizationId,
    required String collection,
    String? id,
    required DirectoryItem item,
  }) async {
    final ref = id != null && id.isNotEmpty
        ? _firestore
            .collection(FirestorePaths.organizations)
            .doc(organizationId)
            .collection(collection)
            .doc(id)
        : _firestore
            .collection(FirestorePaths.organizations)
            .doc(organizationId)
            .collection(collection)
            .doc();
    await ref.set({
      ...item.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (id == null || id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteItem({
    required String organizationId,
    required String collection,
    required String id,
  }) async {
    await _firestore
        .collection(FirestorePaths.organizations)
        .doc(organizationId)
        .collection(collection)
        .doc(id)
        .delete(); // Hard delete if not in use, or soft delete by marking isActive: false
  }

  Future<void> toggleItemStatus({
    required String organizationId,
    required String collection,
    required String id,
    required bool isActive,
  }) async {
    await _firestore
        .collection(FirestorePaths.organizations)
        .doc(organizationId)
        .collection(collection)
        .doc(id)
        .set({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> isItemInUse({
    required String organizationId,
    required String itemId,
    required String fieldName,
  }) async {
    final query = await _firestore
        .collection('users')
        .where('organizationId', isEqualTo: organizationId)
        .where(fieldName, isEqualTo: itemId)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  Future<bool> isNameDuplicate({
    required String organizationId,
    required String collection,
    required String name,
    String? excludeId,
  }) async {
    final query = await _firestore
        .collection(FirestorePaths.organizations)
        .doc(organizationId)
        .collection(collection)
        .where('name', isEqualTo: name)
        .get();

    for (final doc in query.docs) {
      if (doc.id != excludeId) {
        final isActive = doc.data()['isActive'] as bool? ?? true;
        if (isActive) {
          return true;
        }
      }
    }
    return false;
  }
}
