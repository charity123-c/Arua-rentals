import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/ugx_formatter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../auth/data/app_user.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../chat/presentation/chat_providers.dart';
import '../../favorites/presentation/favorite_button.dart';
import '../data/listing.dart';
import 'listing_copy.dart';
import 'listings_providers.dart';
import 'sign_in_prompt.dart';

final listingDetailProvider = FutureProvider.family<Listing?, String>(
  (ref, id) => ref.watch(listingsRepositoryProvider).getById(id),
);

class ListingDetailScreen extends ConsumerWidget {
  const ListingDetailScreen({required this.listingId, super.key});

  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingState = ref.watch(listingDetailProvider(listingId));
    final user = ref.watch(currentAppUserProvider).asData?.value;
    final isSignedIn = ref.watch(authStateProvider).asData?.value != null;
    return listingState.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text(ListingCopy.listingDetails)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => _unavailable(context),
      data: (listing) {
        if (listing == null) return _unavailable(context);
        final canViewUnapproved = _canViewUnapproved(listing, user);
        if (listing.status != ListingStatus.approved && !canViewUnapproved) {
          return _unavailable(context);
        }
        return _detailPage(context, listing, user, isSignedIn);
      },
    );
  }

  bool _canViewUnapproved(Listing listing, AppUser? user) =>
      user != null &&
      (listing.ownerId == user.uid ||
          (user.role == UserRole.admin && user.hasAdminClaim));

  Widget _unavailable(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(ListingCopy.listingDetails)),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.home_work_outlined,
              size: AppLayout.statusPlaceholderIconSize,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              ListingCopy.listingNotAvailable,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.arrow_back),
              label: const Text(ListingCopy.backToHome),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _detailPage(
    BuildContext context,
    Listing listing,
    AppUser? user,
    bool isSignedIn,
  ) {
    final images = listing.imageUrls.isEmpty
        ? [listing.thumbnailUrl]
        : listing.imageUrls;
    return Title(
      title: listing.title,
      color: AppTheme.primaryTextColor,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            listing.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [FavoriteButton(listing: listing, isSignedIn: isSignedIn)],
        ),
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.publicContentMaxWidth,
              ),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (listing.status == ListingStatus.pending &&
                              _canViewUnapproved(listing, user))
                            const _PendingApprovalBanner(),
                          _ListingImageGallery(
                            listing: listing,
                            images: images,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            listing.title,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${formatUgx(listing.priceUgx)} / '
                            '${_priceUnit(listing.priceUnit)}',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: [
                              Chip(label: Text(listing.category)),
                              Chip(
                                avatar: const Icon(Icons.location_on_outlined),
                                label: Text(listing.area),
                              ),
                              Chip(
                                label: Text(
                                  listing.type == ListingType.property
                                      ? ListingCopy.property
                                      : ListingCopy.service,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _DetailSection(
                            title: ListingCopy.description,
                            child: Text(
                              listing.description.trim().isEmpty
                                  ? ListingCopy.noDescription
                                  : listing.description,
                            ),
                          ),
                          if (listing.amenities.isNotEmpty)
                            _DetailSection(
                              title: ListingCopy.amenityLabel,
                              child: Wrap(
                                spacing: AppSpacing.xs,
                                runSpacing: AppSpacing.xs,
                                children: [
                                  for (final amenity in listing.amenities)
                                    Chip(label: Text(amenity)),
                                ],
                              ),
                            ),
                          if (listing.type == ListingType.property &&
                              (listing.bedrooms != null ||
                                  listing.bathrooms != null))
                            _DetailSection(
                              title: ListingCopy.details,
                              child: Wrap(
                                spacing: AppSpacing.lg,
                                runSpacing: AppSpacing.sm,
                                children: [
                                  if (listing.bedrooms != null)
                                    _PropertyFact(
                                      icon: Icons.bed_outlined,
                                      label: ListingCopy.bedroomsLabel,
                                      value: '${listing.bedrooms}',
                                    ),
                                  if (listing.bathrooms != null)
                                    _PropertyFact(
                                      icon: Icons.bathtub_outlined,
                                      label: ListingCopy.bathroomsLabel,
                                      value: '${listing.bathrooms}',
                                    ),
                                ],
                              ),
                            ),
                          _OwnerSummary(listing: listing),
                          _ratingSummary(context, listing),
                          if (listing.createdAt != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.lg,
                                bottom: AppSpacing.xl,
                              ),
                              child: Text(
                                '${ListingCopy.posted} '
                                '${DateFormat.yMMMd().format(listing.createdAt!.toDate())}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: _ContactBar(
          listing: listing,
          isSignedIn: isSignedIn,
          returnPath: GoRouterState.of(context).uri.toString(),
        ),
      ),
    );
  }

  Widget _ratingSummary(BuildContext context, Listing listing) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (listing.ratingCount > 0)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, color: Theme.of(context).colorScheme.tertiary),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '${listing.ratingAvg.toStringAsFixed(1)} '
                  '(${listing.ratingCount} ${ListingCopy.ratingLabel})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          if (listing.ratingCount == 0)
            Text(
              ListingCopy.noRatingsYet,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
        ],
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

