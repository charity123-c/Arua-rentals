import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'app_exception.dart';

void logFirebaseError(Object error) {
  if (!kDebugMode) return;

  switch (error) {
    case FirebaseAuthException():
      debugPrint(
        'FirebaseAuthException: code=${error.code}, message=${error.message}',
      );
    case FirebaseException():
      debugPrint(
        'FirebaseException: plugin=${error.plugin}, code=${error.code}, '
        'message=${error.message}',
      );
    default:
      debugPrint('Firebase error: type=${error.runtimeType}, error=$error');
  }
}

AppException mapFirebaseAuthException(FirebaseAuthException error) {
  logFirebaseError(error);
  final message = switch (error.code) {
    'email-already-in-use' => 'An account already exists for this email.',
    'invalid-email' => 'Enter a valid email address.',
    'user-disabled' => 'This account has been disabled. Contact support.',
    'user-not-found' || 'wrong-password' || 'invalid-credential' =>
      'The email or password is incorrect.',
    'weak-password' => 'Choose a stronger password with at least 8 characters.',
    'too-many-requests' => 'Too many attempts. Please wait and try again.',
    'network-request-failed' =>
      'Network connection failed. Check your connection and try again.',
    'operation-not-allowed' =>
      'Email and password sign-in is not enabled for this Firebase project.',
    _ => 'Authentication failed. Please try again.',
  };
  return AppException(message, code: error.code);
}

AppException mapFirestoreException(FirebaseException error) {
  logFirebaseError(error);
  final message = switch (error.code) {
    'email-already-in-use' => 'An account already exists for this email.',
    'invalid-email' => 'Enter a valid email address.',
    'weak-password' => 'Choose a stronger password with at least 8 characters.',
    'network-request-failed' || 'unavailable' || 'deadline-exceeded' =>
      'Network connection failed. Check your connection and try again.',
    'operation-not-allowed' =>
      'This operation is not enabled for the Firebase project.',
    'permission-denied' =>
      'Firestore denied the account profile write. Check the deployed rules.',
    'unauthenticated' =>
      'Your sign-in expired. Sign in again and retry.',
    'too-many-requests' => 'Too many attempts. Please wait and try again.',
    _ => 'Your account profile could not be loaded or saved. Please try again.',
  };
  return AppException(message, code: error.code);
}
