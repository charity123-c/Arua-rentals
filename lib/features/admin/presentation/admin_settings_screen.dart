import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/admin_widgets.dart';
import '../../listings/data/app_config.dart';
import '../../listings/presentation/app_config_providers.dart';
import 'admin_settings_copy.dart';

class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return config.when(
      loading: () => const AdminLoadingList(itemCount: 3),
      error: (error, stackTrace) => AdminErrorState(
        message: error is AppException
            ? error.message
            : AdminSettingsCopy.error,
        retryLabel: AdminSettingsCopy.retry,
        onRetry: () => ref.invalidate(appConfigProvider),
      ),
      data: (value) {
        final categorySection = _ConfigSection(
          title: AdminSettingsCopy.categories,
          addLabel: AdminSettingsCopy.addCategory,
          options: value.categories,
          onSave: (items) => _save(
            context,
            ref,
            () => ref.read(appConfigRepositoryProvider).saveCategories(items),
          ),
        );
        final areaSection = _ConfigSection(
          title: AdminSettingsCopy.areas,
          addLabel: AdminSettingsCopy.addArea,
          options: value.areas,
          onSave: (items) => _save(
            context,
            ref,
            () => ref.read(appConfigRepositoryProvider).saveAreas(items),
          ),
        );
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= AppLayout.wideBreakpoint;
            final sectionWidth = wide
                ? (constraints.maxWidth - AppSpacing.md) / 2
                : constraints.maxWidth;
            return ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              children: [
                const AdminPageHeader(
                  title: AdminSettingsCopy.title,
                  subtitle: AdminSettingsCopy.settingsSubtitle,
                ),
                AdminSectionCard(
                  title: AdminSettingsCopy.seedDefaults,
                  subtitle: AdminSettingsCopy.seedDefaultsDescription,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => _seedDefaults(context, ref),
                      icon: const Icon(Icons.restart_alt),
                      label: const Text(AdminSettingsCopy.seedDefaults),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    SizedBox(width: sectionWidth, child: categorySection),
                    SizedBox(width: sectionWidth, child: areaSection),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      ref.invalidate(appConfigProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AdminSettingsCopy.saved)));
      }
    } on AppException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _seedDefaults(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(appConfigRepositoryProvider).seedDefaults();
      ref.invalidate(appConfigProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AdminSettingsCopy.seeded)));
      }
    } on AppException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

class _ConfigSection extends StatefulWidget {
  const _ConfigSection({
    required this.title,
    required this.addLabel,
    required this.options,
    required this.onSave,
  });

  final String title;
  final String addLabel;
  final List<ConfigOption> options;
  final Future<void> Function(List<ConfigOption>) onSave;

  @override
  State<_ConfigSection> createState() => _ConfigSectionState();
}

class _ConfigSectionState extends State<_ConfigSection> {
  late List<ConfigOption> _options;
  final _addController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _options = List.of(widget.options);
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ConfigSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options != widget.options) {
      _options = List.of(widget.options);
    }
  }

  @override
  Widget build(BuildContext context) => AdminSectionCard(
    title: widget.title,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_options.isEmpty)
          const AdminEmptyState(
            title: AdminSettingsCopy.title,
            message: AdminSettingsCopy.noOptions,
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: _options.length,
            onReorderItem: _move,
            itemBuilder: (context, index) {
              final option = _options[index];
              return ListTile(
                key: ValueKey(option.id),
                leading: ReorderableDragStartListener(
                  index: index,
                  child: const SizedBox.square(
                    dimension: AppLayout.minimumTapTarget,
                    child: Icon(Icons.drag_handle),
                  ),
                ),
                title: Text(option.label),
                subtitle: Text(
                  option.active
                      ? AdminSettingsCopy.active
                      : AdminSettingsCopy.inactive,
                ),
                trailing: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(
                      tooltip: AdminSettingsCopy.rename,
                      onPressed: _isSaving ? null : () => _rename(index),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    Switch(
                      value: option.active,
                      onChanged: _isSaving ? null : (_) => _toggle(index),
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _addController,
          enabled: !_isSaving,
          maxLength: 60,
          onSubmitted: (_) => _add(),
          decoration: InputDecoration(
            labelText: widget.addLabel,
            helperText: AdminSettingsCopy.label,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _add,
              icon: const Icon(Icons.add),
              label: Text(widget.addLabel),
            ),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox.square(
                      dimension: AppSpacing.lg,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(AdminSettingsCopy.save),
            ),
          ],
        ),
      ],
    ),
  );

  void _add() {
    final label = _addController.text.trim();
    if (label.isEmpty) {
      _showMessage(AdminSettingsCopy.required);
      return;
    }
    final id = _makeId(label);
    if (_options.any((option) => option.id == id)) {
      _showMessage(AdminSettingsCopy.required);
      return;
    }
    setState(() {
      _options.add(ConfigOption(id: id, label: label, active: true));
      _addController.clear();
    });
  }

  Future<void> _rename(int index) async {
    final label = await _askLabel(initial: _options[index].label);
    if (label == null) return;
    final id = _makeId(label);
    if (_options.any(
      (option) => option.id == id && option.id != _options[index].id,
    )) {
      _showMessage(AdminSettingsCopy.required);
      return;
    }
    setState(() {
      _options[index] = ConfigOption(
        id: id,
        label: label,
        active: _options[index].active,
      );
    });
  }

  void _toggle(int index) => setState(() {
    final old = _options[index];
    _options[index] = ConfigOption(
      id: old.id,
      label: old.label,
      active: !old.active,
    );
  });

  void _move(int from, int to) {
    setState(() {
      final item = _options.removeAt(from);
      _options.insert(to, item);
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await widget.onSave(List.unmodifiable(_options));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<String?> _askLabel({String initial = ''}) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.addLabel),
        scrollable: true,
        content: TextField(
          controller: controller,
          maxLength: 60,
          decoration: const InputDecoration(labelText: AdminSettingsCopy.label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AdminSettingsCopy.cancel),
          ),
          FilledButton(
            onPressed: () {
              final label = controller.text.trim();
              if (label.isNotEmpty) Navigator.pop(context, label);
            },
            child: const Text(AdminSettingsCopy.save),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _makeId(String label) => label
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}