class _ListingImageGallery extends StatefulWidget {
  const _ListingImageGallery({required this.listing, required this.images});

  final Listing listing;
  final List<String> images;

  @override
  State<_ListingImageGallery> createState() => _ListingImageGalleryState();
}

class _ListingImageGalleryState extends State<_ListingImageGallery> {
  int _pageIndex = 0;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AspectRatio(
        aspectRatio: AppLayout.listingImageAspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: PageView.builder(
            itemCount: widget.images.length,
            onPageChanged: (index) => setState(() => _pageIndex = index),
            itemBuilder: (context, index) {
              final image = AppNetworkImage(
                imageUrl: widget.images[index],
                semanticLabel:
                    '${widget.listing.title}, ${ListingCopy.imageIndicator} '
                    '${index + 1} of ${widget.images.length}',
              );
              return index == 0
                  ? Hero(
                      tag: 'listing-image-${widget.listing.id}',
                      child: image,
                    )
                  : image;
            },
          ),
        ),
      ),
      if (widget.images.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 0; index < widget.images.length; index++)
                Container(
                  width: AppSpacing.xs,
                  height: AppSpacing.xs,
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == _pageIndex
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
        ),
    ],
  );
}

class _PendingApprovalBanner extends StatelessWidget {
  const _PendingApprovalBanner();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: AppSpacing.md),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Row(
      children: [
        Icon(
          Icons.schedule,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          ListingCopy.pendingApproval,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
      ],
    ),
  );
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    ),
  );
}

class _PropertyFact extends StatelessWidget {
  const _PropertyFact({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, semanticLabel: label),
      const SizedBox(width: AppSpacing.xs),
      Text('$value $label'),
    ],
  );
}

class _OwnerSummary extends StatelessWidget {
  const _OwnerSummary({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg),
    child: Row(
      children: [
        CircleAvatar(
          child: Text(
            listing.ownerName.trim().isEmpty
                ? ListingCopy.appName.substring(0, 1)
                : listing.ownerName.trim()[0],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            listing.ownerName,
            style: Theme.of(context).textTheme.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (listing.ownerVerified)
          Chip(
            avatar: const Icon(Icons.verified_outlined),
            label: const Text(ListingCopy.verified),
          ),
      ],
    ),
  );
}

class _ContactBar extends ConsumerWidget {
  const _ContactBar({
    required this.listing,
    required this.isSignedIn,
    required this.returnPath,
  });

  final Listing listing;
  final bool isSignedIn;
  final String returnPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final digits = _normalizedPhoneDigits(listing.ownerPhone);
    final available = digits != null;
    final currentUid = ref.watch(authStateProvider).asData?.value?.uid;
    final cannotChatWithSelf = currentUid == listing.ownerId;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(
                    AppLayout.minimumTapTarget,
                  ),
                ),
                onPressed: available
                    ? () => _launchContact(
                        context,
                        Uri(scheme: 'tel', path: '+$digits'),
                      )
                    : null,
                icon: const Icon(Icons.call_outlined),
                label: const Text(ListingCopy.call),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(
                    AppLayout.minimumTapTarget,
                  ),
                ),
                onPressed: available
                    ? () => _launchContact(
                        context,
                        Uri.https('wa.me', '/$digits'),
                      )
                    : null,
                icon: const Icon(Icons.chat_outlined),
                label: const Text(ListingCopy.whatsapp),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Tooltip(
                message: cannotChatWithSelf
                    ? ListingCopy.cannotChatWithSelf
                    : ListingCopy.chat,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(
                      AppLayout.minimumTapTarget,
                    ),
                  ),
                  onPressed: !isSignedIn
                      ? () => showSignInPrompt(context, returnPath: returnPath)
                      : cannotChatWithSelf
                      ? null
                      : () => _openChat(context, ref),
                  icon: const Icon(Icons.forum_outlined),
                  label: const Text(ListingCopy.chat),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openChat(BuildContext context, WidgetRef ref) async {
    final authUser = ref.read(authStateProvider).asData?.value;
    final appUser = ref.read(currentAppUserProvider).asData?.value;
    if (authUser == null || appUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(ListingCopy.chatAccountError)),
      );
      return;
    }
    try {
      final roomId = await ref
          .read(chatRepositoryProvider)
          .openRoom(currentUid: authUser.uid, listing: listing);
      if (context.mounted) context.go('/chat/$roomId');
    } on AppException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  String? _normalizedPhoneDigits(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) digits = '256${digits.substring(1)}';
    if (!digits.startsWith('256') && digits.length == 9) {
      digits = '256$digits';
    }
    return digits.length == 12 && digits.startsWith('256') ? digits : null;
  }

  Future<void> _launchContact(BuildContext context, Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          context.mounted) {
        _showFailure(context);
      }
    } on PlatformException {
      if (context.mounted) _showFailure(context);
    }
  }

  void _showFailure(BuildContext context) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text(ListingCopy.actionFailed)));
  }
}
