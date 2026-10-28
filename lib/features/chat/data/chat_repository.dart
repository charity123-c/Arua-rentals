import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/collection_names.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/firebase_error_mapper.dart';
import '../../listings/data/listing.dart';

class ChatRoom {
  const ChatRoom({
    required this.id,
    required this.participants,
    required this.listingId,
    required this.listingTitle,
    required this.listingThumb,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
    required this.createdAt,
  });

  final String id;
  final List<String> participants;
  final String listingId;
  final String listingTitle;
  final String listingThumb;
  final String lastMessage;
  final Timestamp lastMessageAt;
  final Map<String, int> unreadCount;
  final Timestamp createdAt;

  int unreadFor(String uid) => unreadCount[uid] ?? 0;
  String otherParticipant(String uid) =>
      participants.firstWhere((participant) => participant != uid);

  factory ChatRoom.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw const AppException('This chat could not be loaded.');
    }
    final participants = data['participants'];
    final unreadCount = data['unreadCount'];
    if (participants is! List ||
        participants.length != 2 ||
        participants.any((participant) => participant is! String) ||
        unreadCount is! Map ||
        data['listingId'] is! String ||
        data['listingTitle'] is! String ||
        data['listingThumb'] is! String ||
        data['lastMessage'] is! String ||
        data['lastMessageAt'] is! Timestamp ||
        data['createdAt'] is! Timestamp) {
      throw const AppException('This chat contains invalid data.');
    }
    return ChatRoom(
      id: snapshot.id,
      participants: List<String>.unmodifiable(participants.cast<String>()),
      listingId: data['listingId'] as String,
      listingTitle: data['listingTitle'] as String,
      listingThumb: data['listingThumb'] as String,
      lastMessage: data['lastMessage'] as String,
      lastMessageAt: data['lastMessageAt'] as Timestamp,
      unreadCount: Map<String, int>.unmodifiable(
        unreadCount.map((key, value) {
          if (key is! String || value is! int || value < 0) {
            throw const AppException('This chat contains invalid unread data.');
          }
          return MapEntry(key, value);
        }),
      ),
      createdAt: data['createdAt'] as Timestamp,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    required this.snapshot,
  });

  final String id;
  final String senderId;
  final String text;
  final Timestamp createdAt;
  final DocumentSnapshot<Map<String, dynamic>> snapshot;

  factory ChatMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null ||
        data['senderId'] is! String ||
        data['text'] is! String ||
        data['createdAt'] is! Timestamp) {
      throw const AppException('A chat message contains invalid data.');
    }
    return ChatMessage(
      id: snapshot.id,
      senderId: data['senderId'] as String,
      text: data['text'] as String,
      createdAt: data['createdAt'] as Timestamp,
      snapshot: snapshot,
    );
  }
}

class ChatMessagePage {
  const ChatMessagePage({required this.items, required this.lastDocument});

  final List<ChatMessage> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
}

class ChatRepository {
  static const pageSize = 30;

  ChatRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _firestore.collection(CollectionNames.chatRooms);

  String roomId(String firstUid, String secondUid, String listingId) {
    final participants = [firstUid, secondUid]..sort();
    return '${participants[0]}_${participants[1]}_$listingId';
  }

  Future<String> openRoom({
    required String currentUid,
    required Listing listing,
  }) async {
    if (currentUid == listing.ownerId) {
      throw const AppException('You cannot chat with yourself.');
    }
    final id = roomId(currentUid, listing.ownerId, listing.id);
    final reference = _rooms.doc(id);
    try {
      await _firestore.runTransaction((transaction) async {
        final existing = await transaction.get(reference);
        if (existing.exists) {
          final room = ChatRoom.fromFirestore(existing);
          if (!room.participants.contains(currentUid) ||
              !room.participants.contains(listing.ownerId) ||
              room.listingId != listing.id) {
            throw const AppException('This chat room is not valid.');
          }
          return;
        }
        final participants = [currentUid, listing.ownerId]..sort();
        transaction.set(reference, {
          'participants': participants,
          'listingId': listing.id,
          'listingTitle': listing.title,
          'listingThumb': listing.thumbnailUrl,
          'lastMessage': '',
          'lastMessageAt': FieldValue.serverTimestamp(),
          'unreadCount': {for (final uid in participants) uid: 0},
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
      return id;
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<ChatRoom> getRoom(String roomId) async {
    try {
      final snapshot = await _rooms.doc(roomId).get();
      if (!snapshot.exists) {
        throw const AppException('This chat no longer exists.');
      }
      return ChatRoom.fromFirestore(snapshot);
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Stream<List<ChatRoom>> watchRooms(String uid) => _rooms
      .where('participants', arrayContains: uid)
      .orderBy('lastMessageAt', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map(ChatRoom.fromFirestore).toList(growable: false),
      );

  Stream<ChatMessagePage> watchRecentMessages(
    String roomId, {
    int limit = 30,
  }) => _rooms
      .doc(roomId)
      .collection(CollectionNames.messages)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(
        (snapshot) => ChatMessagePage(
          items: snapshot.docs
              .map(ChatMessage.fromFirestore)
              .toList(growable: false),
          lastDocument: snapshot.docs.isEmpty ? null : snapshot.docs.last,
        ),
      );

  Future<ChatMessagePage> getOlderMessages(
    String roomId, {
    required DocumentSnapshot<Map<String, dynamic>> startAfter,
    int limit = 30,
  }) async {
    try {
      final snapshot = await _rooms
          .doc(roomId)
          .collection(CollectionNames.messages)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(startAfter)
          .limit(limit)
          .get();
      return ChatMessagePage(
        items: snapshot.docs
            .map(ChatMessage.fromFirestore)
            .toList(growable: false),
        lastDocument: snapshot.docs.isEmpty ? null : snapshot.docs.last,
      );
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<void> markRead(String roomId, String uid) async {
    final reference = _rooms.doc(roomId);
    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(reference);
        if (!snapshot.exists) return;
        final room = ChatRoom.fromFirestore(snapshot);
        if (!room.participants.contains(uid)) {
          throw const AppException('You cannot access this chat.');
        }
        if (room.unreadFor(uid) == 0) return;
        transaction.update(reference, {
          'unreadCount': {...room.unreadCount, uid: 0},
        });
      });
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<void> sendMessage({
    required String roomId,
    required String senderId,
    required String text,
  }) async {
    final normalized = text.trim();
    if (normalized.isEmpty || normalized.length > 1000) {
      throw const AppException('Messages must be 1 to 1000 characters.');
    }
    final roomReference = _rooms.doc(roomId);
    final messageReference = roomReference
        .collection(CollectionNames.messages)
        .doc();
    try {
      await _firestore.runTransaction((transaction) async {
        final roomSnapshot = await transaction.get(roomReference);
        if (!roomSnapshot.exists) {
          throw const AppException('This chat no longer exists.');
        }
        final room = ChatRoom.fromFirestore(roomSnapshot);
        if (!room.participants.contains(senderId)) {
          throw const AppException('You cannot send messages in this chat.');
        }
        final recipient = room.otherParticipant(senderId);
        final unread = Map<String, int>.of(room.unreadCount)
          ..[recipient] = room.unreadFor(recipient) + 1;
        transaction.set(messageReference, {
          'senderId': senderId,
          'text': normalized,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.update(roomReference, {
          'lastMessage': normalized,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'unreadCount': unread,
        });
      });
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }
}
