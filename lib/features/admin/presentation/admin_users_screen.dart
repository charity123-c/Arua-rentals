import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/admin_widgets.dart';
import '../../../core/utils/phone_normalizer.dart';
import '../../auth/data/app_user.dart';
import '../data/admin_records.dart';
import 'admin_copy.dart';
import 'admin_providers.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  static const _pageSize = 20;
  final _searchController = TextEditingController();
  final _cursors = <DocumentSnapshot<Map<String, dynamic>>?>[null];
  late Future<AdminPage<AdminUserRecord>> _pageFuture;
  Timer? _searchDebounce;
  int _pageIndex = 0;
  String _searchTerm = '';
  UserRole? _roleFilter;
  String? _busyUid;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _loadPage() {
    final repository = ref.read(adminRepositoryProvider);
    if (_searchTerm.isNotEmpty) {
      _pageFuture = repository.searchUsers(
        _searchTerm,
        startAfter: _cursors[_pageIndex],
      );
      return;
    }
    _pageFuture = repository.listUsers(startAfter: _cursors[_pageIndex]);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _searchTerm = value.trim();
        _pageIndex = 0;
        _cursors
          ..clear()
          ..add(null);
        _loadPage();
      });
    });
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
        title: AdminCopy.users,
        subtitle: AdminCopy.usersSubtitle,
      ),
      AdminFilterBar(
        controller: _searchController,
        searchLabel: AdminCopy.searchUsers,
        onSearchChanged: _onSearchChanged,
        clearSearchLabel: AdminCopy.clearSearch,
        onClear: () {
          _searchController.clear();
          _onSearchChanged('');
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
                  AdminCopy.filterRole,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              ChoiceChip(
                label: const Text(AdminCopy.allRoles),
                selected: _roleFilter == null,
                onSelected: (_) => _setRoleFilter(null),
              ),
              for (final role in UserRole.values)
                ChoiceChip(
                  label: Text(role.name),
                  selected: _roleFilter == role,
                  onSelected: (_) => _setRoleFilter(role),
                ),
            ],
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<AdminPage<AdminUserRecord>>(
            future: _pageFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: SizedBox(
                        height: AppLayout.statePlaceholderHeight,
                        child: AdminLoadingList(itemCount: 4),
                      ),
                    ),
                  ],
                );
              }
              if (snapshot.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xl,
                      ),
                      child: AdminErrorState(
                        message: _errorMessage(snapshot.error),
                        retryLabel: AdminCopy.retry,
                        onRetry: () => setState(_loadPage),
                      ),
                    ),
                  ],
                );
              }
              final page = snapshot.data!;
              final users = page.items
                  .where(
                    (user) => _roleFilter == null || user.role == _roleFilter,
                  )
                  .toList();
              if (users.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: AdminEmptyState(
                        title: AdminCopy.users,
                        message: AdminCopy.noUsers,
                      ),
                    ),
                    _pageControls(
                      canPrevious: _pageIndex > 0,
                      canNext: page.items.length == _pageSize,
                    ),
                  ],
                );
              }
              final wide =
                  MediaQuery.sizeOf(context).width >= AppLayout.wideBreakpoint;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                children: [
                  if (wide)
                    _usersTable(users)
                  else
                    for (final user in users) _userCard(user),
                  _pageControls(
                    canPrevious: _pageIndex > 0,
                    canNext: page.items.length == _pageSize,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ],
  );

  void _setRoleFilter(UserRole? role) {
    if (_roleFilter == role) return;
    setState(() {
      _roleFilter = role;
      _pageIndex = 0;
      _cursors
        ..clear()
        ..add(null);
      _loadPage();
    });
  }

  Widget _usersTable(List<AdminUserRecord> users) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      columns: const [
        DataColumn(label: Text(AdminCopy.name)),
        DataColumn(label: Text(AdminCopy.emailAndPhone)),
        DataColumn(label: Text(AdminCopy.role)),
        DataColumn(label: Text(AdminCopy.actions)),
        DataColumn(label: Text(AdminCopy.verify)),
      ],
      rows: [
        for (final user in users)
          DataRow(
            cells: [
              DataCell(Text(user.name)),
              DataCell(
                SizedBox(
                  width: AppLayout.contactColumnWidth,
                  child: Text(
                    '${user.email}\n${user.phone.isEmpty ? AdminCopy.phoneUnavailable : user.phone}',
                  ),
                ),
              ),
              DataCell(RoleBadge(label: user.role.name)),
              DataCell(_userActions(user)),
              DataCell(
                StatusBadge(
                  status: user.isVerified
                      ? AdminStatusKind.verified
                      : AdminStatusKind.unverified,
                  label: user.isVerified
                      ? AdminCopy.verified
                      : AdminCopy.unverified,
                ),
              ),
            ],
          ),
      ],
    ),
  );

  Widget _userCard(AdminUserRecord user) => Card(
    child: Padding(
      padding: AppInsets.phonePage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  user.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              RoleBadge(label: user.role.name),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(user.email),
          Text(user.phone.isEmpty ? AdminCopy.phoneUnavailable : user.phone),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusBadge(
                status: user.isVerified
                    ? AdminStatusKind.verified
                    : AdminStatusKind.unverified,
                label: user.isVerified
                    ? AdminCopy.verified
                    : AdminCopy.unverified,
              ),
              _userActions(user),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _userActions(AdminUserRecord user) => PopupMenuButton<String>(
    tooltip: AdminCopy.actions,
    enabled: _busyUid != user.uid,
    onSelected: (action) {
      if (action == 'verify') _changeVerification(user);
      if (action == 'edit') _editProfile(user);
      if (action == 'delete') _deleteProfile(user);
      if (action.startsWith('role:')) {
        final roleName = action.substring('role:'.length);
        final role = UserRole.values.firstWhere(
          (candidate) => candidate.name == roleName,
        );
        _changeRole(user, role);
      }
    },
    itemBuilder: (context) => [
      if (user.role != UserRole.admin) ...[
        const PopupMenuItem<String>(
          enabled: false,
          child: Text(AdminCopy.changeRole),
        ),
        for (final role in const [
          UserRole.tenant,
          UserRole.landlord,
          UserRole.provider,
        ])
          PopupMenuItem<String>(
            value: 'role:${role.name}',
            enabled: role != user.role,
            child: Text(role.name),
          ),
      ],
      PopupMenuItem<String>(
        value: 'verify',
        child: Text(
          user.isVerified ? AdminCopy.unverified : AdminCopy.verified,
        ),
      ),
      if (user.role != UserRole.admin) ...[
        const PopupMenuItem<String>(
          value: 'edit',
          child: Text(AdminCopy.editProfile),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Text(AdminCopy.deleteProfile),
        ),
      ],
    ],
    icon: const Icon(Icons.more_vert),
  );

  Future<void> _editProfile(AdminUserRecord user) async {
    final nameController = TextEditingController(text: user.name);
    final phoneController = TextEditingController(text: user.phone);
    final values = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AdminCopy.editProfile),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: AdminCopy.name),
            ),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: AdminCopy.phone),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AdminCopy.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, (
              nameController.text.trim(),
              phoneController.text.trim(),
            )),
            child: const Text(AdminCopy.confirm),
          ),
        ],
      ),
    );
    nameController.dispose();
    phoneController.dispose();
    if (values == null) return;
    final phone = values.$2.isEmpty ? '' : normalizeUgandanPhone(values.$2);
    if (values.$1.isEmpty || phone == null) {
      _showMessage(AdminCopy.invalidProfile);
      return;
    }
    await _perform(
      user.uid,
      () => ref
          .read(adminRepositoryProvider)
          .updateUserProfile(uid: user.uid, name: values.$1, phone: phone),
      successMessage: AdminCopy.profileSaved,
    );
  }

  Future<void> _deleteProfile(AdminUserRecord user) async {
    final confirmed = await _confirm(
      context,
      title: AdminCopy.deleteProfileQuestion,
      details: AdminCopy.deleteProfileWarning,
    );
    if (confirmed != true) return;
    await _perform(
      user.uid,
      () => ref.read(adminRepositoryProvider).deleteUserProfile(user.uid),
      successMessage: AdminCopy.profileDeleted,
    );
  }

  Widget _pageControls({required bool canPrevious, required bool canNext}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: canPrevious ? _previousPage : null,
              child: const Text(AdminCopy.previousPage),
            ),
            TextButton(
              onPressed: canNext ? _nextPage : null,
              child: const Text(AdminCopy.nextPage),
            ),
          ],
        ),
      );

  void _nextPage() {
    // The current cursor is the last document in the displayed page.
    _pageFuture.then((page) {
      final lastDocument = page.lastDocument;
      if (!mounted || lastDocument == null) return;
      setState(() {
        _cursors.add(lastDocument);
        _pageIndex++;
        _loadPage();
      });
    });
  }

  void _previousPage() {
    if (_pageIndex == 0) return;
    setState(() {
      _pageIndex--;
      _loadPage();
    });
  }

  Future<void> _changeRole(AdminUserRecord user, UserRole role) async {
    final confirmed = await _confirm(
      context,
      title: AdminCopy.roleUpdated,
      details: '${user.name}: ${user.role.name} → ${role.name}',
    );
    if (confirmed != true) return;
    await _perform(
      user.uid,
      () => ref.read(adminRepositoryProvider).updateUserRole(user.uid, role),
    );
  }

  Future<void> _changeVerification(AdminUserRecord user) async {
    final nextValue = !user.isVerified;
    final confirmed = await _confirm(
      context,
      title: AdminCopy.verificationUpdated,
      details:
          '${user.name}: ${nextValue ? AdminCopy.verified : AdminCopy.unverified}',
    );
    if (confirmed != true) return;
    await _perform(
      user.uid,
      () => ref
          .read(adminRepositoryProvider)
          .setUserVerified(user.uid, nextValue),
    );
  }

  Future<void> _perform(
    String uid,
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    setState(() => _busyUid = uid);
    try {
      await action();
      if (mounted) {
        if (successMessage != null) _showMessage(successMessage);
        setState(_loadPage);
      }
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busyUid = null);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

Future<bool?> _confirm(
  BuildContext context, {
  required String title,
  required String details,
}) => ConfirmDialog.show(
  context,
  title: title,
  details: details,
  cancelLabel: AdminCopy.cancel,
  confirmLabel: AdminCopy.confirm,
);

String _errorMessage(Object? error) =>
    error is AppException ? error.message : AdminCopy.usersError;
