import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/collection_names.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/firebase_error_mapper.dart';
import '../../../core/utils/phone_normalizer.dart';
import '../../auth/data/app_user.dart';
import 'admin_records.dart';

class AdminRepository {
  AdminRepository({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(CollectionNames.users);
  CollectionReference<Map<String, dynamic>> get _roleRequests =>
      _firestore.collection(CollectionNames.roleRequests);
  CollectionReference<Map<String, dynamic>> get _listings =>
      _firestore.collection(CollectionNames.listings);

  String get _adminUid {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) {
      throw const AppException('Sign in with an administrator account first.');
    }
    return uid;
  }

  Future<AdminPage<AdminRoleRequest>> getPendingRoleRequests({
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    try {
      var query = _roleRequests
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(_pageLimit(limit));
      if (startAfter != null) query = query.startAfterDocument(startAfter);
      final snapshot = await query.get();
      return AdminPage(
        items: snapshot.docs.map(AdminRoleRequest.fromSnapshot).toList(),
        lastDocument: snapshot.docs.isEmpty ? null : snapshot.docs.last,
      );
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<AdminPage<AdminListingRecord>> getPendingListings({
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    try {
      var query = _listings
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(_pageLimit(limit));
      if (startAfter != null) query = query.startAfterDocument(startAfter);
      final snapshot = await query.get();
      return AdminPage(
        items: snapshot.docs.map(AdminListingRecord.fromSnapshot).toList(),
        lastDocument: snapshot.docs.isEmpty ? null : snapshot.docs.last,
      );
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<AdminDashboardStats> getDashboardStats() async {
    try {
      final counts = await Future.wait([
        _users.count().get(),
        _roleRequests.where('status', isEqualTo: 'pending').count().get(),
        _listings.where('status', isEqualTo: 'pending').count().get(),
        _listings.where('status', isEqualTo: 'approved').count().get(),
        _listings.where('status', isEqualTo: 'rejected').count().get(),
      ]);
      return AdminDashboardStats(
        totalUsers: counts[0].count ?? 0,
        pendingRoleRequests: counts[1].count ?? 0,
        pendingListings: counts[2].count ?? 0,
        approvedListings: counts[3].count ?? 0,
        rejectedListings: counts[4].count ?? 0,
      );
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<AdminPage<AdminUserRecord>> listUsers({
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    try {
      var query = _users
          .orderBy('createdAt', descending: true)
          .limit(_pageLimit(limit));
      if (startAfter != null) query = query.startAfterDocument(startAfter);
      final snapshot = await query.get();
      return AdminPage(
        items: snapshot.docs.map(AdminUserRecord.fromSnapshot).toList(),
        lastDocument: snapshot.docs.isEmpty ? null : snapshot.docs.last,
      );
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<AdminPage<AdminUserRecord>> searchUsers(
    String searchTerm, {
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    final term = searchTerm.trim();
    if (term.isEmpty) {
      return listUsers(limit: limit, startAfter: startAfter);
    }
    try {
      final cappedLimit = _pageLimit(limit);
      final field = term.contains('@') ? 'email' : 'name';
      var query = _users
          .where(field, isGreaterThanOrEqualTo: term)
          .where(field, isLessThanOrEqualTo: '$term\uf8ff')
          .orderBy(field)
          .limit(cappedLimit);
      if (startAfter != null) query = query.startAfterDocument(startAfter);
      final snapshot = await query.get();
      return AdminPage(
        items: snapshot.docs.map(AdminUserRecord.fromSnapshot).toList(),
        lastDocument: snapshot.docs.isEmpty ? null : snapshot.docs.last,
      );
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<void> approveRoleRequest(String uid, RoleRequest role) async {
    try {
      final requestRef = _roleRequests.doc(uid);
      final userRef = _users.doc(uid);
      final requestSnapshot = await requestRef.get();
      final data = requestSnapshot.data();
      if (!requestSnapshot.exists ||
          data?['status'] != 'pending' ||
          data?['requestedRole'] != role.name) {
        throw const AppException(
          'This role request is no longer pending or the requested role changed.',
        );
      }

      final batch = _firestore.batch();
      batch.update(requestRef, {
        'status': 'approved',
        'reviewedBy': _adminUid,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      batch.update(userRef, {
        'role': role.name,
        'roleRequest': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<void> rejectRoleRequest(String uid, String reason) async {
    final cleanReason = reason.trim();
    if (cleanReason.isEmpty || cleanReason.length > 500) {
      throw const AppException(
        'Enter a rejection reason of 1 to 500 characters.',
      );
    }
    try {
      final requestRef = _roleRequests.doc(uid);
      final userRef = _users.doc(uid);
      final requestSnapshot = await requestRef.get();
      final data = requestSnapshot.data();
      if (!requestSnapshot.exists || data?['status'] != 'pending') {
        throw const AppException('This role request is no longer pending.');
      }

      final batch = _firestore.batch();
      batch.update(requestRef, {
        'status': 'rejected',
        'reviewedBy': _adminUid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'rejectionReason': cleanReason,
      });
      batch.update(userRef, {
        'role': 'tenant',
        'roleRequest': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<void> updateUserRole(String uid, UserRole role) async {
    if (role == UserRole.admin) {
      throw const AppException(
        'Admin access can only be assigned with the trusted bootstrap tool.',
      );
    }
    try {
      await _users.doc(uid).update({
        'role': role.name,
        'roleRequest': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<void> setUserVerified(String uid, bool isVerified) async {
    try {
      final listingSnapshots = await _listings
          .where('ownerId', isEqualTo: uid)
          .get();
      final documents = listingSnapshots.docs;
      var offset = 0;
      do {
        final batch = _firestore.batch();
        var writeCount = 0;
        if (offset == 0) {
          batch.update(_users.doc(uid), {
            'isVerified': isVerified,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          writeCount++;
        }
        final batchEnd = (offset + 400 - writeCount).clamp(0, documents.length);
        for (; offset < batchEnd; offset++) {
          batch.update(documents[offset].reference, {
            'ownerVerified': isVerified,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      } while (offset < documents.length);
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<void> updateUserProfile({
    required String uid,
    required String name,
    required String phone,
  }) async {
    final cleanName = name.trim();
    final cleanPhone = phone.trim().isEmpty ? '' : normalizeUgandanPhone(phone);
    if (cleanName.isEmpty || cleanName.length > 100 || cleanPhone == null) {
      throw const AppException('Enter a valid name and Ugandan phone number.');
    }
    try {
      await _users.doc(uid).update({
        'name': cleanName,
        'phone': cleanPhone,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<void> deleteUserProfile(String uid) async {
    try {
      final user = await _users.doc(uid).get();
      if (user.data()?['role'] == UserRole.admin.name) {
        throw const AppException(
          'An administrator profile cannot be deleted here.',
        );
      }
      // Deleting the Firebase Auth account itself requires the Admin SDK or a
      // Cloud Function and is intentionally out of scope for this client.
      await user.reference.delete();
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<void> approveListing(String listingId) async {
    try {
      await _listings.doc(listingId).update({
        'status': 'approved',
        'rejectionReason': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<void> rejectListing(String listingId, String reason) async {
    final cleanReason = reason.trim();
    if (cleanReason.isEmpty || cleanReason.length > 500) {
      throw const AppException(
        'Enter a rejection reason of 1 to 500 characters.',
      );
    }
    try {
      await _listings.doc(listingId).update({
        'status': 'rejected',
        'rejectionReason': cleanReason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  int _pageLimit(int limit) {
    if (limit < 1 || limit > 100) {
      throw const AppException('Page size must be between 1 and 100.');
    }
    return limit;
  }
}
