import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/app_exception.dart';
import '../../auth/data/app_user.dart';

class AdminPage<T> {
  const AdminPage({required this.items, required this.lastDocument});

  final List<T> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
}

class AdminDashboardStats {
  const AdminDashboardStats({
    required this.totalUsers,
    required this.pendingRoleRequests,
    required this.pendingListings,
    required this.approvedListings,
    required this.rejectedListings,
  });

  final int totalUsers;
  final int pendingRoleRequests;
  final int pendingListings;
  final int approvedListings;
  final int rejectedListings;
}

class AdminRoleRequest {
  const AdminRoleRequest({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.requestedRole,
    required this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final RoleRequest requestedRole;
  final DateTime? createdAt;

  factory AdminRoleRequest.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final requestedRole = RoleRequest.values
        .where((role) => role.name == data['requestedRole'])
        .firstOrNull;
    if (requestedRole == null ||
        data['name'] is! String ||
        data['email'] is! String ||
        data['phone'] is! String) {
      throw const AppException('A role request contains invalid data.');
    }
    final createdAt = data['createdAt'];
    return AdminRoleRequest(
      uid: snapshot.id,
      name: data['name'] as String,
      email: data['email'] as String,
      phone: data['phone'] as String,
      requestedRole: requestedRole,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }
}

class AdminUserRecord {
  const AdminUserRecord({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.isVerified,
    this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final bool isVerified;
  final DateTime? createdAt;

  factory AdminUserRecord.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final rawRole = data['role'];
    final role = UserRole.values
        .where((candidate) => candidate.name == rawRole)
        .firstOrNull;
    if (data['name'] is! String ||
        data['email'] is! String ||
        data['isVerified'] is! bool ||
        role == null) {
      throw const AppException('A user profile contains invalid data.');
    }
    final createdAt = data['createdAt'];
    return AdminUserRecord(
      uid: snapshot.id,
      name: data['name'] as String,
      email: data['email'] as String,
      phone: data['phone'] is String ? data['phone'] as String : '',
      role: role,
      isVerified: data['isVerified'] as bool,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }
}

class AdminListingRecord {
  const AdminListingRecord({
    required this.id,
    required this.title,
    required this.ownerName,
    required this.area,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String ownerName;
  final String area;
  final DateTime? createdAt;

  factory AdminListingRecord.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final createdAt = data['createdAt'];
    return AdminListingRecord(
      id: snapshot.id,
      title: data['title'] is String
          ? data['title'] as String
          : 'Untitled listing',
      ownerName: data['ownerName'] is String ? data['ownerName'] as String : '',
      area: data['area'] is String ? data['area'] as String : '',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }
}
