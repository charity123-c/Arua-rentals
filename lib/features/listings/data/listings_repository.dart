import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/collection_names.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/firebase_error_mapper.dart';
import 'listing.dart';
import 'search_keywords.dart';

class ListingPage {
  const ListingPage({required this.items, required this.lastDocument});

  final List<Listing> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
}

enum ListingSort { newest, priceLowToHigh, priceHighToLow }

class ListingsRepository {
  ListingsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
    this._adminClaimResolver,
  })
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  final Future<bool> Function(User user)? _adminClaimResolver;

  CollectionReference<Map<String, dynamic>> get _listings =>
      _firestore.collection(CollectionNames.listings);

  Future<Listing> create(Listing listing, {String? ownerId}) async {
    final user = _requireUser();
    try {
      final isAdmin = await _hasAdminClaim(user);
      final effectiveOwnerId = isAdmin ? ownerId ?? user.uid : user.uid;
      final profile = await _firestore
          .collection(CollectionNames.users)
          .doc(effectiveOwnerId)
          .get();
      if (!profile.exists) {
        throw const AppException('The listing owner profile was not found.');
      }
      final profileData = profile.data()!;
      if (!isAdmin &&
          !const ['landlord', 'provider'].contains(profileData['role'])) {
        throw const AppException(
          'Only approved landlords and providers can create listings.',
        );
      }
      final created = listing.copyWith(
        id: listing.id.isEmpty ? _listings.doc().id : listing.id,
        ownerId: effectiveOwnerId,
        ownerName: _stringField(profileData, 'name'),
        ownerPhone: _stringField(profileData, 'phone'),
        ownerVerified: _boolField(profileData, 'isVerified'),
      );
      final status = isAdmin ? ListingStatus.approved : ListingStatus.pending;
      final keywords = _keywords(created);
      await _listings
          .doc(created.id)
          .set(created.toFirestore(status: status, searchKeywords: keywords));
      return created.copyWith(status: status, searchKeywords: keywords);
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<Listing?> getById(String id) async {
    try {
      final snapshot = await _listings.doc(id).get();
      return snapshot.exists ? Listing.fromFirestore(snapshot) : null;
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<ListingPage> getApprovedListings({
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    String? category,
    String? area,
    String? keyword,
    ListingSort sort = ListingSort.newest,
  }) => _getPage(
    _listings.where('status', isEqualTo: ListingStatus.approved.name),
    limit: limit,
    startAfter: startAfter,
    category: category,
    area: area,
    keyword: keyword,
    sort: sort,
  );

  Future<List<Listing>> getFeaturedListings({int limit = 8}) async {
    final pageLimit = _pageLimit(limit);
    try {
      final snapshot = await _listings
          .where('status', isEqualTo: ListingStatus.approved.name)
          .where('isFeatured', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(pageLimit)
          .get();
      return snapshot.docs.map(Listing.fromFirestore).toList(growable: false);
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<ListingPage> getOwnerListings({
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    final uid = _requireUser().uid;
    try {
      var query = _listings
          .where('ownerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(_pageLimit(limit));
      if (startAfter != null) query = query.startAfterDocument(startAfter);
      return _listingPage(await query.get());
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<ListingPage> getAdminListings({
    ListingStatus? status,
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    String? keyword,
  }) async {
    final user = _requireUser();
    try {
      if (!await _hasAdminClaim(user)) {
        throw const AppException('Administrator access is required.');
      }
      Query<Map<String, dynamic>> query = _listings;
      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }
      if (keyword != null && keyword.trim().isNotEmpty) {
        query = query.where(
          'searchKeywords',
          arrayContains: keyword.trim().toLowerCase(),
        );
      }
      query = query
          .orderBy('createdAt', descending: true)
          .limit(_pageLimit(limit));
      if (startAfter != null) query = query.startAfterDocument(startAfter);
      return _listingPage(await query.get());
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<Listing> update(Listing listing) async {
    final user = _requireUser();
    try {
      final existingSnapshot = await _listings.doc(listing.id).get();
      if (!existingSnapshot.exists) {
        throw const AppException('This listing no longer exists.');
      }
      final existing = Listing.fromFirestore(existingSnapshot);
      final isAdmin = await _hasAdminClaim(user);
      if (!isAdmin && existing.ownerId != user.uid) {
        throw const AppException('You can only edit your own listings.');
      }
      final updated = listing.copyWith(
        ownerId: existing.ownerId,
        ratingAvg: existing.ratingAvg,
        ratingCount: existing.ratingCount,
        isFeatured: existing.isFeatured,
        ownerVerified: existing.ownerVerified,
      );
      final status = isAdmin ? existing.status : ListingStatus.pending;
      final keywords = _keywords(updated);
      final updates = updated.toFirestore(
        status: status,
        searchKeywords: keywords,
      )..remove('createdAt');
      for (final field in [
        'address',
        'geo',
        'bedrooms',
        'bathrooms',
        'videoUrl',
      ]) {
        if (!updates.containsKey(field)) {
          updates[field] = FieldValue.delete();
        }
      }
      if (!isAdmin) updates['rejectionReason'] = FieldValue.delete();
      await _listings.doc(listing.id).update(updates);
      return updated.copyWith(
        status: status,
        searchKeywords: keywords,
        clearRejectionReason: !isAdmin,
      );
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<void> delete(String id) async {
    final user = _requireUser();
    try {
      final snapshot = await _listings.doc(id).get();
      if (!snapshot.exists) return;
      final isAdmin = await _hasAdminClaim(user);
      if (!isAdmin && snapshot.data()?['ownerId'] != user.uid) {
        throw const AppException('You can only delete your own listings.');
      }
      await snapshot.reference.delete();
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<void> setStatus(
    String id,
    ListingStatus status, {
    String? rejectionReason,
  }) async {
    final user = _requireUser();
    final reason = rejectionReason?.trim();
    if (status == ListingStatus.rejected &&
        (reason == null || reason.isEmpty || reason.length > 500)) {
      throw const AppException(
        'Enter a rejection reason of 1 to 500 characters.',
      );
    }
    try {
      if (!await _hasAdminClaim(user)) {
        throw const AppException('Administrator access is required.');
      }
      final updates = <String, dynamic>{
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (status == ListingStatus.rejected) {
        updates['rejectionReason'] = reason;
      } else {
        updates['rejectionReason'] = FieldValue.delete();
      }
      await _listings.doc(id).update(updates);
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<ListingPage> _getPage(
    Query<Map<String, dynamic>> query, {
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    String? category,
    String? area,
    String? keyword,
    ListingSort sort = ListingSort.newest,
  }) async {
    try {
      if (category != null) {
        query = query.where('category', isEqualTo: category);
      }
      if (area != null) query = query.where('area', isEqualTo: area);
      if (keyword != null && keyword.trim().isNotEmpty) {
        query = query.where(
          'searchKeywords',
          arrayContains: keyword.trim().toLowerCase(),
        );
      }
      query = _orderedQuery(query, sort).limit(_pageLimit(limit));
      if (startAfter != null) query = query.startAfterDocument(startAfter);
      return _listingPage(await query.get());
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Query<Map<String, dynamic>> _orderedQuery(
    Query<Map<String, dynamic>> query,
    ListingSort sort,
  ) => switch (sort) {
    ListingSort.newest => query.orderBy('createdAt', descending: true),
    ListingSort.priceLowToHigh =>
      query.orderBy('priceUgx').orderBy('createdAt', descending: true),
    ListingSort.priceHighToLow =>
      query
          .orderBy('priceUgx', descending: true)
          .orderBy('createdAt', descending: true),
  };

  ListingPage _listingPage(QuerySnapshot<Map<String, dynamic>> snapshot) =>
      ListingPage(
        items: snapshot.docs.map(Listing.fromFirestore).toList(),
        lastDocument: snapshot.docs.isEmpty ? null : snapshot.docs.last,
      );

  List<String> _keywords(Listing listing) => generateListingSearchKeywords(
    title: listing.title,
    category: listing.category,
    area: listing.area,
  );

  User _requireUser() {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AppException('Sign in before managing listings.');
    }
    return user;
  }

  Future<bool> _hasAdminClaim(User user) async {
    final resolver = _adminClaimResolver;
    if (resolver != null) return resolver(user);
    try {
      final result = await user.getIdTokenResult(true);
      return result.claims?['admin'] == true;
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthException(error);
    }
  }

  int _pageLimit(int limit) {
    if (limit < 1 || limit > 100) {
      throw const AppException('Page size must be between 1 and 100.');
    }
    return limit;
  }

  String _stringField(Map<String, dynamic> data, String field) {
    final value = data[field];
    if (value is! String) {
      throw AppException('The listing owner profile has invalid $field data.');
    }
    return value;
  }

  bool _boolField(Map<String, dynamic> data, String field) {
    final value = data[field];
    if (value is! bool) {
      throw AppException('The listing owner profile has invalid $field data.');
    }
    return value;
  }
}
