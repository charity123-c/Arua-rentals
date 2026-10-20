import 'package:arua_rentals/core/utils/phone_normalizer.dart';
import 'package:arua_rentals/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('email validation', () {
    test('rejects invalid email formats', () {
      expect(validateEmail('not-an-email'), isNotNull);
      expect(validateEmail('person@example.com'), isNull);
    });
  });

  group('password validation', () {
    test('requires at least eight characters', () {
      expect(validatePassword('short'), isNotNull);
      expect(validatePassword('long-enough'), isNull);
    });
  });

  group('Ugandan phone normalization', () {
    test('normalizes local and international numbers to +256', () {
      expect(normalizeUgandanPhone('0701 234 567'), '+256701234567');
      expect(normalizeUgandanPhone('256701234567'), '+256701234567');
      expect(normalizeUgandanPhone('+256 701 234 567'), '+256701234567');
      expect(normalizeUgandanPhone('0123456789'), isNull);
      expect(normalizeUgandanPhone('123'), isNull);
    });
  });
}
