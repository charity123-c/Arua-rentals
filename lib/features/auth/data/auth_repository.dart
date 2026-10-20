import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../../../core/constants/collection_names.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/firebase_error_mapper.dart';
import 'app_user.dart';

class AuthRepository {
  AuthRepository({
    firebase_auth.FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  }) : _firebaseAuth = firebaseAuth ?? firebase_auth.FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final firebase_auth.FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  Stream<firebase_auth.User?> get authStateChanges =>
      _firebaseAuth.authStateChanges();

  Future<AppUser?> loadUser(String uid, {bool hasAdminClaim = false}) async {
    try {
      final snapshot = await _firestore
          .collection(CollectionNames.users)
          .doc(uid)
          .get();
      return snapshot.exists
          ? AppUser.fromFirestore(snapshot, hasAdminClaim: hasAdminClaim)
          : null;
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<AppUser> loadOrCreateUser(firebase_auth.User authUser) async {
    late final bool hasAdminClaim;
    try {
      final token = await authUser.getIdTokenResult(true);
      hasAdminClaim = token.claims?['admin'] == true;
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw mapFirebaseAuthException(error);
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }

    final existing = await loadUser(authUser.uid, hasAdminClaim: hasAdminClaim);
    if (existing != null) return existing;

    final email = authUser.email;
    if (email == null || email.isEmpty) {
      throw const AppException('The account is missing an email address.');
    }

    final profile = AppUser(
      uid: authUser.uid,
      name: authUser.displayName?.trim().isNotEmpty == true
          ? authUser.displayName!.trim()
          : email.split('@').first,
      email: email,
      phone: authUser.phoneNumber ?? '',
      role: hasAdminClaim ? UserRole.admin : UserRole.tenant,
      isVerified: hasAdminClaim,
      hasAdminClaim: hasAdminClaim,
    );

    try {
      await _firestore
          .collection(CollectionNames.users)
          .doc(authUser.uid)
          .set(profile.toFirestore());
      return profile;
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<AppUser> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    RoleRequest? roleRequest,
  }) async {
    late final firebase_auth.User authUser;
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final createdUser = credential.user;
      if (createdUser == null) {
        throw const AppException('Account creation did not return a user.');
      }
      authUser = createdUser;
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw mapFirebaseAuthException(error);
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }

    final profile = AppUser(
      uid: authUser.uid,
      name: name,
      email: email,
      phone: phone,
      role: UserRole.tenant,
      roleRequest: roleRequest,
    );
    try {
      final batch = _firestore.batch();
      batch.set(
        _firestore.collection(CollectionNames.users).doc(authUser.uid),
        profile.toFirestore(),
      );
      if (roleRequest != null) {
        batch.set(
          _firestore.collection(CollectionNames.roleRequests).doc(authUser.uid),
          {
            'uid': authUser.uid,
            'requestedRole': roleRequest.name,
            'status': 'pending',
            'name': profile.name,
            'email': profile.email,
            'phone': profile.phone,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      }
      await batch.commit();
      return profile;
    } on FirebaseException catch (error) {
      final firestoreException = mapFirestoreException(error);
      try {
        await authUser.delete();
      } on firebase_auth.FirebaseAuthException catch (cleanupError) {
        logFirebaseError(cleanupError);
        throw AppException(
          '${firestoreException.message} The newly created sign-in account '
          'could not be rolled back; contact support before retrying.',
          code: error.code,
        );
      } on FirebaseException catch (cleanupError) {
        logFirebaseError(cleanupError);
        throw AppException(
          '${firestoreException.message} The newly created sign-in account '
          'could not be rolled back; contact support before retrying.',
          code: error.code,
        );
      }
      throw firestoreException;
    }
  }

  Future<void> login({required String email, required String password}) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw mapFirebaseAuthException(error);
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<void> logout() async {
    try {
      await _firebaseAuth.signOut();
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw mapFirebaseAuthException(error);
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw mapFirebaseAuthException(error);
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }
}
