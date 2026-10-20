import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/app_user.dart';
import 'auth_providers.dart';

class HomePlaceholderScreen extends ConsumerWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(currentAppUserProvider);
    return userState.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (error, stackTrace) => Scaffold(
        body: ErrorView(
          message: error is AppException
              ? error.message
              : 'Unable to load your account profile.',
          retryLabel: 'Retry',
          onRetry: () => ref.invalidate(currentAppUserProvider),
        ),
      ),
      data: (user) {
        if (user == null) return const Scaffold(body: LoadingView());
        return Scaffold(
          appBar: AppBar(
            title: const Text('Arua City Finder'),
            actions: [
              IconButton(
                tooltip: 'Log out',
                onPressed: () => _logout(context, ref),
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Welcome, ${user.name}'),
                  const SizedBox(height: 8),
                  Text(
                    'Account role: ${user.role == UserRole.admin && !user.hasAdminClaim ? UserRole.tenant.name : user.role.name}',
                  ),
                  if (user.roleRequest != null) ...[
                    const SizedBox(height: 8),
                    Text('Role request: ${user.roleRequest!.name} (pending)'),
                  ],
                  if (user.role == UserRole.landlord ||
                      user.role == UserRole.provider) ...[
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.go('/provider'),
                      child: const Text('Open provider dashboard'),
                    ),
                  ],
                  if (user.role == UserRole.admin && user.hasAdminClaim) ...[
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.go('/admin'),
                      child: const Text('Open admin dashboard'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ProviderDashboardPlaceholderScreen extends StatelessWidget {
  const ProviderDashboardPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Provider dashboard'),
      leading: IconButton(
        tooltip: 'Home',
        onPressed: () => context.go('/home'),
        icon: const Icon(Icons.arrow_back),
      ),
    ),
    body: const Center(child: Text('Provider dashboard placeholder')),
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
