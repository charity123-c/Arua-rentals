import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_tokens.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../listings/data/listing.dart';
import '../../listings/presentation/listing_copy.dart';
import '../../listings/presentation/sign_in_prompt.dart';
import 'favorites_providers.dart';

class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({required this.listing, this.isSignedIn, super.key});

  final Listing listing;
  final bool? isSignedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(favoriteStatusProvider(listing.id));
    final override = ref.watch(favoriteToggleProvider)[listing.id];
    final saved = override ?? status.asData?.value ?? false;
    final authenticated =
        isSignedIn ?? ref.watch(authStateProvider).asData?.value != null;
    return IconButton(
      tooltip: saved ? ListingCopy.removeFavorite : ListingCopy.saveFavorite,
      onPressed: () async {
        if (!authenticated) {
          await showSignInPrompt(
            context,
            returnPath: GoRouterState.of(context).uri.toString(),
          );
          return;
        }
        try {
          await ref
              .read(favoriteToggleProvider.notifier)
              .setSaved(listing, saved: !saved);
        } on Object catch (error) {
          if (!context.mounted) return;
          final message = error is AppException
              ? error.message
              : ListingCopy.favoriteFailed;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
        }
      },
      style: IconButton.styleFrom(
        minimumSize: const Size(
          AppLayout.minimumTapTarget,
          AppLayout.minimumTapTarget,
        ),
        backgroundColor: Theme.of(context).colorScheme.surface
            .withValues(alpha: 0.9),
      ),
      icon: Icon(saved ? Icons.favorite : Icons.favorite_border),
    );
  }
}
