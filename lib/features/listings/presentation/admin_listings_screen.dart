import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/ugx_formatter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/admin_widgets.dart';
import '../../../core/widgets/app_network_image.dart';
import '../data/listing.dart';
import '../data/listings_repository.dart';
import 'listing_copy.dart';
import 'listing_form_screen.dart';
import 'listings_providers.dart';
import '../../admin/presentation/admin_copy.dart';

class AdminListingsScreen extends ConsumerStatefulWidget {
  const AdminListingsScreen({super.key});

  @override
  ConsumerState<AdminListingsScreen> createState() =>
      _AdminListingsScreenState();
}

class _AdminListingsScreenState extends ConsumerState<AdminListingsScreen> {
  static const _pageSize = 20;
  final _searchController = TextEditingController();
  late Future<ListingPage> _pageFuture;
  final _loadedListings = <Listing>[];
  Timer? _debounce;
  ListingStatus? _status;
  String _keyword = '';
  DocumentSnapshot<Map<String, dynamic>>? _nextCursor;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _loadPage() {
    _pageFuture = ref
        .read(listingsRepositoryProvider)
        .getAdminListings(status: _status, keyword: _keyword);
  }

  void _resetPages() {
    _loadedListings.clear();
    _nextCursor = null;
    _hasMore = true;
    _loadPage();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _keyword = value.trim().toLowerCase();
        _resetPages();
      });
    });
  }

  Future<void> _refresh() async {
    setState(_resetPages);
    try {
      await _pageFuture;
    } on Object {
      // The FutureBuilder renders the error state.
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const AdminPageHeader(
        title: AdminCopy.listings,
        subtitle: AdminCopy.listingsSubtitle,
      ),
      AdminFilterBar(
        controller: _searchController,
        searchLabel: ListingCopy.searchListings,
        onSearchChanged: _onSearch,
        clearSearchLabel: AdminCopy.clearSearch,
        onClear: () {
          _searchController.clear();
          _onSearch('');
        },
        filters: [
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.md,
                ),
                child: Text(
                  AdminCopy.status,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              ChoiceChip(
                label: const Text(ListingCopy.allStatuses),
                selected: _status == null,
                onSelected: (_) => _setStatus(null),
              ),
              for (final status in ListingStatus.values)
                ChoiceChip(
                  label: Text(_statusLabel(status)),
                  selected: _status == status,
                  onSelected: (_) => _setStatus(status),
                ),
            ],
          ),
        ],
        action: FilledButton.icon(
          onPressed: _openForm,
          icon: const Icon(Icons.add),
          label: const Text(ListingCopy.createTitle),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<ListingPage>(
            future: _pageFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AdminLoadingList(itemCount: 5);
              }
              if (snapshot.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: AppLayout.statePlaceholderHeight,
                      child: AdminErrorState(
                        message: _errorMessage(snapshot.error),
                        retryLabel: ListingCopy.retry,
                        onRetry: () => setState(_resetPages),
                      ),
                    ),
                  ],
                );
              }
              final page = snapshot.data!;
              final listings = _loadedListings.isEmpty
                  ? page.items
                  : _loadedListings;
              if (listings.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(
                      height: AppLayout.statePlaceholderHeight,
                      child: AdminEmptyState(
                        title: ListingCopy.adminListings,
                        message: ListingCopy.noListings,
                      ),
                    ),
                  ],
                );
              }
              final hasNextPage = _loadedListings.isEmpty
                  ? page.items.length == _pageSize
                  : _hasMore;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                children: [
                  for (final listing in listings)
                    _AdminListingCard(
                      listing: listing,
                      isBusy: _busyId == listing.id,
                      onEdit: () => _openForm(listing),
                      onApprove: () => _approve(listing),
                      onReject: () => _reject(listing),
                      onDelete: () => _delete(listing),
                    ),
                  if (hasNextPage)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      child: Center(
                        child: OutlinedButton.icon(
                          onPressed: _isLoadingMore
                              ? null
                              : () => _loadMore(page),
                          icon: _isLoadingMore
                              ? const SizedBox.square(
                                  dimension: AppSpacing.md,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.expand_more),
                          label: const Text(AdminCopy.loadMore),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    ],
  );

  void _setStatus(ListingStatus? status) {
    if (_status == status) return;
    setState(() {
      _status = status;
      _resetPages();
    });
  }

  Future<void> _loadMore(ListingPage currentPage) async {
    final cursor = _nextCursor ?? currentPage.lastDocument;
    if (cursor == null || _isLoadingMore) return;
    setState(() {
      if (_loadedListings.isEmpty) _loadedListings.addAll(currentPage.items);
      _isLoadingMore = true;
    });
    try {
      final page = await ref
          .read(listingsRepositoryProvider)
          .getAdminListings(
            status: _status,
            keyword: _keyword,
            startAfter: cursor,
          );
      if (!mounted) return;
      setState(() {
        _loadedListings.addAll(page.items);
        _nextCursor = page.lastDocument;
        _hasMore = page.items.length == _pageSize;
      });
    } on AppException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _openForm([Listing? listing]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ListingFormScreen(listing: listing, adminMode: true),
      ),
    );
    if (changed == true && mounted) setState(_resetPages);
  }

  Future<void> _approve(Listing listing) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: ListingCopy.approvalQuestion,
      details: listing.title,
      cancelLabel: ListingCopy.cancel,
      confirmLabel: ListingCopy.approve,
    );
    if (confirmed != true) return;
    await _perform(
      listing.id,
      () => ref
          .read(listingsRepositoryProvider)
          .setStatus(listing.id, ListingStatus.approved),
      ListingCopy.listingApproved,
    );
  }

  Future<void> _reject(Listing listing) async {
    final reason = await ReasonDialog.show(
      context,
      title: ListingCopy.rejectionTitle,
      label: ListingCopy.rejectionReason,
      cancelLabel: ListingCopy.cancel,
      confirmLabel: ListingCopy.reject,
      requiredMessage: ListingCopy.rejectionReasonRequired,
    );
    if (reason == null) return;
    await _perform(
      listing.id,
      () => ref
          .read(listingsRepositoryProvider)
          .setStatus(
            listing.id,
            ListingStatus.rejected,
            rejectionReason: reason,
          ),
      ListingCopy.listingRejected,
    );
  }

  Future<void> _delete(Listing listing) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: ListingCopy.deleteQuestion,
      details: ListingCopy.deleteWarning,
      cancelLabel: ListingCopy.cancel,
      confirmLabel: ListingCopy.delete,
    );
    if (confirmed != true) return;
    await _perform(
      listing.id,
      () => ref.read(listingsRepositoryProvider).delete(listing.id),
      ListingCopy.deleted,
    );
  }

  Future<void> _perform(
    String id,
    Future<void> Function() action,
    String successMessage,
  ) async {
    setState(() => _busyId = id);
    try {
      await action();
      if (mounted) {
        _showMessage(successMessage);
        setState(_resetPages);
      }
    } on AppException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AdminListingCard extends StatelessWidget {
  const _AdminListingCard({
    required this.listing,
    required this.isBusy,
    required this.onEdit,
    required this.onApprove,
    required this.onReject,
    required this.onDelete,
  });

  final Listing listing;
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: AppInsets.phonePage,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: AppNetworkImage(
              imageUrl: listing.thumbnailUrl,
              semanticLabel: '${AdminCopy.imagePreview}: ${listing.title}',
              width: AppLayout.listingThumbnailSize,
              height: AppLayout.listingThumbnailSize,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${formatUgx(listing.priceUgx)} · ${listing.priceUnit.name}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  children: [
                    Text('${AdminCopy.area}: ${listing.area}'),
                    Text('${AdminCopy.category}: ${listing.category}'),
                    Text('${AdminCopy.owner}: ${listing.ownerName}'),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                StatusBadge(
                  status: _statusKind(listing.status),
                  label: _statusLabel(listing.status),
                ),
                if (listing.rejectionReason != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${ListingCopy.moderationReason}: ${listing.rejectionReason}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          _ListingActions(
            listing: listing,
            isBusy: isBusy,
            onEdit: onEdit,
            onApprove: onApprove,
            onReject: onReject,
            onDelete: onDelete,
          ),
        ],
      ),
    ),
  );
}

