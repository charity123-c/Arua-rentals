import 'package:arua_rentals/features/listings/data/listing.dart';
import 'package:arua_rentals/features/listings/data/listings_repository.dart';
import 'package:arua_rentals/features/listings/presentation/listing_card.dart';
import 'package:arua_rentals/features/listings/presentation/listing_empty_state.dart';
import 'package:arua_rentals/features/listings/presentation/public_listings_screen.dart';
import 'package:arua_rentals/features/listings/presentation/listings_browse_provider.dart';
import 'package:arua_rentals/features/listings/presentation/app_config_providers.dart';
import 'package:arua_rentals/features/listings/data/app_config.dart';
import 'package:arua_rentals/features/auth/presentation/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('listing card shows the listing title and formatted UGX price', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                height: 376,
                child: ListingCard(listing: _listing(ownerVerified: true)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Two-bedroom rental'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('UGX 350,000 / month'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
  });

  testWidgets('signed-out browse shows denormalized Verified badge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          currentAppUserProvider.overrideWith((ref) async => null),
          appConfigProvider.overrideWith(
            (ref) async => const AppConfig(categories: [], areas: []),
          ),
          featuredListingsProvider.overrideWith((ref) async => []),
          listingsBrowseProvider.overrideWith(_LoadedBrowseController.new),
        ],
        child: const MaterialApp(home: PublicListingsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Verified'), findsOneWidget);
  });

  testWidgets('empty state offers a clear-filters action', (tester) async {
    var cleared = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListingEmptyState(onClearFilters: () => cleared = true),
        ),
      ),
    );

    expect(find.text('No listings match your search'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    expect(cleared, isTrue);
  });

  testWidgets('public listing grid fits phone and wide layouts', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(360, 800), const Size(1280, 900)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(size),
          overrides: [
            currentAppUserProvider.overrideWith((ref) async => null),
            appConfigProvider.overrideWith(
              (ref) async => const AppConfig(categories: [], areas: []),
            ),
            featuredListingsProvider.overrideWith((ref) async => []),
            listingsBrowseProvider.overrideWith(_LoadedBrowseController.new),
          ],
          child: const MaterialApp(home: PublicListingsScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Two-bedroom rental'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('home shows featured and public landing sections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          currentAppUserProvider.overrideWith((ref) async => null),
          appConfigProvider.overrideWith(
            (ref) async => const AppConfig(
              categories: [
                ConfigOption(id: 'rentals', label: 'Rentals', active: true),
              ],
              areas: [],
            ),
          ),
          featuredListingsProvider.overrideWith(
            (ref) async => [_listing(ownerVerified: true)],
          ),
          listingsBrowseProvider.overrideWith(_LoadedBrowseController.new),
        ],
        child: const MaterialApp(home: PublicListingsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Find a place to call home in Arua'), findsOneWidget);
    expect(find.text('Rentals'), findsWidgets);
    expect(find.text('Featured'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Latest listings'), findsOneWidget);
    expect(find.text('Are you a landlord or provider?'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _LoadedBrowseController extends ListingsBrowseController {
  @override
  Future<ListingsBrowseState> build() async => ListingsBrowseState(
    items: [_listing(ownerVerified: true)],
    category: null,
    area: null,
    keyword: null,
    sort: ListingSort.newest,
    hasMore: false,
  );
}

Listing _listing({bool ownerVerified = false}) => Listing(
  id: 'listing-id',
  ownerId: 'owner-id',
  ownerName: 'Arua Rentals',
  ownerPhone: '+256700000000',
  type: ListingType.property,
  category: 'Rentals',
  title: 'Two-bedroom rental',
  description: 'A comfortable rental home.',
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
  ownerVerified: ownerVerified,
);
