import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
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
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            labelText: AdminCopy.searchUsers,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: AdminCopy.clearSearch,
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                    icon: const Icon(Icons.clear),
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<AdminPage<AdminUserRecord>>(
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
                        title: AdminCopy.users,
                        message: AdminCopy.noUsers,
                      ),
                    ),
                  ],
                );
              }
              final wide = MediaQuery.sizeOf(context).width >= 800;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (wide)
                    _usersTable(page.items)
                  else
                    for (final user in page.items) _userCard(user),
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

  Widget _usersTable(List<AdminUserRecord> users) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      columns: const [
        DataColumn(label: Text(AdminCopy.name)),
        DataColumn(label: Text(AdminCopy.emailAndPhone)),
        DataColumn(label: Text(AdminCopy.role)),
        DataColumn(label: Text(AdminCopy.verify)),
        DataColumn(label: Text(AdminCopy.actions)),
      ],
      rows: [
        for (final user in users)
          DataRow(
            cells: [
              DataCell(Text(user.name)),
              DataCell(
                SizedBox(
                  width: 210,
                  child: Text(
                    '${user.email}\n${user.phone.isEmpty ? AdminCopy.phoneUnavailable : user.phone}',
                  ),
                ),
              ),
              DataCell(
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _roleBadge(context, user.role),
                    _userRoleMenu(user),
                  ],
                ),
              ),
              DataCell(_verificationControl(user)),
              DataCell(_userActions(user)),
            ],
          ),
      ],
    ),
  );

  Widget _userCard(AdminUserRecord user) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
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
              _roleBadge(context, user.role),
            ],
          ),
          const SizedBox(height: 4),
          Text(user.email),
          Text(user.phone.isEmpty ? AdminCopy.phoneUnavailable : user.phone),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _verificationControl(user),
              _userRoleMenu(user),
              _userActions(user),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _roleBadge(BuildContext context, UserRole role) =>
      Chip(label: Text(role.name), visualDensity: VisualDensity.compact);

  Widget _verificationControl(AdminUserRecord user) => TextButton.icon(
    onPressed: _busyUid == user.uid ? null : () => _changeVerification(user),
    icon: Icon(user.isVerified ? Icons.verified : Icons.verified_outlined),
    label: Text(user.isVerified ? AdminCopy.verified : AdminCopy.unverified),
  );

  Widget _userRoleMenu(AdminUserRecord user) {
    if (user.role == UserRole.admin) {
      return Text(AdminCopy.roleManagedByBootstrap);
    }
    return PopupMenuButton<UserRole>(
      enabled: _busyUid != user.uid,
      tooltip: AdminCopy.changeRole,
      onSelected: (role) => _changeRole(user, role),
      itemBuilder: (context) => [
        for (final role in const [
          UserRole.tenant,
          UserRole.landlord,
          UserRole.provider,
        ])
          PopupMenuItem<UserRole>(
            value: role,
            enabled: role != user.role,
            child: Text(role.name),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.manage_accounts_outlined),
          const SizedBox(width: 4),
          Text(AdminCopy.changeRole),
        ],
      ),
    );
  }

  Widget _userActions(AdminUserRecord user) => PopupMenuButton<String>(
    tooltip: AdminCopy.actions,
    enabled: _busyUid != user.uid && user.role != UserRole.admin,
    onSelected: (action) {
      if (action == 'edit') _editProfile(user);
      if (action == 'delete') _deleteProfile(user);
    },
    itemBuilder: (context) => const [
      PopupMenuItem(value: 'edit', child: Text(AdminCopy.editProfile)),
      PopupMenuItem(value: 'delete', child: Text(AdminCopy.deleteProfile)),
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
              decoration: const InputDecoration(
                labelText: AdminCopy.phone,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AdminCopy.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              (nameController.text.trim(), phoneController.text.trim()),
            ),
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
      () => ref.read(adminRepositoryProvider).updateUserProfile(
        uid: user.uid,
        name: values.$1,
        phone: phone,
      ),
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
        padding: const EdgeInsets.symmetric(vertical: 12),
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
}) => showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(title),
    content: Text(details),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text(AdminCopy.cancel),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text(AdminCopy.confirm),
      ),
    ],
  ),
);

String _errorMessage(Object? error) =>
    error is AppException ? error.message : AdminCopy.usersError;
