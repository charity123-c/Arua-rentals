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
import 'package:arua_rentals/features/listings/data/app_config.dart';
import 'package:arua_rentals/features/listings/data/listing.dart';
import 'package:arua_rentals/features/listings/data/listings_repository.dart';
import 'package:arua_rentals/features/listings/presentation/app_config_providers.dart';
import 'package:arua_rentals/features/listings/presentation/listing_detail_screen.dart';
import 'package:arua_rentals/features/listings/presentation/public_listings_screen.dart';
import 'package:arua_rentals/features/listings/presentation/listings_browse_provider.dart';
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
        appConfigProvider.overrideWith(
          (ref) async => const AppConfig(categories: [], areas: []),
        ),
        featuredListingsProvider.overrideWith((ref) async => []),
        listingsBrowseProvider.overrideWith(_EmptyBrowseController.new),
        listingDetailProvider.overrideWith((ref, id) async => _testListing(id)),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  testWidgets('unauthenticated visitors can browse the public home', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AruaCityFinderApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PublicListingsScreen), findsOneWidget);
    expect(find.text('Arua City Finder'), findsOneWidget);
  });

  testWidgets('signed-out visitors can open a shared listing link', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AruaCityFinderApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    container.read(appRouterProvider).go('/listing/public-listing');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(ListingDetailScreen), findsOneWidget);
    expect(find.text('Test listing'), findsWidgets);
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
    await tester.tap(find.text('Register'));
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
    appConfigProvider.overrideWith(
      (ref) async => const AppConfig(categories: [], areas: []),
    ),
    featuredListingsProvider.overrideWith((ref) async => []),
    listingsBrowseProvider.overrideWith(_EmptyBrowseController.new),
    listingDetailProvider.overrideWith((ref, id) async => _testListing(id)),
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

class _EmptyBrowseController extends ListingsBrowseController {
  @override
  Future<ListingsBrowseState> build() async => const ListingsBrowseState(
    items: [],
    category: null,
    area: null,
    keyword: null,
    sort: ListingSort.newest,
    hasMore: false,
  );
}

Listing _testListing(String id) => Listing(
  id: id,
  ownerId: 'owner-id',
  ownerName: 'Listing owner',
  ownerPhone: '+256701234567',
  type: ListingType.property,
  category: 'Rentals',
  title: 'Test listing',
  description: 'A test listing.',
  priceUgx: 350000,
  priceUnit: ListingPriceUnit.month,
  area: 'Oli',
  amenities: const [],
  imageUrls: const [],
  thumbnailUrl: 'https://example.test/listing.jpg',
  searchKeywords: const [],
  status: ListingStatus.approved,
  ratingAvg: 0,
  ratingCount: 0,
  isFeatured: false,
);
