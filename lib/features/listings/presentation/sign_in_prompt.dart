import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'listing_copy.dart';

Future<void> showSignInPrompt(
  BuildContext context, {
  required String returnPath,
}) async {
  final selected = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text(ListingCopy.signInPromptTitle),
      content: const Text(ListingCopy.signInPromptMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text(ListingCopy.cancel),
        ),
        OutlinedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text(ListingCopy.register),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text(ListingCopy.login),
        ),
      ],
    ),
  );
  if (selected == null || !context.mounted) return;
  final destination = selected ? '/register' : '/login';
  context.go(
    Uri(path: destination, queryParameters: {'redirect': returnPath}).toString(),
  );
}
