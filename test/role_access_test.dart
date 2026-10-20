import 'package:arua_rentals/core/router/role_access.dart';
import 'package:arua_rentals/features/auth/data/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('admin route role resolution', () {
    test('requires both the admin profile role and custom claim', () {
      expect(canAccessAdmin(UserRole.admin, hasAdminClaim: true), isTrue);
      expect(canAccessAdmin(UserRole.admin, hasAdminClaim: false), isFalse);
      expect(canAccessAdmin(UserRole.tenant, hasAdminClaim: true), isFalse);
    });

    test('a profile role without a claim is treated as tenant in the UI', () {
      expect(
        effectiveRoleFor(UserRole.admin, hasAdminClaim: false),
        UserRole.tenant,
      );
      expect(
        effectiveRoleFor(UserRole.admin, hasAdminClaim: true),
        UserRole.admin,
      );
      expect(
        effectiveRoleFor(UserRole.landlord, hasAdminClaim: true),
        UserRole.landlord,
      );
    });
  });
}