class _ListingActions extends StatelessWidget {
  const _ListingActions({
    required this.listing,
    required this.isBusy,
    required this.onEdit,
    required this.onApprove,
    required this.onReject,
    required this.onDelete,
  });

  final Listing listing;
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: AdminCopy.actions,
    enabled: !isBusy,
    onSelected: (action) {
      switch (action) {
        case 'edit':
          onEdit();
        case 'approve':
          onApprove();
        case 'reject':
          onReject();
        case 'delete':
          onDelete();
      }
    },
    itemBuilder: (context) => [
      const PopupMenuItem<String>(value: 'edit', child: Text(ListingCopy.edit)),
      if (listing.status != ListingStatus.approved)
        const PopupMenuItem<String>(
          value: 'approve',
          child: Text(ListingCopy.approve),
        ),
      if (listing.status != ListingStatus.rejected)
        const PopupMenuItem<String>(
          value: 'reject',
          child: Text(ListingCopy.reject),
        ),
      const PopupMenuItem<String>(
        value: 'delete',
        child: Text(ListingCopy.delete),
      ),
    ],
    icon: isBusy
        ? const SizedBox.square(
            dimension: AppSpacing.lg,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.more_vert),
  );
}

AdminStatusKind _statusKind(ListingStatus status) => switch (status) {
  ListingStatus.pending => AdminStatusKind.pending,
  ListingStatus.approved => AdminStatusKind.approved,
  ListingStatus.rejected => AdminStatusKind.rejected,
};

String _statusLabel(ListingStatus status) => switch (status) {
  ListingStatus.pending => ListingCopy.statusPending,
  ListingStatus.approved => ListingCopy.statusApproved,
  ListingStatus.rejected => ListingCopy.statusRejected,
};

String _errorMessage(Object? error) =>
    error is AppException ? error.message : AdminCopy.queueError;
