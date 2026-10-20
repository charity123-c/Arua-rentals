import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/listings_repository.dart';
import '../data/media_uploader.dart';

final listingsRepositoryProvider = Provider<ListingsRepository>(
  (ref) => ListingsRepository(),
);

final mediaUploaderProvider = Provider<MediaUploader>(
  (ref) => UrlMediaUploader(),
);
