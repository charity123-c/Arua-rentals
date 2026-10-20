import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/app_exception.dart';

enum UserRole { tenant, landlord, provider, admin }

extension UserRoleValue on UserRole {
  String get value => name;

  static UserRole parse(Object? value) {
    for (final role in UserRole.values) {
      if (role.value == value) return role;
    }
    throw const AppException('The account has an invalid role.');
  }
}

enum RoleRequest { landlord, provider }

class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.roleRequest,
    this.photoUrl,
    this.fcmTokens = const [],
    this.createdAt,
    this.isVerified = false,
    this.hasAdminClaim = false,
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final RoleRequest? roleRequest;
  final String? photoUrl;
  final List<String> fcmTokens;
  final Timestamp? createdAt;
  final bool isVerified;
  final bool hasAdminClaim;

  factory AppUser.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    bool hasAdminClaim = false,
  }) {
    final data = snapshot.data();
    if (data == null) {
      throw const AppException('The account profile could not be loaded.');
    }

    final rawName = data['name'];
    final rawEmail = data['email'];
    final rawPhone = data['phone'];
    final rawRoleRequest = data['roleRequest'];
    final rawIsVerified = data['isVerified'];
    final rawPhotoUrl = data['photoUrl'];
    final rawFcmTokens = data['fcmTokens'];
    final rawCreatedAt = data['createdAt'];
    if (rawName is! String ||
        rawEmail is! String ||
        rawPhone is! String ||
        rawIsVerified is! bool ||
        (rawPhotoUrl != null && rawPhotoUrl is! String) ||
        rawFcmTokens is! List ||
        rawFcmTokens.any((token) => token is! String) ||
        rawCreatedAt is! Timestamp ||
        (rawRoleRequest != null && rawRoleRequest is! String)) {
      throw const AppException('The account profile contains invalid data.');
    }

    final roleRequest = rawRoleRequest == null
        ? null
        : RoleRequest.values
              .where((value) => value.name == rawRoleRequest)
              .firstOrNull;
    if (rawRoleRequest != null && roleRequest == null) {
      throw const AppException('The account role request is invalid.');
    }

    return AppUser(
      uid: snapshot.id,
      name: rawName,
      email: rawEmail,
      phone: rawPhone,
      role: UserRoleValue.parse(data['role']),
      roleRequest: roleRequest,
      photoUrl: rawPhotoUrl is String ? rawPhotoUrl : null,
      fcmTokens: List<String>.unmodifiable(rawFcmTokens.cast<String>()),
      createdAt: rawCreatedAt,
      isVerified: rawIsVerified,
      hasAdminClaim: hasAdminClaim,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'email': email,
    'phone': phone,
    'role': role.value,
    if (roleRequest != null) 'roleRequest': roleRequest!.name,
    'photoUrl': photoUrl,
    'fcmTokens': fcmTokens,
    'isVerified': isVerified,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
