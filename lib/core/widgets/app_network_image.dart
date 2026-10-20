import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    required this.imageUrl,
    required this.semanticLabel,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String imageUrl;
  final String semanticLabel;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticLabel,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => _imageFallback(context),
        errorWidget: (context, url, error) => _imageFallback(context),
      ),
    );
  }

  Widget _imageFallback(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      color: colors.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: colors.onSurfaceVariant,
      ),
    );
  }
}
