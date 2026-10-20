import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/arua_areas.dart';
import '../../../core/constants/collection_names.dart';
import '../../../core/constants/listing_categories.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/firebase_error_mapper.dart';

class ConfigOption {
  const ConfigOption({
    required this.id,
    required this.label,
    required this.active,
  });

  final String id;
  final String label;
  final bool active;

  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label,
    'active': active,
  };

  factory ConfigOption.fromMap(Map<String, dynamic> data) {
    if (data['id'] is! String ||
        data['label'] is! String ||
        data['active'] is! bool) {
      throw const AppException('The listing configuration contains invalid data.');
    }
    return ConfigOption(
      id: data['id'] as String,
      label: data['label'] as String,
      active: data['active'] as bool,
    );
  }
}

class AppConfig {
  const AppConfig({required this.categories, required this.areas});

  final List<ConfigOption> categories;
  final List<ConfigOption> areas;

  List<String> get activeCategoryLabels => categories
      .where((option) => option.active)
      .map((option) => option.label)
      .toList(growable: false);

  List<String> get activeAreaLabels => areas
      .where((option) => option.active)
      .map((option) => option.label)
      .toList(growable: false);
}

class AppConfigRepository {
  AppConfigRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<AppConfig> load() async {
    try {
      final snapshots = await Future.wait([
        _firestore.collection(CollectionNames.config).doc('categories').get(),
        _firestore.collection(CollectionNames.config).doc('areas').get(),
      ]);
      return AppConfig(
        categories: snapshots[0].exists
            ? _parseOptions(snapshots[0].data(), 'categories')
            : _defaults(listingCategories),
        areas: snapshots[1].exists
            ? _parseOptions(snapshots[1].data(), 'areas')
            : _defaults(aruaAreas),
      );
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<void> saveCategories(List<ConfigOption> options) =>
      _save('categories', options);

  Future<void> saveAreas(List<ConfigOption> options) =>
      _save('areas', options);

  Future<void> seedDefaults() async {
    try {
      final batch = _firestore.batch();
      batch.set(
        _firestore.collection(CollectionNames.config).doc('categories'),
        _documentData(_defaults(listingCategories)),
      );
      batch.set(
        _firestore.collection(CollectionNames.config).doc('areas'),
        _documentData(_defaults(aruaAreas)),
      );
      await batch.commit();
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Future<void> _save(String documentId, List<ConfigOption> options) async {
    _validateOptions(options, documentId);
    try {
      await _firestore
          .collection(CollectionNames.config)
          .doc(documentId)
          .set(_documentData(options));
    } on FirebaseException catch (error) {
      throw mapFirestoreException(error);
    }
  }

  Map<String, dynamic> _documentData(List<ConfigOption> options) => {
    'items': options.map((option) => option.toMap()).toList(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  List<ConfigOption> _parseOptions(Map<String, dynamic>? data, String field) {
    final rawItems = data?['items'];
    if (rawItems is! List || rawItems.any((item) => item is! Map)) {
      throw AppException('The $field configuration is invalid.');
    }
    final options = rawItems
        .map(
          (item) => ConfigOption.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
    _validateOptions(options, field);
    return options;
  }

  void _validateOptions(List<ConfigOption> options, String field) {
    final ids = <String>{};
    for (final option in options) {
      if (option.id.trim().isEmpty ||
          option.label.trim().isEmpty ||
          option.id.length > 80 ||
          option.label.length > 60 ||
          !ids.add(option.id)) {
        throw AppException('The $field configuration contains invalid items.');
      }
    }
  }

  List<ConfigOption> _defaults(List<String> labels) => [
    for (final label in labels)
      ConfigOption(
        id: _idFor(label),
        label: label,
        active: true,
      ),
  ];

  String _idFor(String label) => label
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}
