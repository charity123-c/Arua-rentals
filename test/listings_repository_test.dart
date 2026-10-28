import 'package:arua_rentals/core/errors/app_exception.dart';
import 'package:arua_rentals/features/listings/data/listing.dart';
import 'package:arua_rentals/features/listings/data/listings_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestAuthUser implements User {
  @override
  String get uid => 'admin-user';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestFirebaseAuth implements FirebaseAuth {
  @override
  User? get currentUser => _TestAuthUser();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeFirebaseFirestore firestore;
  late ListingsRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = ListingsRepository(
      firestore: firestore,
      firebaseAuth: _TestFirebaseAuth(),
      adminClaimResolver: (_) async => true,
    );
  });

  test('admin-created listings use the target owner profile', () async {
    await firestore.collection('users').doc('target-owner').set({
      'name': 'Target Owner',
      'phone': '+256700111222',
      'isVerified': true,
      'role': 'tenant',
    });

    final created = await repository.create(
      Listing(
        id: '',
        ownerId: 'admin-user',
        ownerName: 'Admin User',
        ownerPhone: '+256700999888',
        type: ListingType.property,
        category: 'Rentals',
        title: 'Room for rent',
        description: 'A room in Arua.',
        priceUgx: 350000,
        priceUnit: ListingPriceUnit.month,
        area: 'Oli',
        amenities: const [],
        imageUrls: const [],
        thumbnailUrl: '',
        searchKeywords: const [],
        status: ListingStatus.pending,
        ratingAvg: 0,
        ratingCount: 0,
        isFeatured: false,
      ),
      ownerId: 'target-owner',
    );

    final stored = await firestore
        .collection('listings')
        .doc(created.id)
        .get();
    expect(created.ownerId, 'target-owner');
    expect(stored.data()?['ownerName'], 'Target Owner');
    expect(stored.data()?['ownerPhone'], '+256700111222');
    expect(stored.data()?['ownerVerified'], isTrue);
    expect(stored.data()?['status'], 'approved');
  });

  test('admin creation fails with a friendly message if the owner is missing', () {
    final future = repository.create(
      Listing(
        id: '',
        ownerId: 'admin-user',
        ownerName: '',
        ownerPhone: '',
        type: ListingType.property,
        category: 'Rentals',
        title: 'Room for rent',
        description: 'A room in Arua.',
        priceUgx: 350000,
        priceUnit: ListingPriceUnit.month,
        area: 'Oli',
        amenities: const [],
        imageUrls: const [],
        thumbnailUrl: '',
        searchKeywords: const [],
        status: ListingStatus.pending,
        ratingAvg: 0,
        ratingCount: 0,
        isFeatured: false,
      ),
      ownerId: 'missing-owner',
    );

    expect(
      future,
      throwsA(
        isA<AppException>().having(
          (error) => error.message,
          'message',
          'The listing owner profile was not found.',
        ),
      ),
    );
  });
}
