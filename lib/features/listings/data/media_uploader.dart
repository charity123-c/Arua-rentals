abstract class MediaUploader {
  Future<List<String>> uploadImages(List<String> imageSources);
}

class UrlMediaUploader implements MediaUploader {
  @override
  Future<List<String>> uploadImages(List<String> imageSources) async {
    if (imageSources.length > 8) {
      throw const FormatException('A listing can have at most 8 images.');
    }
    final urls = <String>[];
    for (final source in imageSources) {
      final value = source.trim();
      final uri = Uri.tryParse(value);
      if (uri == null ||
          !uri.hasScheme ||
          !const {'http', 'https'}.contains(uri.scheme) ||
          uri.host.isEmpty) {
        throw const FormatException('Enter a valid image URL.');
      }
      urls.add(uri.toString());
    }
    // TODO: Replace URL validation with StorageMediaUploader after Blaze is enabled.
    return urls;
  }
}
