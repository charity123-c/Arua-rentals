import 'dart:async';

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

class AdminListingsScreen extends ConsumerStatefulWidget {
  const AdminListingsScreen({super.key});

  @override
  ConsumerState<AdminListingsScreen> createState() => _AdminListingsScreenState();
}

class _AdminListingsScreenState extends ConsumerState<AdminListingsScreen> {
  static const _pageSize = 20;
  final _searchController = TextEditingController();
  final _cursors = <DocumentSnapshot<Map<String, dynamic>>?>[null];
  late Future<ListingPage> _pageFuture;
  Timer? _debounce;
  ListingStatus? _status;
  String _keyword = '';
  int _pageIndex = 0;
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
    _pageFuture = ref.read(listingsRepositoryProvider).getAdminListings(
      status: _status,
      keyword: _keyword,
      startAfter: _cursors[_pageIndex],
    );
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

  void _resetPages() {
    _pageIndex = 0;
    _cursors
      ..clear()
      ..add(null);
    _loadPage();
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
      Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                controller: _searchController,
                onChanged: _onSearch,
                decoration: const InputDecoration(
                  labelText: ListingCopy.searchListings,
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<ListingStatus?>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: ListingCopy.allStatuses,
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<ListingStatus?>(
                    value: null,
                    child: Text(ListingCopy.allStatuses),
                  ),
                  for (final status in ListingStatus.values)
                    DropdownMenuItem<ListingStatus?>(
                      value: status,
                      child: Text(status.name),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _status = value;
                  _resetPages();
                }),
              ),
            ),
            FilledButton.icon(
              onPressed: _openForm,
              icon: const Icon(Icons.add),
              label: const Text(ListingCopy.createTitle),
            ),
          ],
        ),
      ),
      Expanded(
        child: RefreshIndicator(
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
                        title: ListingCopy.adminListings,
                        message: ListingCopy.noListings,
                      ),
                    ),
                  ],
                );
              }
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  for (final listing in page.items)
                    _AdminListingCard(
                      listing: listing,
                      isBusy: _busyId == listing.id,
                      onEdit: () => _openForm(listing),
                      onApprove: () => _approve(listing),
                      onReject: () => _reject(listing),
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
      ),
    ],
  );

  Future<void> _openForm([Listing? listing]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ListingFormScreen(listing: listing, adminMode: true),
      ),
    );
    if (changed == true && mounted) setState(_loadPage);
  }

  Future<void> _approve(Listing listing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(ListingCopy.approvalQuestion),
        content: Text(listing.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(ListingCopy.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(ListingCopy.approve),
          ),
        ],
      ),
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
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(ListingCopy.rejectionTitle),
        content: TextField(
          controller: controller,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: ListingCopy.rejectionReason,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(ListingCopy.cancel),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(context, value);
            },
            child: const Text(ListingCopy.reject),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null) return;
    await _perform(
      listing.id,
      () => ref.read(listingsRepositoryProvider).setStatus(
            listing.id,
            ListingStatus.rejected,
            rejectionReason: reason,
          ),
      ListingCopy.listingRejected,
    );
  }

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
        setState(_loadPage);
      }
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(listing.title, style: Theme.of(context).textTheme.titleMedium),
          Text('${listing.ownerName} · ${listing.ownerId}'),
          Text('${listing.area} · ${listing.status.name}'),
          if (listing.rejectionReason != null)
            Text('${ListingCopy.moderationReason}: ${listing.rejectionReason}'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: isBusy ? null : onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text(ListingCopy.edit),
              ),
              if (listing.status != ListingStatus.approved)
                FilledButton.icon(
                  onPressed: isBusy ? null : onApprove,
                  icon: const Icon(Icons.check),
                  label: const Text(ListingCopy.approve),
                ),
              if (listing.status != ListingStatus.rejected)
                OutlinedButton.icon(
                  onPressed: isBusy ? null : onReject,
                  icon: const Icon(Icons.close),
                  label: const Text(ListingCopy.reject),
                ),
              OutlinedButton.icon(
                onPressed: isBusy ? null : onDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text(ListingCopy.delete),
              ),
              if (isBusy)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ],
      ),
    ),
  );
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
