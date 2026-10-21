import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/admin_widgets.dart';
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
  Widget build(BuildContext context) => Column(
    children: [
      const AdminPageHeader(
        title: AdminCopy.roleRequests,
        subtitle: AdminCopy.roleRequestsSubtitle,
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<AdminPage<AdminRoleRequest>>(
            future: _pageFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _queueState(const AdminLoadingList(itemCount: 4));
              }
              if (snapshot.hasError) {
                return _queueState(
                  AdminErrorState(
                    message: _errorMessage(snapshot.error),
                    retryLabel: AdminCopy.retry,
                    onRetry: () => setState(_loadPage),
                  ),
                );
              }
              final page = snapshot.data!;
              if (page.items.isEmpty) {
                return _queueState(
                  const AdminEmptyState(
                    title: AdminCopy.roleRequests,
                    message: AdminCopy.noRoleRequests,
                  ),
                );
              }
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
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
        ),
      ),
    ],
  );

  Widget _queueState(Widget state) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      SizedBox(height: AppLayout.statePlaceholderHeight, child: state),
    ],
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
    final confirmed = await ConfirmDialog.show(
      context,
      title: AdminCopy.approvalQuestion,
      details: '${request.name} — ${request.requestedRole.name}',
      cancelLabel: AdminCopy.cancel,
      confirmLabel: AdminCopy.approve,
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
    final reason = await ReasonDialog.show(
      context,
      title: AdminCopy.rejectionTitle,
      label: AdminCopy.rejectionReason,
      cancelLabel: AdminCopy.cancel,
      confirmLabel: AdminCopy.reject,
      requiredMessage: AdminCopy.rejectionReasonRequired,
    );
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
      if (mounted) setState(_loadPage);
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
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.wideBreakpoint;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(request.name, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xxs),
        Text(request.email),
        Text(
          request.phone.isEmpty ? AdminCopy.phoneUnavailable : request.phone,
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            RoleBadge(label: request.requestedRole.name),
            Text('${AdminCopy.date}: ${_formatDate(request.createdAt)}'),
          ],
        ),
      ],
    );
    final actions = Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
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
          const SizedBox.square(
            dimension: AppSpacing.lg,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
    final initial = request.name.isEmpty
        ? AdminCopy.title.substring(0, 1)
        : request.name.substring(0, 1).toUpperCase();
    return Card(
      child: Padding(
        padding: AppInsets.phonePage,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(child: Text(initial)),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: details),
                if (wide) ...[const SizedBox(width: AppSpacing.md), actions],
              ],
            ),
            if (!wide) ...[const SizedBox(height: AppSpacing.md), actions],
          ],
        ),
      ),
    );
  }
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
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
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

String _formatDate(DateTime? date) => date == null
    ? AdminCopy.unknownDate
    : DateFormat.yMMMd().add_jm().format(
        date.toUtc().add(const Duration(hours: 3)),
      );

String _errorMessage(Object? error) =>
    error is AppException ? error.message : AdminCopy.queueError;
