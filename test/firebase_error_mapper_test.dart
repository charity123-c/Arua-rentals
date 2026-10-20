import 'package:arua_rentals/core/errors/firebase_error_mapper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Firebase Auth error mapping', () {
    test('maps common registration failures to actionable messages', () {
      expect(
        mapFirebaseAuthException(
          FirebaseAuthException(code: 'email-already-in-use'),
        ).message,
        'An account already exists for this email.',
      );
      expect(
        mapFirebaseAuthException(
          FirebaseAuthException(code: 'invalid-email'),
        ).message,
        'Enter a valid email address.',
      );
      expect(
        mapFirebaseAuthException(
          FirebaseAuthException(code: 'weak-password'),
        ).message,
        'Choose a stronger password with at least 8 characters.',
      );
      expect(
        mapFirebaseAuthException(
          FirebaseAuthException(code: 'operation-not-allowed'),
        ).message,
        'Email and password sign-in is not enabled for this Firebase project.',
      );
      expect(
        mapFirebaseAuthException(
          FirebaseAuthException(code: 'network-request-failed'),
        ).message,
        'Network connection failed. Check your connection and try again.',
      );
      expect(
        mapFirebaseAuthException(
          FirebaseAuthException(code: 'too-many-requests'),
        ).message,
        'Too many attempts. Please wait and try again.',
      );
    });

    test('uses the fallback only for unknown auth codes', () {
      final error = mapFirebaseAuthException(
        FirebaseAuthException(code: 'unknown-auth-code'),
      );
      expect(error.code, 'unknown-auth-code');
      expect(error.message, 'Authentication failed. Please try again.');
    });
  });

  group('Firestore error mapping', () {
    test('maps permission and network failures to actionable messages', () {
      expect(
        mapFirestoreException(
          FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
        ).message,
        'Firestore denied the account profile write. Check the deployed rules.',
      );
      expect(
        mapFirestoreException(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ).message,
        'Network connection failed. Check your connection and try again.',
      );
      expect(
        mapFirestoreException(
          FirebaseException(plugin: 'cloud_firestore', code: 'too-many-requests'),
        ).message,
        'Too many attempts. Please wait and try again.',
      );
    });
  });
}
