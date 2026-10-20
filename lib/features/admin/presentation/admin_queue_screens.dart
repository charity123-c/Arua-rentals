import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/admin_records.dart';
import 'admin_copy.dart';
import 'admin_providers.dart';

class RoleRequestsScreen extends ConsumerStatefulWidget {
  const RoleRequestsScreen({super.key});

  @override
  ConsumerState<RoleRequestsScreen> createState() => _RoleRequestsScreenState();
}

class _RoleRequestsScreenState extends ConsumerState<RoleRequestsScreen> {
  static const _pageSize = 20;
  late Future<AdminPage<AdminRoleRequest>> _pageFuture;
  final _cursors = <DocumentSnapshot<Map<String, dynamic>>?>[null];
  int _pageIndex = 0;
  String? _busyUid;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  void _loadPage() {
    _pageFuture = ref
        .read(adminRepositoryProvider)
        .getPendingRoleRequests(startAfter: _cursors[_pageIndex]);
  }

  Future<void> _refresh() async {
    setState(_loadPage);
    try {
      await _pageFuture;
    } on Object {
      // The FutureBuilder below renders the error state.
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refresh,
    child: FutureBuilder<AdminPage<AdminRoleRequest>>(
      future: _pageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                  retryLabel: AdminCopy.retry,
                  onRetry: () => setState(_loadPage),
                ),
              ),
            ],
          );
        }
        final page = snapshot.data!;
        if (page.items.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: 280,
                child: EmptyView(
                  title: AdminCopy.roleRequests,
                  message: AdminCopy.noRoleRequests,
                ),
              ),
            ],
          );
        }
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            for (final request in page.items)
              _RoleRequestCard(
                request: request,
                isBusy: _busyUid == request.uid,
                onApprove: () => _approve(request),
                onReject: () => _reject(request),
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
  );

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

  Future<void> _approve(AdminRoleRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AdminCopy.approvalQuestion),
        content: Text('${request.name} — ${request.requestedRole.name}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AdminCopy.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AdminCopy.approve),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _perform(
      request.uid,
      () => ref
          .read(adminRepositoryProvider)
          .approveRoleRequest(request.uid, request.requestedRole),
    );
  }

  Future<void> _reject(AdminRoleRequest request) async {
    final reason = await _promptForReason(context);
    if (reason == null) return;
    await _perform(
      request.uid,
      () => ref
          .read(adminRepositoryProvider)
          .rejectRoleRequest(request.uid, reason),
    );
  }

  Future<void> _perform(String uid, Future<void> Function() action) async {
    setState(() => _busyUid = uid);
    try {
      await action();
      if (mounted) {
        setState(_loadPage);
      }
    } on AppException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _busyUid = null);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class ListingsModerationScreen extends ConsumerStatefulWidget {
  const ListingsModerationScreen({super.key});

  @override
  ConsumerState<ListingsModerationScreen> createState() =>
      _ListingsModerationScreenState();
}

class _ListingsModerationScreenState
    extends ConsumerState<ListingsModerationScreen> {
  static const _pageSize = 20;
  late Future<AdminPage<AdminListingRecord>> _pageFuture;
  final _cursors = <DocumentSnapshot<Map<String, dynamic>>?>[null];
  int _pageIndex = 0;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  void _loadPage() {
    _pageFuture = ref
        .read(adminRepositoryProvider)
        .getPendingListings(startAfter: _cursors[_pageIndex]);
  }

  Future<void> _refresh() async {
    setState(_loadPage);
    try {
      await _pageFuture;
    } on Object {
      // The FutureBuilder below renders the error state.
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refresh,
    child: FutureBuilder<AdminPage<AdminListingRecord>>(
      future: _pageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                  retryLabel: AdminCopy.retry,
                  onRetry: () => setState(_loadPage),
                ),
              ),
            ],
          );
        }
        final page = snapshot.data!;
        if (page.items.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: 280,
                child: EmptyView(
                  title: AdminCopy.listings,
                  message: AdminCopy.noListings,
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
              _ListingCard(
                listing: listing,
                isBusy: _busyId == listing.id,
                onApprove: () => _approve(listing),
                onReject: () => _reject(listing),
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
  );

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

  Future<void> _approve(AdminListingRecord listing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AdminCopy.approvalQuestion),
        content: Text(listing.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AdminCopy.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AdminCopy.approve),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _perform(
      listing.id,
      () => ref.read(adminRepositoryProvider).approveListing(listing.id),
    );
  }

  Future<void> _reject(AdminListingRecord listing) async {
    final reason = await _promptForReason(context);
    if (reason == null) return;
    await _perform(
      listing.id,
      () => ref.read(adminRepositoryProvider).rejectListing(listing.id, reason),
    );
  }

  Future<void> _perform(String id, Future<void> Function() action) async {
    setState(() => _busyId = id);
    try {
      await action();
      if (mounted) setState(_loadPage);
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }
}

class _RoleRequestCard extends StatelessWidget {
  const _RoleRequestCard({
    required this.request,
    required this.isBusy,
    required this.onApprove,
    required this.onReject,
  });

  final AdminRoleRequest request;
  final bool isBusy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(request.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(request.email),
          Text(
            request.phone.isEmpty ? AdminCopy.phoneUnavailable : request.phone,
          ),
          Text(
            '${AdminCopy.requestedRoleLabel}: ${request.requestedRole.name} · ${_formatDate(request.createdAt)}',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: isBusy ? null : onApprove,
                icon: const Icon(Icons.check),
                label: const Text(AdminCopy.approve),
              ),
              OutlinedButton.icon(
                onPressed: isBusy ? null : onReject,
                icon: const Icon(Icons.close),
                label: const Text(AdminCopy.reject),
              ),
              if (isBusy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({
    required this.listing,
    required this.isBusy,
    required this.onApprove,
    required this.onReject,
  });

  final AdminListingRecord listing;
  final bool isBusy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(listing.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(listing.ownerName),
          Text(listing.area),
          Text(_formatDate(listing.createdAt)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: isBusy ? null : onApprove,
                icon: const Icon(Icons.check),
                label: const Text(AdminCopy.approve),
              ),
              OutlinedButton.icon(
                onPressed: isBusy ? null : onReject,
                icon: const Icon(Icons.close),
                label: const Text(AdminCopy.reject),
              ),
              if (isBusy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: canPrevious ? onPrevious : null,
          child: const Text(AdminCopy.previousPage),
        ),
        TextButton(
          onPressed: canNext ? onNext : null,
          child: const Text(AdminCopy.nextPage),
        ),
      ],
    ),
  );
}

Future<String?> _promptForReason(BuildContext context) async {
  final controller = TextEditingController();
  String? validationMessage;
  final reason = await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text(AdminCopy.rejectionTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 500,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: AdminCopy.rejectionReason,
            errorText: validationMessage,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AdminCopy.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                setDialogState(
                  () => validationMessage = AdminCopy.rejectionReasonRequired,
                );
                return;
              }
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text(AdminCopy.reject),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  return reason;
}

String _formatDate(DateTime? date) => date == null
    ? AdminCopy.unknownDate
    : DateFormat.yMMMd().add_jm().format(
        date.toUtc().add(const Duration(hours: 3)),
      );

String _errorMessage(Object? error) =>
    error is AppException ? error.message : AdminCopy.queueError;
