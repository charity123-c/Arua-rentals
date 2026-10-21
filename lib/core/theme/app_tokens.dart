import 'package:flutter/widgets.dart';

abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
}

abstract final class AppElevation {
  static const double none = 0;
  static const double low = 1;
  static const double medium = 2;
}

abstract final class AppLayout {
  static const double contentMaxWidth = 1100;
  static const double wideBreakpoint = 900;
  static const double phoneBreakpoint = 600;
  static const double contactColumnWidth = 210;
  static const double filterMinWidth = 240;
  static const double filterMaxWidth = 420;
  static const double statePlaceholderHeight = 320;
  static const double listingThumbnailSize = 80;
  static const double imagePreviewSize = 72;
  static const double navigationRailWidth = 232;
  static const double overviewLoadingHeight = 420;
  static const double skeletonShortWidth = 180;
  static const double skeletonLongWidth = 240;
  static const double statusIconSize = 16;
  static const double phoneStatCardAspectRatio = 1.35;
  static const double wideStatCardAspectRatio = 1.2;
  static const double minimumTapTarget = 48;
  static const double dividerThickness = 1;
  static const double pageHeaderTextMaxWidth = 720;
  static const double listingGridCardHeight = 352;
  static const double listingGridWideCardHeight = 376;
  static const double listingImageAspectRatio = 4 / 3;
  static const double listingLoadMoreThreshold = 320;
  static const double publicContentMaxWidth = 1200;
  static const double statusPlaceholderIconSize = 44;
  static const double categoryTileWidth = 124;
  static const double categoryTileHeight = 88;
  static const double featuredCardWidth = 248;
  static const double featuredCardHeight = 356;
}

abstract final class AppMotion {
  static const Duration shimmerDuration = Duration(milliseconds: 1100);
  static const Duration pageTransitionDuration = Duration(milliseconds: 280);
}

abstract final class AppInsets {
  static const EdgeInsets phonePage = EdgeInsets.all(AppSpacing.md);
  static const EdgeInsets sectionCard = EdgeInsets.all(AppSpacing.lg);
}
