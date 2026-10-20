List<String> generateListingSearchKeywords({
  required String title,
  required String category,
  required String area,
}) {
  final keywords = <String>{};
  for (final source in [title, category, area]) {
    for (final rawToken in source.toLowerCase().split(RegExp(r'[^a-z0-9]+'))) {
      final token = rawToken.trim();
      if (token.isEmpty) continue;
      for (var length = 1; length <= token.length; length++) {
        keywords.add(token.substring(0, length));
      }
    }
  }
  return keywords.toList()..sort();
}
