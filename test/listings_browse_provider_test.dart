import 'package:arua_rentals/features/listings/data/listings_repository.dart';
import 'package:arua_rentals/features/listings/data/listing.dart';
import 'package:arua_rentals/features/listings/data/search_keywords.dart';
import 'package:arua_rentals/features/listings/presentation/listings_browse_provider.dart';
import 'package:arua_rentals/features/listings/presentation/listings_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _UnusedFirebaseAuth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('browse provider loads the next 20-item page without duplicates', () async {
    final firestore = FakeFirebaseFirestore();
    await _addListings(firestore, count: 25);
    final snapshots = await firestore.collection('listings').get();
    final repository = _PagedListingsRepository(
      firestore: firestore,
      items: snapshots.docs.map(Listing.fromFirestore).toList(),
    );
    final container = ProviderContainer(
      overrides: [listingsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(listingsBrowseProvider.future);
    final firstPage = container.read(listingsBrowseProvider).asData!.value;
    expect(firstPage.items, hasLength(20));
    expect(firstPage.hasMore, isTrue);
    expect(firstPage.lastDocument, isNotNull);

    await container.read(listingsBrowseProvider.notifier).loadMore();
    final secondPage = container.read(listingsBrowseProvider).asData!.value;
    expect(secondPage.loadMoreError, isNull);
    expect(secondPage.isLoadingMore, isFalse);
    expect(secondPage.items, hasLength(25));
    expect(secondPage.items.map((listing) => listing.id).toSet(), hasLength(25));
    expect(secondPage.hasMore, isFalse);
  });

  test('filters by category, area, and keyword, then sorts by price', () async {
    final firestore = FakeFirebaseFirestore();
    await _writeListing(firestore, 'cheap', title: 'Room near Oli', price: 100000);
    await _writeListing(firestore, 'mid', title: 'Room by Oli', price: 200000);
    await _writeListing(firestore, 'high', title: 'Room in Oli', price: 300000);
    await _writeListing(
      firestore,
      'other-area',
      title: 'Room elsewhere',
      area: 'Ayivu',
      price: 900000,
    );
    await _writeListing(
      firestore,
      'other-category',
      title: 'Room in Oli',
      category: 'Cleaning',
      price: 800000,
    );
    final container = _container(firestore);
    addTearDown(container.dispose);

    await container.read(listingsBrowseProvider.future);
    await container
        .read(listingsBrowseProvider.notifier)
        .applyFilters(
          category: 'Rentals',
          area: 'Oli',
          keyword: 'room',
          sort: ListingSort.priceHighToLow,
        );

    final result = container.read(listingsBrowseProvider).asData!.value;
    expect(result.items.map((listing) => listing.id), ['high', 'mid', 'cheap']);
    expect(result.category, 'Rentals');
    expect(result.area, 'Oli');
    expect(result.keyword, 'room');
    expect(result.sort, ListingSort.priceHighToLow);
  });
}

class _PagedListingsRepository extends ListingsRepository {
  _PagedListingsRepository({
    required FakeFirebaseFirestore firestore,
    required this.items,
  }) : _firestore = firestore,
       super(firestore: firestore, firebaseAuth: _UnusedFirebaseAuth());

  final FakeFirebaseFirestore _firestore;
  final List<Listing> items;

  @override
  Future<ListingPage> getApprovedListings({
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    String? category,
    String? area,
    String? keyword,
    ListingSort sort = ListingSort.newest,
  }) async {
    final offset = startAfter == null ? 0 : limit;
    final pageItems = items.skip(offset).take(limit).toList();
    final lastDocument = pageItems.isEmpty
        ? null
        : await _firestore.collection('listings').doc(pageItems.last.id).get();
    return ListingPage(items: pageItems, lastDocument: lastDocument);
  }
}

ProviderContainer _container(FakeFirebaseFirestore firestore) {
  final repository = ListingsRepository(
    firestore: firestore,
    firebaseAuth: _UnusedFirebaseAuth(),
  );
  return ProviderContainer(
    overrides: [listingsRepositoryProvider.overrideWithValue(repository)],
  );
}

Future<void> _addListings(
  FakeFirebaseFirestore firestore, {
  required int count,
}) async {
  for (var index = 0; index < count; index++) {
    await _writeListing(
      firestore,
      'listing-$index',
      title: 'Room Listing $index',
      price: 100000 + index,
      createdAt: Timestamp.fromMillisecondsSinceEpoch(index * 1000),
    );
  }
}

Future<void> _writeListing(
  FakeFirebaseFirestore firestore,
  String id, {
  required String title,
  required int price,
  String category = 'Rentals',
  String area = 'Oli',
  Timestamp? createdAt,
}) async {
  await firestore.collection('listings').doc(id).set({
    'ownerId': 'owner-$id',
    'ownerName': 'Listing owner',
    'ownerPhone': '+256700000000',
    'type': 'property',
    'category': category,
    'title': title,
    'titleLower': title.toLowerCase(),
    'description': 'A test listing.',
    'priceUgx': price,
    'priceUnit': 'month',
    'area': area,
    'amenities': <String>[],
    'imageUrls': <String>[],
    'thumbnailUrl': 'https://example.test/listing.jpg',
    'status': 'approved',
    'ratingAvg': 0,
    'ratingCount': 0,
    'searchKeywords': generateListingSearchKeywords(
      title: title,
      category: category,
      area: area,
    ),
    'isFeatured': false,
    'createdAt': createdAt ?? Timestamp.fromDate(DateTime.utc(2026)),
    'updatedAt': Timestamp.fromDate(DateTime.utc(2026)),
  });
}
