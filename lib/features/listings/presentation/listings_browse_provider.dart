import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/listing.dart';
import '../data/listings_repository.dart';
import 'listings_providers.dart';

class ListingsBrowseState {
  const ListingsBrowseState({
    required this.items,
    required this.category,
    required this.area,
    required this.keyword,
    required this.sort,
    required this.hasMore,
    this.lastDocument,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<Listing> items;
  final String? category;
  final String? area;
  final String? keyword;
  final ListingSort sort;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool isLoadingMore;
  final Object? loadMoreError;
}

final listingsBrowseProvider =
    AsyncNotifierProvider<ListingsBrowseController, ListingsBrowseState>(
      ListingsBrowseController.new,
    );

final featuredListingsProvider = FutureProvider<List<Listing>>(
  (ref) => ref.watch(listingsRepositoryProvider).getFeaturedListings(),
);

class ListingsBrowseController extends AsyncNotifier<ListingsBrowseState> {
  static const pageSize = 20;
  int _requestGeneration = 0;

  @override
  Future<ListingsBrowseState> build() => _load(
    category: null,
    area: null,
    keyword: null,
    sort: ListingSort.newest,
  );

  Future<void> applyFilters({
    String? category,
    String? area,
    String? keyword,
    ListingSort sort = ListingSort.newest,
  }) async {
    final generation = ++_requestGeneration;
    state = const AsyncLoading();
    try {
      final next = await _load(
        category: category,
        area: area,
        keyword: keyword,
        sort: sort,
      );
      if (generation == _requestGeneration) state = AsyncData(next);
    } on Object catch (error, stackTrace) {
      if (generation == _requestGeneration) {
        state = AsyncError(error, stackTrace);
      }
    }
  }

  Future<void> refresh() async {
    final current = state.asData?.value;
    await applyFilters(
      category: current?.category,
      area: current?.area,
      keyword: current?.keyword,
      sort: current?.sort ?? ListingSort.newest,
    );
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null ||
        !current.hasMore ||
        current.isLoadingMore ||
        current.lastDocument == null) {
      return;
    }
    final generation = _requestGeneration;
    state = AsyncData(
      ListingsBrowseState(
        items: current.items,
        category: current.category,
        area: current.area,
        keyword: current.keyword,
        sort: current.sort,
        hasMore: current.hasMore,
        lastDocument: current.lastDocument,
        isLoadingMore: true,
      ),
    );
    try {
      final page = await ref
          .read(listingsRepositoryProvider)
          .getApprovedListings(
            limit: pageSize,
            startAfter: current.lastDocument,
            category: current.category,
            area: current.area,
            keyword: current.keyword,
            sort: current.sort,
          );
      if (generation != _requestGeneration) return;
      state = AsyncData(
        ListingsBrowseState(
          items: [...current.items, ...page.items],
          category: current.category,
          area: current.area,
          keyword: current.keyword,
          sort: current.sort,
          hasMore: page.items.length == pageSize,
          lastDocument: page.lastDocument ?? current.lastDocument,
        ),
      );
    } on Object catch (error) {
      if (generation != _requestGeneration) return;
      state = AsyncData(
        ListingsBrowseState(
          items: current.items,
          category: current.category,
          area: current.area,
          keyword: current.keyword,
          sort: current.sort,
          hasMore: current.hasMore,
          lastDocument: current.lastDocument,
          loadMoreError: error,
        ),
      );
    }
  }

  Future<ListingsBrowseState> _load({
    required String? category,
    required String? area,
    required String? keyword,
    required ListingSort sort,
  }) async {
    final page = await ref
        .read(listingsRepositoryProvider)
        .getApprovedListings(
          limit: pageSize,
          category: category,
          area: area,
          keyword: keyword,
          sort: sort,
        );
    return ListingsBrowseState(
      items: page.items,
      category: category,
      area: area,
      keyword: keyword,
      sort: sort,
      hasMore: page.items.length == pageSize,
      lastDocument: page.lastDocument,
    );
  }
}
