import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/ugx_formatter.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/app_network_image.dart';
import '../data/favorites_repository.dart';
import '../../listings/presentation/listing_copy.dart';
import 'favorites_providers.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreWhenNeeded);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreWhenNeeded)
      ..dispose();
    super.dispose();
  }

  void _loadMoreWhenNeeded() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter <
            AppLayout.listingLoadMoreThreshold) {
      ref.read(favoritesPageProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesPageProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(ListingCopy.favorites)),
      body: favorites.when(
        loading: () => const LoadingView(),
        error: (error, stackTrace) => ErrorView(
          message: ListingCopy.favoritesError,
          retryLabel: ListingCopy.retry,
          onRetry: () => ref.read(favoritesPageProvider.notifier).refresh(),
        ),
        data: (state) {
          if (state.items.isEmpty) {
            return const EmptyView(
              title: ListingCopy.noFavoritesTitle,
              message: ListingCopy.noFavoritesMessage,
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(favoritesPageProvider.notifier).refresh(),
            child: ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount:
                  state.items.length +
                  (state.isLoadingMore || state.loadMoreError != null ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == state.items.length) {
                  if (state.loadMoreError != null) {
                    return TextButton.icon(
                      onPressed: () =>
                          ref.read(favoritesPageProvider.notifier).loadMore(),
                      icon: const Icon(Icons.refresh),
                      label: const Text(ListingCopy.loadMoreFavoritesFailed),
                    );
                  }
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final favorite = state.items[index];
                return _FavoriteTile(
                  favorite: favorite,
                  onRemove: () async {
                    try {
                      await ref
                          .read(favoritesPageProvider.notifier)
                          .remove(favorite);
                    } on Object {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(ListingCopy.favoriteFailed),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _FavoriteTile extends ConsumerWidget {
  const _FavoriteTile({required this.favorite, required this.onRemove});

  final FavoriteListing favorite;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(
      favoriteAvailabilityProvider(favorite.listingId),
    );
    final isAvailable = availability.asData?.value == true;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        onTap: isAvailable
            ? () => context.go('/listing/${favorite.listingId}')
            : null,
        leading: SizedBox(
          width: AppLayout.listingThumbnailSize,
          height: AppLayout.listingThumbnailSize,
          child: AppNetworkImage(
            imageUrl: favorite.thumbnailUrl,
            semanticLabel: favorite.title,
          ),
        ),
        title: Text(
          isAvailable ? favorite.title : ListingCopy.listingUnavailable,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          isAvailable
              ? '${formatUgx(favorite.priceUgx)} · ${favorite.area}'
              : favorite.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: ListingCopy.removeFavorite,
          onPressed: onRemove,
          icon: const Icon(Icons.favorite),
        ),
      ),
    );
  }
}
