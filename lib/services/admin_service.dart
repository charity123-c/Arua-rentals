import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. Get ALL listings (Pending and Approved)
  Stream<QuerySnapshot> getAllListings() {
    return _firestore
        .collection('listings')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // 2. Approve or Reject a listing
  Future<void> updateListingStatus(String docId, bool isApproved) async {
    await _firestore.collection('listings').doc(docId).update({
      'isApproved': isApproved,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  // 3. Delete a listing permanently
  Future<void> deleteListing(String docId) async {
    await _firestore.collection('listings').doc(docId).delete();
  }

  // 4. Get basic stats for the dashboard
  Future<Map<String, int>> getDashboardStats() async {
    final listingsCount = await _firestore.collection('listings').count().get();
    // Add users count later when you set up the users collection
    return {
      'totalListings': listingsCount.count ?? 0,
      'totalUsers': 0, // Placeholder
    };
  }
}
