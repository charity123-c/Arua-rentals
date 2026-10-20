import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../listings/presentation/admin_listings_screen.dart';
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

  static const _sections = [
    AdminCopy.overview,
    AdminCopy.roleRequests,
    AdminCopy.users,
    AdminCopy.listings,
    AdminSettingsCopy.title,
  ];

  @override
  Widget build(BuildContext context) {
    final wideLayout = MediaQuery.sizeOf(context).width >= 900;
    final user = ref.watch(currentAppUserProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(_sections[_selectedIndex]),
        actions: [
          PopupMenuButton<String>(
            tooltip: AdminCopy.logout,
            icon: CircleAvatar(
              child: Text(
                user?.name.isNotEmpty == true
                    ? user!.name.substring(0, 1).toUpperCase()
                    : 'A',
              ),
            ),
            onSelected: (value) {
              if (value == 'logout') _logout(context, ref);
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                value: 'profile',
                child: Text(user?.email ?? AdminCopy.title),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Text(AdminCopy.logout),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: wideLayout
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) =>
                      setState(() => _selectedIndex = index),
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: Text(AdminCopy.overview),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.fact_check_outlined),
                      selectedIcon: Icon(Icons.fact_check),
                      label: Text(AdminCopy.roleRequests),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.people_outline),
                      selectedIcon: Icon(Icons.people),
                      label: Text(AdminCopy.users),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.home_work_outlined),
                      selectedIcon: Icon(Icons.home_work),
                      label: Text(AdminCopy.listings),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text(AdminSettingsCopy.title),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _sectionBody()),
              ],
            )
          : _sectionBody(),
      bottomNavigationBar: wideLayout
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) =>
                  setState(() => _selectedIndex = index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  label: AdminCopy.overview,
                ),
                NavigationDestination(
                  icon: Icon(Icons.fact_check_outlined),
                  label: AdminCopy.roleRequests,
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  label: AdminCopy.users,
                ),
                NavigationDestination(
                  icon: Icon(Icons.home_work_outlined),
                  label: AdminCopy.listings,
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  label: AdminSettingsCopy.title,
                ),
              ],
            ),
    );
  }

  Widget _sectionBody() => switch (_selectedIndex) {
    0 => const AdminOverviewScreen(),
    1 => const RoleRequestsScreen(),
    2 => const AdminUsersScreen(),
    3 => const AdminListingsScreen(),
    _ => const AdminSettingsScreen(),
  };
}

class AdminOverviewScreen extends ConsumerWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminDashboardStatsProvider);
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1100
        ? 3
        : width >= 600
        ? 2
        : 1;
    final cardWidth = (width - 48 - ((columns - 1) * 16)) / columns;
    return RefreshIndicator(
      onRefresh: () => ref.refresh(adminDashboardStatsProvider.future),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            AdminCopy.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          stats.when(
            loading: () => const SizedBox(height: 220, child: LoadingView()),
            error: (error, stackTrace) => SizedBox(
              height: 220,
              child: ErrorView(
                message: _errorMessage(error),
                retryLabel: AdminCopy.retry,
                onRetry: () => ref.invalidate(adminDashboardStatsProvider),
              ),
            ),
            data: (data) => Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatCard(
                  width: cardWidth,
                  label: AdminCopy.totalUsers,
                  count: data.totalUsers,
                  icon: Icons.people_outline,
                ),
                _StatCard(
                  width: cardWidth,
                  label: AdminCopy.pendingRequests,
                  count: data.pendingRoleRequests,
                  icon: Icons.fact_check_outlined,
                ),
                _StatCard(
                  width: cardWidth,
                  label: AdminCopy.pendingListings,
                  count: data.pendingListings,
                  icon: Icons.hourglass_top,
                ),
                _StatCard(
                  width: cardWidth,
                  label: AdminCopy.approvedListings,
                  count: data.approvedListings,
                  icon: Icons.check_circle_outline,
                ),
                _StatCard(
                  width: cardWidth,
                  label: AdminCopy.rejectedListings,
                  count: data.rejectedListings,
                  icon: Icons.cancel_outlined,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.width,
    required this.label,
    required this.count,
    required this.icon,
  });

  final double width;
  final String label;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('$count', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(label),
          ],
        ),
      ),
    ),
  );
}

class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(AdminCopy.accessDenied)),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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

String _errorMessage(Object error) =>
    error is AppException ? error.message : AdminCopy.adminDataError;
