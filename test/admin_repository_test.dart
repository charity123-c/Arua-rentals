import 'package:arua_rentals/features/admin/data/admin_repository.dart';
import 'package:arua_rentals/features/auth/data/app_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestAuthUser implements User {
  @override
  String get uid => 'admin-uid';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestFirebaseAuth implements FirebaseAuth {
  @override
  User? get currentUser => _TestAuthUser();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeFirebaseFirestore firestore;
  late AdminRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = AdminRepository(
      firestore: firestore,
      firebaseAuth: _TestFirebaseAuth(),
    );
  });

  Future<void> seedPendingRequest(String uid) async {
    await firestore.collection('users').doc(uid).set({
      'name': 'Arua User',
      'email': '$uid@example.com',
      'phone': '+256701234567',
      'role': 'tenant',
      'roleRequest': 'landlord',
      'photoUrl': null,
      'fcmTokens': <String>[],
      'isVerified': false,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
    await firestore.collection('role_requests').doc(uid).set({
      'uid': uid,
      'requestedRole': 'landlord',
      'status': 'pending',
      'name': 'Arua User',
      'email': '$uid@example.com',
      'phone': '+256701234567',
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
  }

  test('approval updates the request and user role atomically', () async {
    await seedPendingRequest('landlord-candidate');

    await repository.approveRoleRequest(
      'landlord-candidate',
      RoleRequest.landlord,
    );

    final request = await firestore
        .collection('role_requests')
        .doc('landlord-candidate')
        .get();
    final user = await firestore
        .collection('users')
        .doc('landlord-candidate')
        .get();
    expect(request.data()?['status'], 'approved');
    expect(request.data()?['reviewedBy'], 'admin-uid');
    expect(user.data()?['role'], 'landlord');
    expect(user.data()?.containsKey('roleRequest'), isFalse);
  });

  test('rejection keeps the profile a tenant and records a reason', () async {
    await seedPendingRequest('rejected-candidate');

    await repository.rejectRoleRequest(
      'rejected-candidate',
      'Please provide more information.',
    );

    final request = await firestore
        .collection('role_requests')
        .doc('rejected-candidate')
        .get();
    final user = await firestore
        .collection('users')
        .doc('rejected-candidate')
        .get();
    expect(request.data()?['status'], 'rejected');
    expect(
      request.data()?['rejectionReason'],
      'Please provide more information.',
    );
    expect(user.data()?['role'], 'tenant');
    expect(user.data()?.containsKey('roleRequest'), isFalse);
  });

  test('admin dashboard queries return typed role-request records', () async {
    await seedPendingRequest('pending-candidate');

    final page = await repository.getPendingRoleRequests();

    expect(page.items, hasLength(1));
    expect(page.items.single.uid, 'pending-candidate');
    expect(page.items.single.requestedRole, RoleRequest.landlord);
    expect(page.lastDocument?.id, 'pending-candidate');
  });

  test('dashboard statistics count users and listing statuses', () async {
    await seedPendingRequest('pending-user');
    await firestore.collection('users').doc('second-user').set({
      'name': 'Second User',
      'email': 'second@example.com',
      'phone': '',
      'role': 'tenant',
      'isVerified': false,
      'createdAt': Timestamp.now(),
    });
    await firestore.collection('listings').doc('pending-listing').set({
      'status': 'pending',
    });
    await firestore.collection('listings').doc('approved-listing').set({
      'status': 'approved',
    });
    await firestore.collection('listings').doc('rejected-listing').set({
      'status': 'rejected',
    });

    final stats = await repository.getDashboardStats();

    expect(stats.totalUsers, 2);
    expect(stats.pendingRoleRequests, 1);
    expect(stats.pendingListings, 1);
    expect(stats.approvedListings, 1);
    expect(stats.rejectedListings, 1);
  });

  test('the user management API cannot assign admin role', () async {
    await firestore.collection('users').doc('target').set({'role': 'tenant'});

    await expectLater(
      repository.updateUserRole('target', UserRole.admin),
      throwsA(isA<Exception>()),
    );
    expect(
      (await firestore.collection('users').doc('target').get()).data()?['role'],
      'tenant',
    );
  });
}
