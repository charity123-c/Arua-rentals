import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/ugx_formatter.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_network_image.dart';
import '../data/listing.dart';
import '../../favorites/presentation/favorite_button.dart';
import 'listing_copy.dart';

class ListingCard extends StatelessWidget {
  const ListingCard({
    required this.listing,
    this.isSignedIn = false,
    this.enableHero = true,
    super.key,
  });

  final Listing listing;
  final bool isSignedIn;
  final bool enableHero;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: AppElevation.low,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: InkWell(
        onTap: () => context.go('/listing/${listing.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: AppLayout.listingImageAspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (enableHero)
                    Hero(
                      tag: 'listing-image-${listing.id}',
                      child: AppNetworkImage(
                        imageUrl: listing.thumbnailUrl,
                        semanticLabel: listing.title,
                      ),
                    )
                  else
                    AppNetworkImage(
                      imageUrl: listing.thumbnailUrl,
                      semanticLabel: listing.title,
                    ),
                  Positioned(
                    top: AppSpacing.xs,
                    right: AppSpacing.xs,
                    child: FavoriteButton(
                      listing: listing,
                      isSignedIn: isSignedIn,
                    ),
                  ),
                  if (listing.ownerVerified)
                    Positioned(
                      left: AppSpacing.xs,
                      bottom: AppSpacing.xs,
                      child: _VerifiedBadge(),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${formatUgx(listing.priceUgx)} / ${_priceUnit(listing.priceUnit)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.primaryTextColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${listing.area} · ${listing.category}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                    if (listing.ratingCount > 0) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: AppLayout.statusIconSize,
                            color: colors.tertiary,
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          Text(
                            '${listing.ratingAvg.toStringAsFixed(1)} '
                            '(${listing.ratingCount})',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _priceUnit(ListingPriceUnit unit) => switch (unit) {
    ListingPriceUnit.month => ListingCopy.perMonth,
    ListingPriceUnit.job => ListingCopy.perJob,
    ListingPriceUnit.hour => ListingCopy.perHour,
    ListingPriceUnit.fixed => ListingCopy.fixedPrice,
  };
}

class _VerifiedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_outlined,
            size: AppLayout.statusIconSize,
            color: colors.onTertiaryContainer,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            ListingCopy.verified,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: colors.onTertiaryContainer),
          ),
        ],
      ),
    );
  }
}
