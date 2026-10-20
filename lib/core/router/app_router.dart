import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/auth/data/app_user.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/route_placeholders.dart';
import '../../features/listings/presentation/provider_listings_screen.dart';
import 'role_access.dart';
import '../widgets/loading_view.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier();
  ref.listen(authStateProvider, (_, _) => refreshNotifier.refresh());
  ref.listen(currentAppUserProvider, (_, _) => refreshNotifier.refresh());

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final path = state.matchedLocation;
      final isAuthPath = const {
        '/login',
        '/register',
        '/forgot-password',
      }.contains(path);
      final authState = ref.read(authStateProvider);

      if (authState.isLoading) {
        return path == '/loading' ? null : '/loading';
      }
      if (authState.hasError) {
        return isAuthPath ? null : '/login';
      }

      final authUser = authState.value;
      if (authUser == null) {
        if (isAuthPath) return null;
        return '/login';
      }

      if (isAuthPath) {
        if (path == '/register' && ref.read(registrationInProgressProvider)) {
          return null;
        }
        return _landingPath(ref);
      }

      final userState = ref.read(currentAppUserProvider);
      if (userState.isLoading) {
        return path == '/loading' ? null : '/loading';
      }
      if (userState.hasError || userState.value == null) {
        if (path == '/admin') return '/access-denied';
        return path == '/home' ? null : '/home';
      }

      final user = userState.value!;
      final effectiveRole = effectiveRoleFor(
        user.role,
        hasAdminClaim: user.hasAdminClaim,
      );
      if (path == '/' || path == '/loading') return _landingPath(ref);
      if (path == '/provider' &&
          effectiveRole != UserRole.landlord &&
          effectiveRole != UserRole.provider) {
        return '/home';
      }
      if (path == '/admin' &&
          !canAccessAdmin(user.role, hasAdminClaim: user.hasAdminClaim)) {
        return '/access-denied';
      }
      if (path == '/login' || path == '/register' || path == '/forgot-password') {
        return _landingPath(ref);
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SizedBox.shrink()),
      GoRoute(
        path: '/loading',
        builder: (context, state) => const Scaffold(body: LoadingView()),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePlaceholderScreen(),
      ),
      GoRoute(
        path: '/provider',
        builder: (context, state) => const ProviderListingsScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/access-denied',
        builder: (context, state) => const AccessDeniedScreen(),
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refreshNotifier.dispose();
  });
  return router;
});

String _landingPath(Ref ref) {
  final user = ref.read(currentAppUserProvider).asData?.value;
  return user?.role == UserRole.admin && user!.hasAdminClaim
      ? '/admin'
      : '/home';
}

class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}
