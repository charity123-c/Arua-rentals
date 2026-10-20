import 'package:cloud_firestore/cloud_firestore.dart';

class RatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add a rating/review for a property or user
  Future<void> addRating({
    required String targetId, // Property ID or User ID being rated
    required String targetType, // 'property', 'landlord', 'service_provider'
    required String raterId,
    required String raterName,
    required int stars,
    required String comment,
  }) async {
    await _firestore.collection('ratings').add({
      'targetId': targetId,
      'targetType': targetType,
      'raterId': raterId,
      'raterName': raterName,
      'stars': stars,
      'comment': comment,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Get average rating and reviews for a target
  Stream<QuerySnapshot> getReviewsStream(String targetId) {
    return _firestore
        .collection('ratings')
        .where('targetId', isEqualTo: targetId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}
