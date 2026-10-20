import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_user.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges,
);

final currentAppUserProvider = FutureProvider<AppUser?>((ref) async {
  final authUser = await ref.watch(authStateProvider.future);
  if (authUser == null) return null;
  return ref.watch(authRepositoryProvider).loadOrCreateUser(authUser);
});

final currentUserRoleProvider = Provider<AsyncValue<UserRole?>>(
  (ref) => ref.watch(currentAppUserProvider).whenData((user) {
    if (user == null) return null;
    if (user.role == UserRole.admin) {
      return user.hasAdminClaim ? UserRole.admin : UserRole.tenant;
    }
    return user.role;
  }),
);

final registrationInProgressProvider =
    NotifierProvider<RegistrationFlowNotifier, bool>(
      RegistrationFlowNotifier.new,
    );

class RegistrationFlowNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setInProgress(bool value) {
    state = value;
  }
}
