import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/listing.dart';
import '../data/listings_repository.dart';
import 'listing_copy.dart';
import 'listing_form_screen.dart';
import 'listings_providers.dart';

class ProviderListingsScreen extends ConsumerStatefulWidget {
  const ProviderListingsScreen({super.key});

  @override
  ConsumerState<ProviderListingsScreen> createState() =>
      _ProviderListingsScreenState();
}

class _ProviderListingsScreenState extends ConsumerState<ProviderListingsScreen> {
  static const _pageSize = 20;
  late Future<ListingPage> _pageFuture;
  final _cursors = <DocumentSnapshot<Map<String, dynamic>>?>[null];
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  void _loadPage() {
    _pageFuture = ref
        .read(listingsRepositoryProvider)
        .getOwnerListings(startAfter: _cursors[_pageIndex]);
  }

  Future<void> _refresh() async {
    setState(() {
      _pageIndex = 0;
      _cursors
        ..clear()
        ..add(null);
      _loadPage();
    });
    try {
      await _pageFuture;
    } on Object {
      // The FutureBuilder renders the error state.
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(ListingCopy.providerTitle)),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<ListingPage>(
        future: _pageFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              physics: AlwaysScrollableScrollPhysics(),
              children: [SizedBox(height: 280, child: LoadingView())],
            );
          }
          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: 280,
                  child: ErrorView(
                    message: _errorMessage(snapshot.error),
                    retryLabel: ListingCopy.retry,
                    onRetry: () => setState(_loadPage),
                  ),
                ),
              ],
            );
          }
          final page = snapshot.data!;
          if (page.items.isEmpty) {
            return ListView(
              physics: AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: 280,
                  child: EmptyView(
                    title: ListingCopy.providerTitle,
                    message: ListingCopy.noOwnListings,
                  ),
                ),
              ],
            );
          }
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              for (final listing in page.items)
                _ProviderListingCard(
                  listing: listing,
                  onEdit: () => _edit(listing),
                  onDelete: () => _delete(listing),
                ),
              _PageControls(
                canPrevious: _pageIndex > 0,
                canNext: page.items.length == _pageSize,
                onPrevious: _previousPage,
                onNext: () => _nextPage(page.lastDocument),
              ),
            ],
          );
        },
      ),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _openForm(),
      icon: const Icon(Icons.add),
      label: const Text(ListingCopy.newListing),
    ),
  );

  Future<void> _openForm({Listing? listing}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ListingFormScreen(listing: listing),
      ),
    );
    if (changed == true && mounted) setState(_loadPage);
  }

  Future<void> _edit(Listing listing) => _openForm(listing: listing);

  Future<void> _delete(Listing listing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(ListingCopy.deleteQuestion),
        content: const Text(ListingCopy.deleteWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(ListingCopy.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(ListingCopy.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(listingsRepositoryProvider).delete(listing.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(ListingCopy.deleted)),
        );
        setState(_loadPage);
      }
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  void _nextPage(DocumentSnapshot<Map<String, dynamic>>? lastDocument) {
    if (lastDocument == null) return;
    setState(() {
      _cursors.add(lastDocument);
      _pageIndex++;
      _loadPage();
    });
  }

  void _previousPage() {
    if (_pageIndex == 0) return;
    setState(() {
      _pageIndex--;
      _loadPage();
    });
  }
}

class _ProviderListingCard extends StatelessWidget {
  const _ProviderListingCard({
    required this.listing,
    required this.onEdit,
    required this.onDelete,
  });

  final Listing listing;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text(listing.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_statusText(listing.status)),
          if (listing.rejectionReason != null)
            Text('${ListingCopy.moderationReason}: ${listing.rejectionReason}'),
        ],
      ),
      trailing: Wrap(
        children: [
          IconButton(
            tooltip: ListingCopy.edit,
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: ListingCopy.delete,
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    ),
  );

  String _statusText(ListingStatus status) => switch (status) {
    ListingStatus.approved => ListingCopy.statusLive,
    ListingStatus.pending => ListingCopy.statusPending,
    ListingStatus.rejected => ListingCopy.statusRejected,
  };
}

class _PageControls extends StatelessWidget {
  const _PageControls({
    required this.canPrevious,
    required this.canNext,
    required this.onPrevious,
    required this.onNext,
  });

  final bool canPrevious;
  final bool canNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      TextButton(
        onPressed: canPrevious ? onPrevious : null,
        child: const Text(ListingCopy.previousPage),
      ),
      TextButton(
        onPressed: canNext ? onNext : null,
        child: const Text(ListingCopy.nextPage),
      ),
    ],
  );
}

String _errorMessage(Object? error) =>
    error is AppException ? error.message : ListingCopy.noListings;
