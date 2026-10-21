import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/admin_widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/admin_records.dart';
import '../../listings/presentation/admin_listings_screen.dart';
import '../../listings/presentation/listing_copy.dart';
import 'admin_copy.dart';
import 'admin_providers.dart';
import 'admin_queue_screens.dart';
import 'admin_settings_copy.dart';
import 'admin_settings_screen.dart';
import 'admin_users_screen.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final wideLayout =
        MediaQuery.sizeOf(context).width >= AppLayout.wideBreakpoint;
    final user = ref.watch(currentAppUserProvider).asData?.value;
    final stats = ref.watch(adminDashboardStatsProvider).asData?.value;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: wideLayout
            ? Row(
                children: [
                  _WideNavigation(
                    selectedIndex: _selectedIndex,
                    stats: stats,
                    name: user?.name ?? AdminCopy.title,
                    onSelect: _selectSection,
                    onLogout: () => _logout(context, ref),
                    onPreview: () => context.go('/?preview=true'),
                  ),
                  const VerticalDivider(width: AppLayout.dividerThickness),
                  Expanded(child: AdminContent(child: _sectionBody())),
                ],
              )
            : AdminContent(child: _sectionBody()),
      ),
      bottomNavigationBar: wideLayout
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex < 3 ? _selectedIndex : 3,
              onDestinationSelected: (index) {
                if (index == 3) {
                  _showMoreMenu(
                    context,
                    name: user?.name ?? AdminCopy.title,
                    email: user?.email ?? AdminCopy.title,
                    pendingListings: stats?.pendingListings ?? 0,
                  );
                } else {
                  _selectSection(index);
                }
              },
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  label: AdminCopy.overview,
                ),
                NavigationDestination(
                  icon: _NavBadgeIcon(
                    icon: Icons.fact_check_outlined,
                    count: stats?.pendingRoleRequests ?? 0,
                  ),
                  label: AdminCopy.roleRequests,
                ),
                const NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  label: AdminCopy.users,
                ),
                const NavigationDestination(
                  icon: Icon(Icons.more_horiz),
                  label: AdminCopy.more,
                ),
              ],
            ),
    );
  }

  void _selectSection(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  Future<void> _showMoreMenu(
    BuildContext context, {
    required String name,
    required String email,
    required int pendingListings,
  }) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CircleAvatar(child: Text(_initialFor(name))),
              title: Text(name),
              subtitle: Text(email),
              enabled: false,
            ),
            const Divider(height: AppLayout.dividerThickness),
            ListTile(
              leading: _NavBadgeIcon(
                icon: Icons.home_work_outlined,
                count: pendingListings,
              ),
              title: const Text(AdminCopy.manageListings),
              onTap: () => Navigator.pop(context, 3),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text(AdminCopy.settings),
              onTap: () => Navigator.pop(context, 4),
            ),
            ListTile(
              leading: const Icon(Icons.public_outlined),
              title: const Text(ListingCopy.previewPublicSite),
              onTap: () => Navigator.pop(context, -2),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text(AdminCopy.logout),
              onTap: () => Navigator.pop(context, -1),
            ),
          ],
        ),
      ),
    );
    if (!mounted || !context.mounted || selected == null) return;
    if (selected == -1) {
      await _logout(context, ref);
    } else if (selected == -2) {
      context.go('/?preview=true');
    } else {
      _selectSection(selected);
    }
  }

  Widget _sectionBody() => switch (_selectedIndex) {
    0 => AdminOverviewScreen(onNavigate: _selectSection),
    1 => const RoleRequestsScreen(),
    2 => const AdminUsersScreen(),
    3 => const AdminListingsScreen(),
    _ => const AdminSettingsScreen(),
  };
}

class _WideNavigation extends StatelessWidget {
  const _WideNavigation({
    required this.selectedIndex,
    required this.stats,
    required this.name,
    required this.onSelect,
    required this.onLogout,
    required this.onPreview,
  });

