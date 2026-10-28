import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:arua_rentals/features/favorites/data/favorites_repository.dart';
import 'package:arua_rentals/features/listings/data/listing.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FavoritesRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = FavoritesRepository(firestore: firestore);
  });

  test('saves and removes a typed favorite snapshot', () async {
    final listing = _listing();

    await repository.setSaved('user-1', listing, saved: true);
    final favorite = await firestore
        .collection('favorites')
        .doc('user-1')
        .collection('items')
        .doc(listing.id)
        .get();

    expect(await repository.isSaved('user-1', listing.id), isTrue);
    expect(FavoriteListing.fromFirestore(favorite).title, listing.title);
    expect(favorite.data()?['thumbnailUrl'], listing.thumbnailUrl);
    expect(favorite.data()?['priceUgx'], listing.priceUgx);
    expect(favorite.data()?['area'], listing.area);

    await repository.remove('user-1', listing.id);
    expect(await repository.isSaved('user-1', listing.id), isFalse);
  });

  test('favorite list pages are ordered and bounded', () async {
    for (var index = 0; index < 22; index++) {
      await firestore
          .collection('favorites')
          .doc('user-1')
          .collection('items')
          .doc('listing-$index')
          .set({
            'listingId': 'listing-$index',
            'title': 'Listing $index',
            'thumbnailUrl': 'https://example.test/listing.jpg',
            'priceUgx': 350000,
            'area': 'Oli',
            'createdAt': Timestamp.fromMillisecondsSinceEpoch(index * 1000),
          });
    }

    final first = await repository.getPage('user-1');
    final second = await repository.getPage(
      'user-1',
      startAfter: first.lastDocument,
    );

    expect(first.items, hasLength(20));
    expect(first.lastDocument, isNotNull);
    expect(second.items, hasLength(2));
    expect(
      [...first.items, ...second.items].map((item) => item.listingId).toSet(),
      hasLength(22),
    );
  });

  test('availability requires a currently approved listing', () async {
    await firestore.collection('listings').doc('approved').set({
      'status': 'approved',
    });
    await firestore.collection('listings').doc('pending').set({
      'status': 'pending',
    });

    expect(await repository.isListingAvailable('approved'), isTrue);
    expect(await repository.isListingAvailable('pending'), isFalse);
    expect(await repository.isListingAvailable('missing'), isFalse);
  });
}

Listing _listing({String id = 'listing-1', String title = 'Arua room'}) =>
    Listing(
      id: id,
      ownerId: 'owner-1',
      ownerName: 'Owner',
      ownerPhone: '+256700111222',
      type: ListingType.property,
      category: 'Rentals',
      title: title,
      description: 'A test listing.',
      priceUgx: 350000,
      priceUnit: ListingPriceUnit.month,
      area: 'Oli',
      amenities: const [],
      imageUrls: const [],
      thumbnailUrl: 'https://example.test/room.jpg',
      searchKeywords: const [],
      status: ListingStatus.approved,
      ratingAvg: 0,
      ratingCount: 0,
      isFeatured: false,
    );
