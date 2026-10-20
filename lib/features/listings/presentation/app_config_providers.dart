import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_config.dart';

final appConfigRepositoryProvider = Provider<AppConfigRepository>(
  (ref) => AppConfigRepository(),
);

final appConfigProvider = FutureProvider<AppConfig>(
  (ref) => ref.watch(appConfigRepositoryProvider).load(),
);
