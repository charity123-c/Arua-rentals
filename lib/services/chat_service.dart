import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get or create a chat room between two users
  Future<String> getOrCreateChatRoom(
    String user1Id,
    String user1Name,
    String user2Id,
    String user2Name,
  ) async {
    // Check if room already exists
    QuerySnapshot existingRooms = await _firestore
        .collection('chat_rooms')
        .where('participantIds', arrayContains: user1Id)
        .get();

    for (var doc in existingRooms.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final participantIds = List<String>.from(
        data['participantIds'] ?? <String>[],
      );

      if (participantIds.contains(user2Id)) {
        return doc.id; // Room exists
      }
    }

    // Create new room
    DocumentReference newRoom = await _firestore.collection('chat_rooms').add({
      'participantIds': [user1Id, user2Id],
      'participantNames': {user1Id: user1Name, user2Id: user2Name},
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
    });
    return newRoom.id;
  }

  // Send a message
  Future<void> sendMessage(String roomId, String senderId, String text) async {
    await _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .add({
          'senderId': senderId,
          'text': text,
          'timestamp': FieldValue.serverTimestamp(),
        });

    // Update last message in the room document
    await _firestore.collection('chat_rooms').doc(roomId).update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });
  }

  // Stream messages for a specific room
  Stream<QuerySnapshot> getMessagesStream(String roomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}
