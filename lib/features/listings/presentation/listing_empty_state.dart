import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import 'listing_copy.dart';

class ListingEmptyState extends StatelessWidget {
  const ListingEmptyState({required this.onClearFilters, super.key});

  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: AppLayout.statusPlaceholderIconSize,
            semanticLabel: ListingCopy.noListingsMatch,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            ListingCopy.noListingsMatch,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: onClearFilters,
            child: const Text(ListingCopy.clearFilters),
          ),
        ],
      ),
    ),
  );
}
