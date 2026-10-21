import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class AdminContent extends StatelessWidget {
  const AdminContent({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppLayout.contentMaxWidth),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: SizedBox(width: double.infinity, child: child),
      ),
    ),
  );
}

class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    required this.title,
    required this.subtitle,
    this.action,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final subtitleWidget = Text(
      subtitle,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.pageHeaderTextMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.xxs),
                subtitleWidget,
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class AdminSectionCard extends StatelessWidget {
  const AdminSectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.action,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final subtitleText = subtitle;
    final subtitleWidget = subtitleText == null
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xxs),
              Text(
                subtitleText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
    return Card(
      elevation: AppElevation.low,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      ?subtitleWidget,
                    ],
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    required this.label,
    required this.value,
    required this.icon,
    super.key,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: AppElevation.low,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.primary),
            const SizedBox(height: AppSpacing.md),
            Text('$value', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.xxs),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

enum AdminStatusKind { pending, approved, rejected, verified, unverified }

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, required this.label, super.key});

  final AdminStatusKind status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground, icon) = switch (status) {
      AdminStatusKind.pending => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        Icons.schedule,
      ),
      AdminStatusKind.approved || AdminStatusKind.verified => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        Icons.verified_outlined,
      ),
      AdminStatusKind.rejected => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.cancel_outlined,
      ),
      AdminStatusKind.unverified => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
        Icons.help_outline,
      ),
    };
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppLayout.statusIconSize, color: foreground),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class RoleBadge extends StatelessWidget {
  const RoleBadge({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Chip(
    label: Text(label),
    visualDensity: VisualDensity.compact,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
    side: BorderSide.none,
    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
    labelStyle: Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer),
  );
}

class ConfirmDialog {
  const ConfirmDialog._();

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String details,
    required String cancelLabel,
    required String confirmLabel,
  }) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      scrollable: true,
      content: Text(details),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

class ReasonDialog {
  const ReasonDialog._();

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String label,
    required String cancelLabel,
    required String confirmLabel,
    required String requiredMessage,
  }) async {
    final controller = TextEditingController();
    String? validationMessage;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          scrollable: true,
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 500,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: label,
              errorText: validationMessage,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(cancelLabel),
            ),
            FilledButton(
              onPressed: () {
                final reason = controller.text.trim();
                if (reason.isEmpty) {
                  setDialogState(() => validationMessage = requiredMessage);
                  return;
                }
                Navigator.pop(context, reason);
              },
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }
}

class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 40,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    ),
  );
}

class AdminErrorState extends StatelessWidget {
  const AdminErrorState({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    super.key,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: 40,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          FilledButton.tonal(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    ),
  );
}

class AdminLoadingList extends StatelessWidget {
  const AdminLoadingList({this.itemCount = 5, super.key});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final placeholder = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      itemCount: itemCount,
      itemBuilder: (context, index) => Card(
        elevation: AppElevation.none,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: placeholder),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: AppSpacing.md,
                      width: AppLayout.skeletonShortWidth,
                      decoration: BoxDecoration(
                        color: placeholder,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      height: AppSpacing.sm,
                      width: AppLayout.skeletonLongWidth,
                      decoration: BoxDecoration(
                        color: placeholder,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminFilterBar extends StatelessWidget {
  const AdminFilterBar({
    required this.controller,
    required this.searchLabel,
    required this.onSearchChanged,
    required this.filters,
    this.clearSearchLabel,
    this.onClear,
    this.sort,
    this.action,
    super.key,
  });

  final TextEditingController controller;
  final String searchLabel;
  final ValueChanged<String> onSearchChanged;
  final List<Widget> filters;
  final String? clearSearchLabel;
  final VoidCallback? onClear;
  final Widget? sort;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final actionWidget = action;
    final sortWidget = sort;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AppLayout.filterMinWidth,
            maxWidth: AppLayout.filterMaxWidth,
          ),
          child: TextField(
            controller: controller,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              labelText: searchLabel,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: controller.text.isEmpty || onClear == null
                  ? null
                  : IconButton(
                      tooltip: clearSearchLabel,
                      onPressed: onClear,
                      icon: const Icon(Icons.clear),
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        ...filters,
        ?sortWidget,
        ?actionWidget,
      ],
    );
  }
}
