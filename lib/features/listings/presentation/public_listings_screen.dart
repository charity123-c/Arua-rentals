import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../../auth/data/app_user.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../chat/presentation/chat_providers.dart';
import '../data/app_config.dart';
import 'app_config_providers.dart';
import 'listing_card.dart';
import 'listing_copy.dart';
import 'listing_empty_state.dart';
import '../data/listing.dart';
import 'listings_browse_provider.dart';
import '../data/listings_repository.dart';

class PublicListingsScreen extends ConsumerStatefulWidget {
  const PublicListingsScreen({super.key});

  @override
  ConsumerState<PublicListingsScreen> createState() =>
      _PublicListingsScreenState();
}

class _PublicListingsScreenState extends ConsumerState<PublicListingsScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _searchDebounce;
  String? _category;
  String? _area;
  ListingSort _sort = ListingSort.newest;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent - position.pixels <
        AppLayout.listingLoadMoreThreshold) {
      ref.read(listingsBrowseProvider.notifier).loadMore();
    }
  }

  void _scheduleSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _applyFilters);
  }

  void _applyFilters() {
    ref
        .read(listingsBrowseProvider.notifier)
        .applyFilters(
          category: _category,
          area: _area,
          keyword: _searchKeyword(_searchController.text),
          sort: _sort,
        );
  }

  String? _searchKeyword(String search) {
    for (final token in search.toLowerCase().split(RegExp(r'[^a-z0-9]+'))) {
      if (token.isNotEmpty) return token;
    }
    return null;
  }

  void _clearFilters() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _category = null;
      _area = null;
      _sort = ListingSort.newest;
    });
    _applyFilters();
  }

  void _removeSearch() {
    _searchController.clear();
    _applyFilters();
  }

  void _removeCategory() {
    setState(() => _category = null);
    _applyFilters();
  }

  void _removeArea() {
    setState(() => _area = null);
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final browse = ref.watch(listingsBrowseProvider);
    final user = ref.watch(currentAppUserProvider).asData?.value;
    final isSignedIn = ref.watch(authStateProvider).asData?.value != null;
    final config = ref.watch(appConfigProvider);
    final featured = ref.watch(featuredListingsProvider);
    return Title(
      title: ListingCopy.appName,
      color: Theme.of(context).colorScheme.primary,
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.location_city_outlined),
              SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  ListingCopy.appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [_AccountActions(user: user)],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await ref.read(listingsBrowseProvider.notifier).refresh();
            ref.invalidate(featuredListingsProvider);
          },
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _content(
                  context,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.md,
                          bottom: AppSpacing.xs,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ListingCopy.heroHeadline,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              ListingCopy.heroSubtext,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextField(
                              controller: _searchController,
                              onChanged: _scheduleSearch,
                              onSubmitted: (_) {
                                _searchDebounce?.cancel();
                                _applyFilters();
                              },
                              decoration: InputDecoration(
                                hintText: ListingCopy.searchPublicListings,
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchController.text.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: ListingCopy.clearSearch,
                                        onPressed: _removeSearch,
                                        icon: const Icon(Icons.close),
                                      ),
                                border: const OutlineInputBorder(),
                                filled: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.lg,
                                ),
                              ),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              ListingCopy.browseByCategory,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                      config.when(
                        data: (value) => _buildFilters(value),
                        loading: () => const LinearProgressIndicator(),
                        error: (error, stackTrace) => ErrorView(
                          message: _errorMessage(error),
                          retryLabel: ListingCopy.retry,
                          onRetry: () => ref.invalidate(appConfigProvider),
                        ),
                      ),
                      browse.asData?.value == null
                          ? const SizedBox.shrink()
                          : _activeFilterChips(browse.asData!.value),
                    ],
                  ),
                ),
              ),
              _featuredListingsSliver(featured, isSignedIn),
              SliverToBoxAdapter(
                child: _content(
                  context,
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.lg,
                      bottom: AppSpacing.sm,
                    ),
                    child: Text(
                      ListingCopy.latestListings,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),
              ),
              ..._listingSlivers(browse, isSignedIn),
              if (browse.asData?.value.loadMoreError != null)
                SliverToBoxAdapter(
                  child: _content(
                    context,
                    TextButton.icon(
                      onPressed: () =>
                          ref.read(listingsBrowseProvider.notifier).loadMore(),
                      icon: const Icon(Icons.refresh),
                      label: Text(ListingCopy.retry),
                    ),
                  ),
                ),
              if (browse.asData?.value.isLoadingMore == true)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              SliverToBoxAdapter(
                child: _closingSections(context, user, isSignedIn),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(AppConfig config) {
    final categories = config.activeCategoryLabels;
    final areas = config.activeAreaLabels;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: AppLayout.categoryTileHeight,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _categoryTile(
                label: ListingCopy.all,
                icon: Icons.apps_outlined,
                selected: _category == null,
                onTap: () {
                  setState(() => _category = null);
                  _applyFilters();
                },
              ),
              for (final category in categories)
                _categoryTile(
                  label: category,
                  icon: _categoryIcon(category),
                  selected: _category == category,
                  onTap: () {
                    setState(
                      () => _category = _category == category ? null : category,
                    );
                    _applyFilters();
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: AppLayout.filterMinWidth,
                maxWidth: AppLayout.filterMaxWidth,
              ),
              child: DropdownButtonFormField<String?>(
                key: ValueKey(_area),
                initialValue: _area,
                decoration: const InputDecoration(
                  labelText: ListingCopy.areaLabel,
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text(ListingCopy.allAreas),
                  ),
                  for (final area in areas)
                    DropdownMenuItem<String?>(value: area, child: Text(area)),
                ],
                onChanged: (value) {
                  setState(() => _area = value);
                  _applyFilters();
                },
              ),
            ),
            PopupMenuButton<ListingSort>(
              tooltip: ListingCopy.chooseSort,
              initialValue: _sort,
              onSelected: (value) {
                setState(() => _sort = value);
                _applyFilters();
              },
              itemBuilder: (context) => [
                _sortItem(ListingSort.newest, ListingCopy.newest),
                _sortItem(
                  ListingSort.priceLowToHigh,
                  ListingCopy.priceLowToHigh,
                ),
                _sortItem(
                  ListingSort.priceHighToLow,
                  ListingCopy.priceHighToLow,
                ),
              ],
              child: Chip(
                avatar: const Icon(Icons.sort),
                label: Text(_sortLabel(_sort)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _categoryTile({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) => SizedBox(
    width: AppLayout.categoryTileWidth,
    child: Card(
      color: selected ? Theme.of(context).colorScheme.secondaryContainer : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, semanticLabel: ListingCopy.categoryIconDescription),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  IconData _categoryIcon(String category) {
    final normalized = category.toLowerCase();
    if (normalized.contains('rent') || normalized.contains('property')) {
      return Icons.home_work_outlined;
    }
    if (normalized.contains('plumb') || normalized.contains('water')) {
      return Icons.plumbing_outlined;
    }
    if (normalized.contains('electric')) return Icons.electrical_services;
    if (normalized.contains('clean')) return Icons.cleaning_services_outlined;
    if (normalized.contains('mov')) return Icons.local_shipping_outlined;
    return Icons.category_outlined;
  }

  SliverToBoxAdapter _featuredListingsSliver(
    AsyncValue<List<Listing>> featured,
    bool isSignedIn,
  ) => SliverToBoxAdapter(
    child: featured.when(
      data: (listings) => listings.isEmpty
          ? const SizedBox.shrink()
          : _content(
              context,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.lg,
                      bottom: AppSpacing.sm,
                    ),
                    child: Text(
                      ListingCopy.featuredListings,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  SizedBox(
                    height: AppLayout.featuredCardHeight,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: listings.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: AppSpacing.sm),
                      itemBuilder: (context, index) => SizedBox(
                        width: AppLayout.featuredCardWidth,
                        child: ListingCard(
                          listing: listings[index],
                          isSignedIn: isSignedIn,
                          enableHero: false,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      error: (error, stackTrace) => _content(
        context,
        ErrorView(
          message: ListingCopy.featuredListingsError,
          retryLabel: ListingCopy.retry,
          onRetry: () => ref.invalidate(featuredListingsProvider),
        ),
      ),
      loading: () => _content(
        context,
        SizedBox(
          height: AppLayout.featuredCardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            separatorBuilder: (context, index) =>
                const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) => SizedBox(
              width: AppLayout.featuredCardWidth,
              child: const _ListingSkeleton(),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _closingSections(
    BuildContext context,
    AppUser? user,
    bool isSignedIn,
  ) => _content(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: const EdgeInsets.only(top: AppSpacing.xl),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.md,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppLayout.pageHeaderTextMaxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ListingCopy.listWithUsTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(ListingCopy.listWithUsSubtitle),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () =>
                      _openListingSignup(context, user, isSignedIn),
                  icon: const Icon(Icons.add_home_work_outlined),
                  label: const Text(ListingCopy.listWithUsAction),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.lg,
            children: [
              _footerColumn(context, ListingCopy.about, ListingCopy.aboutText),
              _footerColumn(
                context,
                ListingCopy.contact,
                ListingCopy.contactPlaceholder,
              ),
              _footerColumn(
                context,
                ListingCopy.terms,
                ListingCopy.termsPlaceholder,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _footerColumn(BuildContext context, String title, String body) =>
      SizedBox(
        width: AppLayout.filterMaxWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(body, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );

  void _openListingSignup(
    BuildContext context,
    AppUser? user,
    bool isSignedIn,
  ) {
    if (!isSignedIn) {
      context.go(
        Uri(path: '/register', queryParameters: {'redirect': '/'}).toString(),
      );
      return;
    }
    if (user?.role == UserRole.landlord || user?.role == UserRole.provider) {
      context.go('/provider');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(ListingCopy.listAccessPending)),
    );
  }

  PopupMenuItem<ListingSort> _sortItem(ListingSort sort, String label) =>
      PopupMenuItem(value: sort, child: Text(label));

  String _sortLabel(ListingSort sort) => switch (sort) {
    ListingSort.newest => ListingCopy.newest,
    ListingSort.priceLowToHigh => ListingCopy.priceLowToHigh,
    ListingSort.priceHighToLow => ListingCopy.priceHighToLow,
  };

  Widget _activeFilterChips(ListingsBrowseState browse) {
    final chips = <Widget>[];
    final search = _searchController.text.trim();
    if (search.isNotEmpty) {
      chips.add(
        InputChip(
          label: Text(search),
          onDeleted: _removeSearch,
          deleteButtonTooltipMessage: ListingCopy.clearSearch,
        ),
      );
    }
    if (browse.category != null) {
      chips.add(
        InputChip(label: Text(browse.category!), onDeleted: _removeCategory),
      );
    }
    if (browse.area != null) {
      chips.add(InputChip(label: Text(browse.area!), onDeleted: _removeArea));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...chips,
          TextButton(
            onPressed: _clearFilters,
            child: const Text(ListingCopy.clearFilters),
          ),
        ],
      ),
    );
  }

  List<Widget> _listingSlivers(
    AsyncValue<ListingsBrowseState> browse,
    bool isSignedIn,
  ) => browse.when(
    data: (value) {
      if (value.items.isEmpty) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: ListingEmptyState(onClearFilters: _clearFilters),
          ),
        ];
      }
      final phoneLayout =
          MediaQuery.sizeOf(context).width < AppLayout.phoneBreakpoint;
      return [
        _gridPadding(
          SliverGrid(
            gridDelegate: phoneLayout
                ? const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: AppLayout.listingGridCardHeight,
                    crossAxisSpacing: AppSpacing.sm,
                    mainAxisSpacing: AppSpacing.sm,
                  )
                : const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 320,
                    mainAxisExtent: AppLayout.listingGridWideCardHeight,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                  ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final listing = value.items[index];
              return ListingCard(listing: listing, isSignedIn: isSignedIn);
            }, childCount: value.items.length),
          ),
        ),
      ];
    },
    error: (error, stackTrace) => [
      SliverFillRemaining(
        hasScrollBody: false,
        child: ErrorView(
          message: _errorMessage(error),
          retryLabel: ListingCopy.retry,
          onRetry: () => ref.invalidate(listingsBrowseProvider),
        ),
      ),
    ],
    loading: () => [
      _gridPadding(
        SliverGrid(
          gridDelegate:
              MediaQuery.sizeOf(context).width < AppLayout.phoneBreakpoint
              ? const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: AppLayout.listingGridCardHeight,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                )
              : const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 320,
                  mainAxisExtent: AppLayout.listingGridWideCardHeight,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => const _ListingSkeleton(),
            childCount: 6,
          ),
        ),
      ),
    ],
  );

  Widget _gridPadding(Widget sliver) => SliverLayoutBuilder(
    builder: (context, constraints) => SliverPadding(
      padding: EdgeInsets.symmetric(
        horizontal: math.max(
          AppSpacing.md,
          (constraints.crossAxisExtent - AppLayout.publicContentMaxWidth) / 2,
        ),
      ),
      sliver: sliver,
    ),
  );

  Widget _content(BuildContext context, Widget child) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: AppLayout.publicContentMaxWidth,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: SizedBox(width: double.infinity, child: child),
      ),
    ),
  );

  String _errorMessage(Object error) =>
      error is AppException ? error.message : ListingCopy.publicListingsError;
}

class _ListingSkeleton extends StatelessWidget {
  const _ListingSkeleton();

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        const Expanded(child: ShimmerBox()),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ShimmerBox(height: AppSpacing.md),
              const SizedBox(height: AppSpacing.sm),
              const ShimmerBox(
                height: AppSpacing.md,
                width: AppLayout.skeletonShortWidth,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

enum _AccountAction {
  profile,
  favorites,
  inbox,
  listings,
  admin,
  logout,
  login,
  register,
}

class _AccountActions extends ConsumerWidget {
  const _AccountActions({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (user == null) {
      return Wrap(
        children: [
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text(ListingCopy.login),
          ),
          TextButton(
            onPressed: () => context.go('/register'),
            child: const Text(ListingCopy.register),
          ),
        ],
      );
    }
    final isAdmin = user!.role == UserRole.admin && user!.hasAdminClaim;
    final canList =
        user!.role == UserRole.landlord || user!.role == UserRole.provider;
    final unreadCount = ref.watch(totalUnreadChatsProvider);
    return PopupMenuButton<_AccountAction>(
      tooltip: ListingCopy.profile,
      onSelected: (action) => _selectAction(context, ref, action),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _AccountAction.profile,
          child: Text(ListingCopy.profile),
        ),
        PopupMenuItem(
          value: _AccountAction.favorites,
          child: Text(ListingCopy.favorites),
        ),
        PopupMenuItem(
          value: _AccountAction.inbox,
          child: Row(
            children: [
              Expanded(child: Text(ListingCopy.inbox)),
              if (unreadCount > 0) Badge(label: Text('$unreadCount')),
            ],
          ),
        ),
        if (canList)
          PopupMenuItem(
            value: _AccountAction.listings,
            child: Text(ListingCopy.myListings),
          ),
        if (isAdmin)
          PopupMenuItem(
            value: _AccountAction.admin,
            child: Text(ListingCopy.admin),
          ),
        PopupMenuItem(
          value: _AccountAction.logout,
          child: Text(ListingCopy.logout),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Badge(
          isLabelVisible: unreadCount > 0,
          label: Text('$unreadCount'),
          child: CircleAvatar(child: Text(_initial(user!.name))),
        ),
      ),
    );
  }

  Future<void> _selectAction(
    BuildContext context,
    WidgetRef ref,
    _AccountAction action,
  ) async {
    switch (action) {
      case _AccountAction.profile:
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(user!.name),
            content: Text('${user!.email}\n${user!.phone}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(ListingCopy.cancel),
              ),
            ],
          ),
        );
      case _AccountAction.listings:
        context.go('/provider');
      case _AccountAction.favorites:
        context.go('/favorites');
      case _AccountAction.inbox:
        context.go('/chat');
      case _AccountAction.admin:
        context.go('/admin');
      case _AccountAction.logout:
        try {
          await ref.read(authRepositoryProvider).logout();
        } on AppException catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  error.message.isEmpty
                      ? ListingCopy.failedToSignOut
                      : error.message,
                ),
              ),
            );
          }
        }
      case _AccountAction.login:
        context.go('/login');
      case _AccountAction.register:
        context.go('/register');
    }
  }

  String _initial(String name) => name.trim().isEmpty
      ? ListingCopy.appName.substring(0, 1)
      : name.trim()[0];
}