  final int selectedIndex;
  final AdminDashboardStats? stats;
  final String name;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: AppLayout.navigationRailWidth,
    child: Column(
      children: [
        Expanded(
          child: NavigationRail(
            extended: true,
            minExtendedWidth: AppLayout.navigationRailWidth,
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelect,
            destinations: [
              const NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text(AdminCopy.overview),
              ),
              NavigationRailDestination(
                icon: _NavBadgeIcon(
                  icon: Icons.fact_check_outlined,
                  count: stats?.pendingRoleRequests ?? 0,
                ),
                selectedIcon: _NavBadgeIcon(
                  icon: Icons.fact_check,
                  count: stats?.pendingRoleRequests ?? 0,
                ),
                label: const Text(AdminCopy.roleRequests),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text(AdminCopy.users),
              ),
              NavigationRailDestination(
                icon: _NavBadgeIcon(
                  icon: Icons.home_work_outlined,
                  count: stats?.pendingListings ?? 0,
                ),
                selectedIcon: _NavBadgeIcon(
                  icon: Icons.home_work,
                  count: stats?.pendingListings ?? 0,
                ),
                label: const Text(AdminCopy.listings),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text(AdminSettingsCopy.title),
              ),
            ],
          ),
        ),
        const Divider(height: AppLayout.dividerThickness),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton.icon(
                onPressed: onPreview,
                icon: const Icon(Icons.public_outlined),
                label: const Text(ListingCopy.previewPublicSite),
              ),
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout),
                label: const Text(AdminCopy.logout),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _NavBadgeIcon extends StatelessWidget {
  const _NavBadgeIcon({required this.icon, required this.count});

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) => Badge(
    isLabelVisible: count > 0,
    label: Text(count > 99 ? '99+' : '$count'),
    child: Icon(icon),
  );
}

class AdminOverviewScreen extends ConsumerWidget {
  const AdminOverviewScreen({required this.onNavigate, super.key});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminDashboardStatsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(adminDashboardStatsProvider.future),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        children: [
          const AdminPageHeader(
            title: AdminCopy.title,
            subtitle: AdminCopy.overviewSubtitle,
          ),
          stats.when(
            loading: () => const SizedBox(
              height: AppLayout.overviewLoadingHeight,
              child: AdminLoadingList(itemCount: 4),
            ),
            error: (error, stackTrace) => SizedBox(
              height: AppLayout.statePlaceholderHeight,
              child: AdminErrorState(
                message: _errorMessage(error),
                retryLabel: AdminCopy.retry,
                onRetry: () => ref.invalidate(adminDashboardStatsProvider),
              ),
            ),
            data: (data) => Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns =
                        constraints.maxWidth >= AppLayout.wideBreakpoint
                        ? 4
                        : 2;
                    return GridView.count(
                      crossAxisCount: columns,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      childAspectRatio: columns == 2
                          ? AppLayout.phoneStatCardAspectRatio
                          : AppLayout.wideStatCardAspectRatio,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        StatCard(
                          label: AdminCopy.totalUsers,
                          value: data.totalUsers,
                          icon: Icons.people_outline,
                        ),
                        StatCard(
                          label: AdminCopy.pendingRequests,
                          value: data.pendingRoleRequests,
                          icon: Icons.fact_check_outlined,
                        ),
                        StatCard(
                          label: AdminCopy.pendingListings,
                          value: data.pendingListings,
                          icon: Icons.hourglass_top,
                        ),
                        StatCard(
                          label: AdminCopy.approvedListings,
                          value: data.approvedListings,
                          icon: Icons.check_circle_outline,
                        ),
                        StatCard(
                          label: AdminCopy.rejectedListings,
                          value: data.rejectedListings,
                          icon: Icons.cancel_outlined,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                AdminSectionCard(
                  title: AdminCopy.needsAttention,
                  child: Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => onNavigate(1),
                        icon: const Icon(Icons.fact_check_outlined),
                        label: Text(
                          '${AdminCopy.reviewRequests} (${data.pendingRoleRequests})',
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => onNavigate(3),
                        icon: const Icon(Icons.home_work_outlined),
                        label: Text(
                          '${AdminCopy.reviewListings} (${data.pendingListings})',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(AdminCopy.accessDenied)),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(AdminCopy.accessDeniedMessage, textAlign: TextAlign.center),
      ),
    ),
  );
}

Future<void> _logout(BuildContext context, WidgetRef ref) async {
  try {
    await ref.read(authRepositoryProvider).logout();
  } on AppException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

String _initialFor(String? name) => name?.isNotEmpty == true
    ? name!.substring(0, 1).toUpperCase()
    : AdminCopy.title.substring(0, 1);

String _errorMessage(Object error) =>
    error is AppException ? error.message : AdminCopy.adminDataError;
