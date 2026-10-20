import 'dart:async';

import 'package:arua_rentals/app.dart';
import 'package:arua_rentals/core/router/app_router.dart';
import 'package:arua_rentals/features/admin/data/admin_records.dart';
import 'package:arua_rentals/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:arua_rentals/features/admin/presentation/admin_copy.dart';
import 'package:arua_rentals/features/admin/presentation/admin_providers.dart';
import 'package:arua_rentals/features/auth/data/app_user.dart';
import 'package:arua_rentals/features/auth/data/auth_repository.dart';
import 'package:arua_rentals/features/auth/presentation/auth_providers.dart';
import 'package:arua_rentals/features/auth/presentation/login_screen.dart';
import 'package:arua_rentals/features/auth/presentation/register_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestAuthUser implements firebase_auth.User {
  @override
  String get uid => 'test-uid';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnauthenticatedRepository implements AuthRepository {
  @override
  Stream<firebase_auth.User?> get authStateChanges => Stream.value(null);

  @override
  Future<AppUser?> loadUser(String uid, {bool hasAdminClaim = false}) async =>
      null;

  @override
  Future<AppUser> loadOrCreateUser(firebase_auth.User authUser) =>
      throw UnimplementedError();

  @override
  Future<AppUser> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    RoleRequest? roleRequest,
  }) => throw UnimplementedError();

  @override
  Future<void> login({required String email, required String password}) async =>
      throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      throw UnimplementedError();
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(_UnauthenticatedRepository()),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  testWidgets('unauthenticated visitors are sent to login', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AruaCityFinderApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Arua City Finder'), findsOneWidget);
  });

  testWidgets('protected provider route redirects to login', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AruaCityFinderApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/provider');
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('registration only presents role requests, not role assignment', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AruaCityFinderApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.text('I want to list properties or services'), findsOneWidget);
    expect(find.text('Request to join as'), findsNothing);

    await tester.tap(find.text('I want to list properties or services'));
    await tester.pumpAndSettle();
    expect(find.text('Request to join as'), findsOneWidget);
    expect(find.textContaining('remain a tenant account'), findsOneWidget);
  });

  testWidgets('a signed-in tenant is denied the admin route', (tester) async {
    container.dispose();
    container = _signedInContainer(
      const AppUser(
        uid: 'test-uid',
        name: 'Tenant',
        email: 'tenant@example.com',
        phone: '',
        role: UserRole.tenant,
      ),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AruaCityFinderApp(),
      ),
    );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/admin');
    await tester.pumpAndSettle();

    expect(find.byType(AccessDeniedScreen), findsOneWidget);
  });

  testWidgets('an admin with both role and claim lands on the dashboard', (
    tester,
  ) async {
    container.dispose();
    container = _signedInContainer(
      const AppUser(
        uid: 'test-uid',
        name: 'Admin',
        email: 'admin@example.com',
        phone: '',
        role: UserRole.admin,
        hasAdminClaim: true,
      ),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AruaCityFinderApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AdminDashboardScreen), findsOneWidget);
    expect(find.text(AdminCopy.totalUsers), findsOneWidget);
  });
}

ProviderContainer _signedInContainer(AppUser user) => ProviderContainer(
  overrides: [
    authStateProvider.overrideWith((ref) => Stream.value(_TestAuthUser())),
    currentAppUserProvider.overrideWith((ref) async => user),
    adminDashboardStatsProvider.overrideWith(
      (ref) async => const AdminDashboardStats(
        totalUsers: 1,
        pendingRoleRequests: 0,
        pendingListings: 0,
        approvedListings: 0,
        rejectedListings: 0,
      ),
    ),
  ],
);
