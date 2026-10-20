import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../listings/data/app_config.dart';
import '../../listings/presentation/app_config_providers.dart';
import 'admin_settings_copy.dart';

class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return config.when(
      loading: () => const LoadingView(),
      error: (error, stackTrace) => ErrorView(
        message: error is AppException ? error.message : AdminSettingsCopy.error,
        retryLabel: AdminSettingsCopy.retry,
        onRetry: () => ref.invalidate(appConfigProvider),
      ),
      data: (value) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _seedDefaults(context, ref),
              icon: const Icon(Icons.restart_alt),
              label: const Text(AdminSettingsCopy.seedDefaults),
            ),
          ),
          _ConfigSection(
            title: AdminSettingsCopy.categories,
            addLabel: AdminSettingsCopy.addCategory,
            options: value.categories,
            onSave: (items) => _save(
              context,
              ref,
              () => ref
                  .read(appConfigRepositoryProvider)
                  .saveCategories(items),
            ),
          ),
          const SizedBox(height: 24),
          _ConfigSection(
            title: AdminSettingsCopy.areas,
            addLabel: AdminSettingsCopy.addArea,
            options: value.areas,
            onSave: (items) => _save(
              context,
              ref,
              () => ref.read(appConfigRepositoryProvider).saveAreas(items),
            ),
          ),
        ],
      ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AdminSettingsCopy.saved)),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AdminSettingsCopy.seeded)),
        );
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
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _options = List.of(widget.options);
  }

  @override
  void didUpdateWidget(covariant _ConfigSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options != widget.options) {
      _options = List.of(widget.options);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          if (_options.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: EmptyView(
                title: AdminSettingsCopy.title,
                message: AdminSettingsCopy.noOptions,
              ),
            ),
          for (var index = 0; index < _options.length; index++)
            ListTile(
              title: Text(_options[index].label),
              subtitle: Text(_options[index].active
                  ? AdminSettingsCopy.active
                  : AdminSettingsCopy.inactive),
              leading: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: AdminSettingsCopy.moveUp,
                    onPressed: index == 0 || _isSaving
                        ? null
                        : () => _move(index, index - 1),
                    icon: const Icon(Icons.keyboard_arrow_up),
                  ),
                  IconButton(
                    tooltip: AdminSettingsCopy.moveDown,
                    onPressed: index == _options.length - 1 || _isSaving
                        ? null
                        : () => _move(index, index + 1),
                    icon: const Icon(Icons.keyboard_arrow_down),
                  ),
                ],
              ),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: AdminSettingsCopy.rename,
                    onPressed: _isSaving ? null : () => _rename(index),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: _options[index].active
                        ? AdminSettingsCopy.deactivate
                        : AdminSettingsCopy.activate,
                    onPressed: _isSaving ? null : () => _toggle(index),
                    icon: Icon(
                      _options[index].active
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ],
              ),
            ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _add,
                icon: const Icon(Icons.add),
                label: Text(widget.addLabel),
              ),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const CircularProgressIndicator()
                    : const Text(AdminSettingsCopy.save),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Future<void> _add() async {
    final label = await _askLabel();
    if (label == null) return;
    final id = _makeId(label);
    if (_options.any((option) => option.id == id)) {
      _showMessage(AdminSettingsCopy.required);
      return;
    }
    setState(() {
      _options.add(ConfigOption(id: id, label: label, active: true));
    });
  }

  Future<void> _rename(int index) async {
    final label = await _askLabel(initial: _options[index].label);
    if (label == null) return;
    final id = _makeId(label);
    if (_options.any((option) => option.id == id && option.id != _options[index].id)) {
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

  void _move(int from, int to) => setState(() {
    final item = _options.removeAt(from);
    _options.insert(to, item);
  });

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
