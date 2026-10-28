import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../listings/data/listing.dart';
import '../data/favorites_repository.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => FavoritesRepository(),
);

final favoriteStatusProvider = FutureProvider.family<bool, String>((
  ref,
  listingId,
) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return false;
  return ref.watch(favoritesRepositoryProvider).isSaved(user.uid, listingId);
});

final favoriteToggleProvider =
    NotifierProvider<FavoriteToggleController, Map<String, bool>>(
      FavoriteToggleController.new,
    );

class FavoriteToggleController extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() {
    ref.watch(authStateProvider);
    return const {};
  }

  Future<void> setSaved(Listing listing, {required bool saved}) async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) {
      throw const AppException('Sign in to save listings.');
    }
    final previous = state[listing.id];
    state = {...state, listing.id: saved};
    try {
      await ref
          .read(favoritesRepositoryProvider)
          .setSaved(user.uid, listing, saved: saved);
      ref.invalidate(favoriteStatusProvider(listing.id));
    } on Object {
      if (previous == null) {
        final next = Map<String, bool>.of(state)..remove(listing.id);
        state = next;
      } else {
        state = {...state, listing.id: previous};
      }
      rethrow;
    }
  }

  void clear(String listingId) {
    final next = Map<String, bool>.of(state)..remove(listingId);
    state = next;
  }
}

class FavoritesPageState {
  const FavoritesPageState({
    required this.items,
    required this.hasMore,
    this.lastDocument,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<FavoriteListing> items;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool isLoadingMore;
  final Object? loadMoreError;
}

final favoritesPageProvider =
    AsyncNotifierProvider<FavoritesPageController, FavoritesPageState>(
      FavoritesPageController.new,
    );

class FavoritesPageController extends AsyncNotifier<FavoritesPageState> {
  static const pageSize = 20;
  int _generation = 0;

  @override
  Future<FavoritesPageState> build() async {
    final user = await ref.watch(authStateProvider.future);
    if (user == null) {
      throw const AppException('Sign in to view saved listings.');
    }
    return _load(user.uid);
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null ||
        !current.hasMore ||
        current.isLoadingMore ||
        current.lastDocument == null) {
      return;
    }
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;
    final generation = _generation;
    state = AsyncData(
      FavoritesPageState(
        items: current.items,
        hasMore: current.hasMore,
        lastDocument: current.lastDocument,
        isLoadingMore: true,
      ),
    );
    try {
      final page = await ref
          .read(favoritesRepositoryProvider)
          .getPage(user.uid, startAfter: current.lastDocument);
      if (generation != _generation) return;
      state = AsyncData(
        FavoritesPageState(
          items: [...current.items, ...page.items],
          hasMore: page.items.length == pageSize,
          lastDocument: page.lastDocument ?? current.lastDocument,
        ),
      );
    } on Object catch (error) {
      if (generation != _generation) return;
      state = AsyncData(
        FavoritesPageState(
          items: current.items,
          hasMore: current.hasMore,
          lastDocument: current.lastDocument,
          loadMoreError: error,
        ),
      );
    }
  }

  Future<void> remove(FavoriteListing favorite) async {
    final current = state.asData?.value;
    final user = ref.read(authStateProvider).asData?.value;
    if (current == null || user == null) return;
    state = AsyncData(
      FavoritesPageState(
        items: current.items
            .where((item) => item.listingId != favorite.listingId)
            .toList(growable: false),
        hasMore: current.hasMore,
        lastDocument: current.lastDocument,
      ),
    );
    try {
      await ref
          .read(favoritesRepositoryProvider)
          .remove(user.uid, favorite.listingId);
      ref.read(favoriteToggleProvider.notifier).clear(favorite.listingId);
      ref.invalidate(favoriteStatusProvider(favorite.listingId));
    } on Object catch (error) {
      state = AsyncData(
        FavoritesPageState(
          items: current.items,
          hasMore: current.hasMore,
          lastDocument: current.lastDocument,
          loadMoreError: error,
        ),
      );
      rethrow;
    }
  }

  Future<void> refresh() async {
    _generation++;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await ref.read(authStateProvider.future);
      if (user == null) {
        throw const AppException('Sign in to view saved listings.');
      }
      return _load(user.uid);
    });
  }

  Future<FavoritesPageState> _load(String uid) async {
    final page = await ref
        .read(favoritesRepositoryProvider)
        .getPage(uid, limit: pageSize);
    return FavoritesPageState(
      items: page.items,
      hasMore: page.items.length == pageSize,
      lastDocument: page.lastDocument,
    );
  }
}

final favoriteAvailabilityProvider = FutureProvider.family<bool, String>(
  (ref, listingId) =>
      ref.watch(favoritesRepositoryProvider).isListingAvailable(listingId),
);
