import '../../features/auth/data/app_user.dart';

UserRole effectiveRoleFor(UserRole profileRole, {required bool hasAdminClaim}) {
  if (profileRole == UserRole.admin && !hasAdminClaim) {
    return UserRole.tenant;
  }
  return profileRole;
}

bool canAccessAdmin(UserRole profileRole, {required bool hasAdminClaim}) =>
    profileRole == UserRole.admin && hasAdminClaim;
