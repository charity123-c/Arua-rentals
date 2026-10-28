import 'package:arua_rentals/core/errors/app_exception.dart';
import 'package:arua_rentals/features/chat/data/chat_repository.dart';
import 'package:arua_rentals/features/listings/data/listing.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ChatRepository repository;
  late Listing listing;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    repository = ChatRepository(firestore: firestore);
    listing = _listing();
    await firestore.collection('listings').doc(listing.id).set({
      ...listing.toFirestore(
        status: ListingStatus.approved,
        searchKeywords: const [],
      ),
    });
  });

  test('chat room ids are deterministic and self-chat is rejected', () async {
    final first = repository.roomId('alice', 'owner', listing.id);
    final reverse = repository.roomId('owner', 'alice', listing.id);

    expect(first, reverse);
    await expectLater(
      repository.openRoom(currentUid: 'owner-1', listing: listing),
      throwsA(isA<AppException>()),
    );
  });

  test(
    'creates one room and sends messages with unread count updates',
    () async {
      final roomId = await repository.openRoom(
        currentUid: 'alice',
        listing: listing,
      );
      expect(
        await repository.openRoom(currentUid: 'alice', listing: listing),
        roomId,
      );

      await repository.sendMessage(
        roomId: roomId,
        senderId: 'alice',
        text: '  Hello  ',
      );
      final room = await repository.getRoom(roomId);
      final messages = await firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('messages')
          .get();

      expect(room.participants, ['alice', 'owner-1']);
      expect(room.lastMessage, 'Hello');
      expect(room.unreadFor('alice'), 0);
      expect(room.unreadFor('owner-1'), 1);
      expect(messages.docs.single.data()['text'], 'Hello');
    },
  );

  test('rejects empty, oversized, and nonparticipant messages', () async {
    final roomId = await repository.openRoom(
      currentUid: 'alice',
      listing: listing,
    );

    await expectLater(
      repository.sendMessage(roomId: roomId, senderId: 'alice', text: '  '),
      throwsA(isA<AppException>()),
    );
    await expectLater(
      repository.sendMessage(
        roomId: roomId,
        senderId: 'alice',
        text: List.filled(1001, 'x').join(),
      ),
      throwsA(isA<AppException>()),
    );
    await expectLater(
      repository.sendMessage(
        roomId: roomId,
        senderId: 'outsider',
        text: 'Not allowed',
      ),
      throwsA(isA<AppException>()),
    );
  });
}

Listing _listing() => Listing(
  id: 'listing-1',
  ownerId: 'owner-1',
  ownerName: 'Arua Owner',
  ownerPhone: '+256700111222',
  type: ListingType.property,
  category: 'Rentals',
  title: 'Room in Arua',
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
