import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/auth/data/app_user.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/listings/presentation/provider_listings_screen.dart';
import '../../features/listings/presentation/public_listings_screen.dart';
import '../../features/listings/presentation/listing_detail_screen.dart';
import 'role_access.dart';
import '../theme/app_tokens.dart';
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
      final isPublicPath =
          path == '/' ||
          (state.pathParameters.containsKey('id') &&
              path.startsWith('/listing/'));
      final isAuthPath = const {
        '/login',
        '/register',
        '/forgot-password',
      }.contains(path);
      final authState = ref.read(authStateProvider);

      if (authState.isLoading) {
        if (isPublicPath || isAuthPath) return null;
        return path == '/loading'
            ? null
            : _loadingLocation(state.uri.toString());
      }
      if (authState.hasError) {
        return isPublicPath || isAuthPath
            ? null
            : _loginLocation(state.uri.toString());
      }

      final authUser = authState.value;
      if (authUser == null) {
        if (isPublicPath || isAuthPath) return null;
        return _loginLocation(state.uri.toString());
      }

      if (isAuthPath) {
        if (path == '/register' && ref.read(registrationInProgressProvider)) {
          return null;
        }
        return _safeRedirect(state.uri.queryParameters['redirect']) ??
            _landingPath(ref);
      }

      final userState = ref.read(currentAppUserProvider);
      if (userState.isLoading) {
        if (isPublicPath) return null;
        return path == '/loading'
            ? null
            : _loadingLocation(state.uri.toString());
      }
      if (userState.hasError || userState.value == null) {
        if (path == '/admin') return '/access-denied';
        if (isPublicPath) return null;
        return _loginLocation(state.uri.toString());
      }

      final user = userState.value!;
      final effectiveRole = effectiveRoleFor(
        user.role,
        hasAdminClaim: user.hasAdminClaim,
      );
      if (path == '/' &&
          effectiveRole == UserRole.admin &&
          state.uri.queryParameters['preview'] != 'true') {
        return '/admin';
      }
      if (isPublicPath) return null;
      if (path == '/home') return '/';
      if (path == '/loading') {
        return _safeRedirect(state.uri.queryParameters['redirect']) ??
            _landingPath(ref);
      }
      if (path == '/') return null;
      if (path == '/provider' &&
          effectiveRole != UserRole.landlord &&
          effectiveRole != UserRole.provider) {
        return '/home';
      }
      if (path == '/admin' &&
          !canAccessAdmin(user.role, hasAdminClaim: user.hasAdminClaim)) {
        return '/access-denied';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            _publicPage(state.pageKey, const PublicListingsScreen()),
      ),
      GoRoute(
        path: '/listing/:id',
        pageBuilder: (context, state) => _publicPage(
          state.pageKey,
          ListingDetailScreen(listingId: state.pathParameters['id']!),
        ),
      ),
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
        builder: (context, state) => const PublicListingsScreen(),
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

CustomTransitionPage<void> _publicPage(LocalKey key, Widget child) =>
    CustomTransitionPage<void>(
      key: key,
      child: child,
      transitionDuration: AppMotion.pageTransitionDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );

String _landingPath(Ref ref) {
  final user = ref.read(currentAppUserProvider).asData?.value;
  return user?.role == UserRole.admin && user!.hasAdminClaim ? '/admin' : '/';
}

String _loginLocation(String returnPath) =>
    Uri(path: '/login', queryParameters: {'redirect': returnPath}).toString();

String _loadingLocation(String returnPath) =>
    Uri(path: '/loading', queryParameters: {'redirect': returnPath}).toString();

String? _safeRedirect(String? value) {
  if (value == null || !value.startsWith('/') || value.startsWith('//')) {
    return null;
  }
  if (value == '/login' ||
      value.startsWith('/login?') ||
      value == '/register' ||
      value.startsWith('/register?')) {
    return null;
  }
  return value;
}

class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}
