import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/app_exception.dart';

enum ListingType { property, service }

enum ListingStatus { pending, approved, rejected }

enum ListingPriceUnit { month, job, hour, fixed }

class Listing {
  const Listing({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.ownerPhone,
    required this.type,
    required this.category,
    required this.title,
    required this.description,
    required this.priceUgx,
    required this.priceUnit,
    required this.area,
    required this.amenities,
    required this.imageUrls,
    required this.thumbnailUrl,
    required this.searchKeywords,
    required this.status,
    required this.ratingAvg,
    required this.ratingCount,
    required this.isFeatured,
    this.ownerVerified = false,
    this.titleLower,
    this.address,
    this.geo,
    this.bedrooms,
    this.bathrooms,
    this.videoUrl,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String ownerName;
  final String ownerPhone;
  final ListingType type;
  final String category;
  final String title;
  final String? titleLower;
  final String description;
  final int priceUgx;
  final ListingPriceUnit priceUnit;
  final String area;
  final String? address;
  final GeoPoint? geo;
  final int? bedrooms;
  final int? bathrooms;
  final List<String> amenities;
  final List<String> imageUrls;
  final String thumbnailUrl;
  final String? videoUrl;
  final ListingStatus status;
  final String? rejectionReason;
  final double ratingAvg;
  final int ratingCount;
  final List<String> searchKeywords;
  final bool isFeatured;
  final bool ownerVerified;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory Listing.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw const AppException('The listing could not be loaded.');
    }

    T requiredValue<T>(String key) {
      final value = data[key];
      if (value is! T) {
        throw AppException('The listing contains invalid $key data.');
      }
      return value;
    }

    T? optionalValue<T>(String key) {
      final value = data[key];
      if (value == null) return null;
      if (value is! T) {
        throw AppException('The listing contains invalid $key data.');
      }
      return value;
    }

    final type = ListingType.values.where((value) => value.name == data['type']);
    final status =
        ListingStatus.values.where((value) => value.name == data['status']);
    final priceUnit =
        ListingPriceUnit.values.where((value) => value.name == data['priceUnit']);
    final amenities = requiredValue<List>('amenities');
    final imageUrls = requiredValue<List>('imageUrls');
    final searchKeywords = requiredValue<List>('searchKeywords');
    if (type.isEmpty ||
        status.isEmpty ||
        priceUnit.isEmpty ||
        amenities.any((value) => value is! String) ||
        imageUrls.any((value) => value is! String) ||
        searchKeywords.any((value) => value is! String)) {
      throw const AppException('The listing contains invalid data.');
    }

    final price = requiredValue<num>('priceUgx');
    final ratingAvg = requiredValue<num>('ratingAvg');
    final ratingCount = requiredValue<num>('ratingCount');
    final rawOwnerVerified = data['ownerVerified'];
    if (rawOwnerVerified != null && rawOwnerVerified is! bool) {
      throw const AppException('The listing contains invalid ownerVerified data.');
    }
    final createdAt = optionalValue<Timestamp>('createdAt');
    final updatedAt = optionalValue<Timestamp>('updatedAt');

    return Listing(
      id: snapshot.id,
      ownerId: requiredValue<String>('ownerId'),
      ownerName: requiredValue<String>('ownerName'),
      ownerPhone: requiredValue<String>('ownerPhone'),
      type: type.first,
      category: requiredValue<String>('category'),
      title: requiredValue<String>('title'),
      titleLower: optionalValue<String>('titleLower'),
      description: requiredValue<String>('description'),
      priceUgx: price.toInt(),
      priceUnit: priceUnit.first,
      area: requiredValue<String>('area'),
      address: optionalValue<String>('address'),
      geo: optionalValue<GeoPoint>('geo'),
      bedrooms: optionalValue<num>('bedrooms')?.toInt(),
      bathrooms: optionalValue<num>('bathrooms')?.toInt(),
      amenities: List<String>.unmodifiable(amenities.cast<String>()),
      imageUrls: List<String>.unmodifiable(imageUrls.cast<String>()),
      thumbnailUrl: requiredValue<String>('thumbnailUrl'),
      videoUrl: optionalValue<String>('videoUrl'),
      status: status.first,
      rejectionReason: optionalValue<String>('rejectionReason'),
      ratingAvg: ratingAvg.toDouble(),
      ratingCount: ratingCount.toInt(),
      searchKeywords: List<String>.unmodifiable(
        searchKeywords.cast<String>(),
      ),
      isFeatured: requiredValue<bool>('isFeatured'),
      ownerVerified: rawOwnerVerified == true,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toFirestore({
    required ListingStatus status,
    required List<String> searchKeywords,
  }) => {
    'ownerId': ownerId,
    'ownerName': ownerName,
    'ownerPhone': ownerPhone,
    'type': type.name,
    'category': category,
    'title': title,
    'titleLower': title.trim().toLowerCase(),
    'description': description,
    'priceUgx': priceUgx,
    'priceUnit': priceUnit.name,
    'area': area,
    if (address != null) 'address': address,
    if (geo != null) 'geo': geo,
    if (bedrooms != null) 'bedrooms': bedrooms,
    if (bathrooms != null) 'bathrooms': bathrooms,
    'amenities': amenities,
    'imageUrls': imageUrls,
    'thumbnailUrl': thumbnailUrl,
    if (videoUrl != null) 'videoUrl': videoUrl,
    'status': status.name,
    if (rejectionReason != null) 'rejectionReason': rejectionReason,
    'ratingAvg': ratingAvg,
    'ratingCount': ratingCount,
    'searchKeywords': searchKeywords,
    'isFeatured': isFeatured,
    'ownerVerified': ownerVerified,
    'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  Listing copyWith({
    String? id,
    String? ownerId,
    String? ownerName,
    String? ownerPhone,
    ListingType? type,
    String? category,
    String? title,
    String? description,
    int? priceUgx,
    ListingPriceUnit? priceUnit,
    String? area,
    String? address,
    GeoPoint? geo,
    int? bedrooms,
    int? bathrooms,
    List<String>? amenities,
    List<String>? imageUrls,
    String? thumbnailUrl,
    String? videoUrl,
    ListingStatus? status,
    String? rejectionReason,
    double? ratingAvg,
    int? ratingCount,
    List<String>? searchKeywords,
    bool? isFeatured,
    bool? ownerVerified,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    bool clearRejectionReason = false,
  }) => Listing(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    ownerName: ownerName ?? this.ownerName,
    ownerPhone: ownerPhone ?? this.ownerPhone,
    type: type ?? this.type,
    category: category ?? this.category,
    title: title ?? this.title,
    description: description ?? this.description,
    priceUgx: priceUgx ?? this.priceUgx,
    priceUnit: priceUnit ?? this.priceUnit,
    area: area ?? this.area,
    address: address ?? this.address,
    geo: geo ?? this.geo,
    bedrooms: bedrooms ?? this.bedrooms,
    bathrooms: bathrooms ?? this.bathrooms,
    amenities: amenities ?? this.amenities,
    imageUrls: imageUrls ?? this.imageUrls,
    thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    videoUrl: videoUrl ?? this.videoUrl,
    status: status ?? this.status,
    rejectionReason: clearRejectionReason
        ? null
        : rejectionReason ?? this.rejectionReason,
    ratingAvg: ratingAvg ?? this.ratingAvg,
    ratingCount: ratingCount ?? this.ratingCount,
    searchKeywords: searchKeywords ?? this.searchKeywords,
    isFeatured: isFeatured ?? this.isFeatured,
    ownerVerified: ownerVerified ?? this.ownerVerified,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
