import 'package:arua_rentals/features/listings/data/listing.dart';
import 'package:arua_rentals/features/listings/data/listings_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestFirebaseAuth implements FirebaseAuth {
  @override
  User? get currentUser => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'featured listings include only approved featured documents in date order',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repository = ListingsRepository(
        firestore: firestore,
        firebaseAuth: _TestFirebaseAuth(),
      );

      await _seedListing(
        firestore,
        id: 'featured-newest',
        status: ListingStatus.approved,
        featured: true,
        createdAt: Timestamp.fromDate(DateTime.utc(2025, 2)),
      );
      await _seedListing(
        firestore,
        id: 'featured-older',
        status: ListingStatus.approved,
        featured: true,
        createdAt: Timestamp.fromDate(DateTime.utc(2025, 1)),
      );
      await _seedListing(
        firestore,
        id: 'regular',
        status: ListingStatus.approved,
        featured: false,
        createdAt: Timestamp.fromDate(DateTime.utc(2025, 3)),
      );
      await _seedListing(
        firestore,
        id: 'pending-featured',
        status: ListingStatus.pending,
        featured: true,
        createdAt: Timestamp.fromDate(DateTime.utc(2025, 4)),
      );

      final results = await repository.getFeaturedListings();

      expect(results.map((listing) => listing.id), [
        'featured-newest',
        'featured-older',
      ]);
    },
  );
}

Future<void> _seedListing(
  FakeFirebaseFirestore firestore, {
  required String id,
  required ListingStatus status,
  required bool featured,
  required Timestamp createdAt,
}) async {
  final listing = Listing(
    id: id,
    ownerId: 'owner',
    ownerName: 'Arua Rentals',
    ownerPhone: '+256700000000',
    type: ListingType.property,
    category: 'Rentals',
    title: id,
    description: 'A test listing.',
    priceUgx: 350000,
    priceUnit: ListingPriceUnit.month,
    area: 'Oli',
    amenities: const [],
    imageUrls: const [],
    thumbnailUrl: '',
    searchKeywords: const [],
    status: status,
    ratingAvg: 0,
    ratingCount: 0,
    isFeatured: featured,
    createdAt: createdAt,
  );
  await firestore
      .collection('listings')
      .doc(id)
      .set(listing.toFirestore(status: status, searchKeywords: const []));
}
