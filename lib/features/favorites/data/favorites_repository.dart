import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/collection_names.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/firebase_error_mapper.dart';
import '../../listings/data/listing.dart';

class FavoriteListing {
  const FavoriteListing({
    required this.listingId,
    required this.title,
    required this.thumbnailUrl,
    required this.priceUgx,
    required this.area,
    required this.createdAt,
  });

  final String listingId;
  final String title;
  final String thumbnailUrl;
  final int priceUgx;
  final String area;
  final Timestamp createdAt;

  factory FavoriteListing.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw const AppException('This saved listing could not be loaded.');
    }
    final listingId = data['listingId'];
    final title = data['title'];
    final thumbnailUrl = data['thumbnailUrl'];
    final priceUgx = data['priceUgx'];
    final area = data['area'];
    final createdAt = data['createdAt'];
    if (listingId != snapshot.id ||
        title is! String ||
        thumbnailUrl is! String ||
        priceUgx is! int ||
        area is! String ||
        createdAt is! Timestamp) {
      throw const AppException('This saved listing contains invalid data.');
    }
    return FavoriteListing(
      listingId: listingId,
      title: title,
      thumbnailUrl: thumbnailUrl,
      priceUgx: priceUgx,
      area: area,
      createdAt: createdAt,
    );
  }
}

class FavoriteListingsPage {
  const FavoriteListingsPage({required this.items, required this.lastDocument});

  final List<FavoriteListing> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
}

class FavoritesRepository {
  FavoritesRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _items(String uid) => _firestore
      .collection(CollectionNames.favorites)
      .doc(uid)
      .collection('items');

  Future<bool> isSaved(String uid, String listingId) async {
    try {
      return (await _items(uid).doc(listingId).get()).exists;
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<void> setSaved(
    String uid,
    Listing listing, {
    required bool saved,
  }) async {
    try {
      final reference = _items(uid).doc(listing.id);
      if (!saved) {
        await reference.delete();
        return;
      }
      await reference.set({
        'listingId': listing.id,
        'title': listing.title,
        'thumbnailUrl': listing.thumbnailUrl,
        'priceUgx': listing.priceUgx,
        'area': listing.area,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<void> remove(String uid, String listingId) async {
    try {
      await _items(uid).doc(listingId).delete();
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<FavoriteListingsPage> getPage(
    String uid, {
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    if (limit < 1 || limit > 100) {
      throw const AppException('Page size must be between 1 and 100.');
    }
    try {
      var query = _items(uid).orderBy('createdAt', descending: true);
      if (startAfter != null) query = query.startAfterDocument(startAfter);
      final snapshot = await query.limit(limit).get();
      return FavoriteListingsPage(
        items: snapshot.docs.map(FavoriteListing.fromFirestore).toList(),
        lastDocument: snapshot.docs.isEmpty ? null : snapshot.docs.last,
      );
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<bool> isListingAvailable(String listingId) async {
    try {
      final snapshot = await _firestore
          .collection(CollectionNames.listings)
          .doc(listingId)
          .get();
      return snapshot.exists && snapshot.data()?['status'] == 'approved';
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied' || error.code == 'not-found') {
        return false;
      }
      throw mapFirestoreException(error);
    }
  }
}
