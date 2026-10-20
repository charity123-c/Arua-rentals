import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(),
);

final adminDashboardStatsProvider = FutureProvider(
  (ref) => ref.watch(adminRepositoryProvider).getDashboardStats(),
);
