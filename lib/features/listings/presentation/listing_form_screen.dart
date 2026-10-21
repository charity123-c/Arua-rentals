import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/admin_widgets.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/utils/phone_normalizer.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/data/app_user.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/app_config.dart';
import '../../admin/presentation/admin_copy.dart';
import 'app_config_providers.dart';
import '../data/listing.dart';
import 'listing_copy.dart';
import 'listings_providers.dart';

class ListingFormScreen extends ConsumerStatefulWidget {
  const ListingFormScreen({this.listing, this.adminMode = false, super.key});

  final Listing? listing;
  final bool adminMode;

  @override
  ConsumerState<ListingFormScreen> createState() => _ListingFormScreenState();
}

class _ListingFormScreenState extends ConsumerState<ListingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _bedroomsController = TextEditingController();
  final _bathroomsController = TextEditingController();
  final _phoneController = TextEditingController();
  final _imageUrlsController = TextEditingController();
  final _ownerIdController = TextEditingController();
  final _amenityController = TextEditingController();
  final _amenities = <String>[];
  late ListingType _type;
  late ListingPriceUnit _priceUnit;
  String? _category;
  String? _area;
  bool _isSaving = false;
  bool _isDirty = false;

  bool get _isEditing => widget.listing != null;

  @override
  void initState() {
    super.initState();
    final listing = widget.listing;
    _titleController.text = listing?.title ?? '';
    _descriptionController.text = listing?.description ?? '';
    _priceController.text = listing?.priceUgx.toString() ?? '';
    _bedroomsController.text = listing?.bedrooms?.toString() ?? '';
    _bathroomsController.text = listing?.bathrooms?.toString() ?? '';
    _phoneController.text = listing?.ownerPhone ?? '';
    _imageUrlsController.text = listing?.imageUrls.join('\n') ?? '';
    _ownerIdController.text = listing?.ownerId ?? '';
    _amenities.addAll(listing?.amenities ?? const []);
    _type = listing?.type ?? ListingType.property;
    _priceUnit = listing?.priceUnit ?? ListingPriceUnit.month;
    _category = listing?.category;
    _area = listing?.area;
    for (final controller in [
      _titleController,
      _descriptionController,
      _priceController,
      _bedroomsController,
      _bathroomsController,
      _phoneController,
      _ownerIdController,
    ]) {
      controller.addListener(_markDirty);
    }
    _imageUrlsController.addListener(_markImageUrlsDirty);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    _phoneController.dispose();
    _imageUrlsController.dispose();
    _ownerIdController.dispose();
    _amenityController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_isDirty && mounted) setState(() => _isDirty = true);
  }

  void _markImageUrlsDirty() {
    if (mounted) setState(() => _isDirty = true);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentAppUserProvider).asData?.value;
    final isAdmin =
        widget.adminMode &&
        currentUser?.hasAdminClaim == true &&
        currentUser?.role == UserRole.admin;
    return PopScope(
      canPop: !_isDirty && !_isSaving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _isSaving || !_isDirty) return;
        final discard = await _confirmDiscard();
        if (!context.mounted) return;
        if (discard) context.pop(false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEditing ? ListingCopy.editTitle : ListingCopy.createTitle,
          ),
        ),
        body: ref
            .watch(appConfigProvider)
            .when(
              loading: () => widget.adminMode
                  ? const AdminLoadingList(itemCount: 4)
                  : const LoadingView(),
              error: (error, stackTrace) {
                final message = error is AppException
                    ? error.message
                    : ListingCopy.invalidOwner;
                return widget.adminMode
                    ? AdminErrorState(
                        message: message,
                        retryLabel: ListingCopy.retry,
                        onRetry: () => ref.invalidate(appConfigProvider),
                      )
                    : ErrorView(
                        message: message,
                        retryLabel: ListingCopy.retry,
                        onRetry: () => ref.invalidate(appConfigProvider),
                      );
              },
              data: (config) => widget.adminMode
                  ? _adminForm(config, isAdmin)
                  : _legacyForm(config, isAdmin),
            ),
      ),
    );
  }

  Widget _adminForm(AppConfig config, bool isAdmin) => Form(
    key: _formKey,
    child: Column(
      children: [
        Expanded(
          child: AdminContent(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= AppLayout.wideBreakpoint
                    ? 2
                    : 1;
                final width = columns == 1
                    ? constraints.maxWidth
                    : (constraints.maxWidth - AppSpacing.md) / columns;
                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  children: [
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: [
                        SizedBox(width: width, child: _basicsSection()),
                        SizedBox(width: width, child: _priceSection()),
                        SizedBox(width: width, child: _locationSection(config)),
                        SizedBox(width: width, child: _detailsSection()),
                        SizedBox(width: width, child: _photosSection()),
                        SizedBox(width: width, child: _contactSection(isAdmin)),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Material(
            elevation: AppElevation.medium,
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: AppInsets.phonePage,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _cancel,
                      child: const Text(ListingCopy.cancel),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSaving ? null : () => _save(isAdmin),
                      child: _isSaving
                          ? const SizedBox.square(
                              dimension: AppSpacing.lg,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(ListingCopy.save),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _legacyForm(AppConfig config, bool isAdmin) => Form(
    key: _formKey,
    child: ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _basicsFields(),
        _listingTypeField(),
        _categoryField(config),
        _areaField(config),
        _priceField(),
        _priceUnitField(),
        _bedroomFields(),
        _amenitiesEditor(),
        _phoneField(),
        _imageUrlsField(),
        if (isAdmin && !_isEditing) _ownerIdField(),
        if (isAdmin && !_isEditing)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xxs),
            child: Text(ListingCopy.adminCreateApproved),
          ),
        FilledButton(
          onPressed: _isSaving ? null : () => _save(isAdmin),
          child: _isSaving
              ? const CircularProgressIndicator()
              : const Text(ListingCopy.save),
        ),
      ],
    ),
  );

  Widget _basicsSection() =>
      AdminSectionCard(title: AdminCopy.basics, child: _basicsFields());

  Widget _basicsFields() => Column(
    children: [
      _textField(
        controller: _titleController,
        label: ListingCopy.title,
        maxLength: 100,
        validator: _required,
      ),
      _textField(
        controller: _descriptionController,
        label: ListingCopy.description,
        maxLength: 3000,
        maxLines: 5,
        validator: _required,
      ),
    ],
  );

  Widget _priceSection() => AdminSectionCard(
    title: AdminCopy.priceAndType,
    child: Column(
      children: [_listingTypeField(), _priceField(), _priceUnitField()],
    ),
  );

  Widget _locationSection(AppConfig config) => AdminSectionCard(
    title: AdminCopy.location,
    child: Column(children: [_categoryField(config), _areaField(config)]),
  );

  Widget _detailsSection() => AdminSectionCard(
    title: AdminCopy.details,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_bedroomFields(), _amenitiesEditor()],
    ),
  );

  Widget _photosSection() => AdminSectionCard(
    title: AdminCopy.photos,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _imageUrlsField(),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final url
                in _imageUrlsController.text
                    .split(RegExp(r'[\r\n]+'))
                    .map((value) => value.trim())
                    .where((value) => value.isNotEmpty)
                    .take(8))
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: AppNetworkImage(
                  imageUrl: url,
                  semanticLabel: AdminCopy.imagePreview,
                  width: AppLayout.imagePreviewSize,
                  height: AppLayout.imagePreviewSize,
                ),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _contactSection(bool isAdmin) => AdminSectionCard(
    title: AdminCopy.contact,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _phoneField(),
        if (isAdmin && !_isEditing) ...[
          _ownerIdField(),
          Text(
            ListingCopy.adminCreateApproved,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    ),
  );

  Widget _listingTypeField() => DropdownButtonFormField<ListingType>(
    initialValue: _type,
    decoration: const InputDecoration(labelText: ListingCopy.type),
    items: const [
      DropdownMenuItem(
        value: ListingType.property,
        child: Text(ListingCopy.property),
      ),
      DropdownMenuItem(
        value: ListingType.service,
        child: Text(ListingCopy.service),
      ),
    ],
    onChanged: _isSaving
        ? null
        : (value) {
            if (value == null) return;
            setState(() {
              _type = value;
              _isDirty = true;
            });
          },
  );

  Widget _categoryField(AppConfig config) => DropdownButtonFormField<String>(
    initialValue: _validOrNull(_category, config.activeCategoryLabels),
    decoration: const InputDecoration(labelText: ListingCopy.category),
    validator: (value) => value == null ? ListingCopy.required : null,
    items: [
      for (final category in config.activeCategoryLabels)
        DropdownMenuItem(value: category, child: Text(category)),
    ],
    onChanged: _isSaving
        ? null
        : (value) => setState(() {
            _category = value;
            _isDirty = true;
          }),
  );

  Widget _areaField(AppConfig config) => DropdownButtonFormField<String>(
    initialValue: _validOrNull(_area, config.activeAreaLabels),
    decoration: const InputDecoration(labelText: ListingCopy.area),
    validator: (value) => value == null ? ListingCopy.required : null,
    items: [
      for (final area in config.activeAreaLabels)
        DropdownMenuItem(value: area, child: Text(area)),
    ],
    onChanged: _isSaving
        ? null
        : (value) => setState(() {
            _area = value;
            _isDirty = true;
          }),
  );

  Widget _priceField() => _textField(
    controller: _priceController,
    label: ListingCopy.price,
    keyboardType: TextInputType.number,
    validator: (value) {
      final parsed = int.tryParse(value?.trim() ?? '');
      return parsed == null || parsed <= 0 ? ListingCopy.invalidPrice : null;
    },
  );

  Widget _priceUnitField() => DropdownButtonFormField<ListingPriceUnit>(
    initialValue: _priceUnit,
    decoration: const InputDecoration(labelText: ListingCopy.priceUnit),
    items: [
      for (final unit in ListingPriceUnit.values)
        DropdownMenuItem(value: unit, child: Text(unit.name)),
    ],
    onChanged: _isSaving
        ? null
        : (value) {
            if (value == null) return;
            setState(() {
              _priceUnit = value;
              _isDirty = true;
            });
          },
  );

  Widget _bedroomFields() => _type == ListingType.property
      ? Column(
          children: [
            _textField(
              controller: _bedroomsController,
              label: ListingCopy.bedrooms,
              keyboardType: TextInputType.number,
              validator: _optionalPositiveInt,
            ),
            _textField(
              controller: _bathroomsController,
              label: ListingCopy.bathrooms,
              keyboardType: TextInputType.number,
              validator: _optionalPositiveInt,
            ),
          ],
        )
      : const SizedBox.shrink();

  Widget _amenitiesEditor() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        ListingCopy.amenities,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _amenityController,
              decoration: const InputDecoration(
                labelText: ListingCopy.addAmenity,
              ),
              onSubmitted: (_) => _addAmenity(),
            ),
          ),
          IconButton(
            tooltip: ListingCopy.addAmenity,
            onPressed: _isSaving ? null : _addAmenity,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final amenity in _amenities)
            InputChip(
              label: Text(amenity),
              onDeleted: _isSaving
                  ? null
                  : () => setState(() {
                      _amenities.remove(amenity);
                      _isDirty = true;
                    }),
            ),
        ],
      ),
    ],
  );

  Widget _phoneField() => _textField(
    controller: _phoneController,
    label: ListingCopy.contactPhone,
    keyboardType: TextInputType.phone,
    validator: (value) => normalizeUgandanPhone(value ?? '') == null
        ? ListingCopy.invalidPhone
        : null,
  );

  Widget _imageUrlsField() => _textField(
    controller: _imageUrlsController,
    label: ListingCopy.imageUrls,
    helperText: ListingCopy.imageUrlHelp,
    maxLines: 3,
  );

  Widget _ownerIdField() => _textField(
    controller: _ownerIdController,
    label: ListingCopy.ownerId,
    validator: (value) =>
        value == null || value.trim().isEmpty ? ListingCopy.invalidOwner : null,
  );

  Future<void> _cancel() async {
    if (_isSaving) return;
    if (!_isDirty) {
      context.pop(false);
      return;
    }
    final discard = await _confirmDiscard();
    if (!mounted) return;
    if (discard) context.pop(false);
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    String? helperText,
    int? maxLength,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: TextFormField(
      controller: controller,
      enabled: !_isSaving,
      maxLength: maxLength,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        border: const OutlineInputBorder(),
      ),
      validator: validator,
    ),
  );

  void _addAmenity() {
    final value = _amenityController.text.trim();
    if (value.isEmpty || _amenities.contains(value)) return;
    setState(() {
      _amenities.add(value);
      _amenityController.clear();
      _isDirty = true;
    });
  }

  Future<void> _save(bool isAdmin) async {
    if (!_formKey.currentState!.validate()) return;
    final normalizedPhone = normalizeUgandanPhone(_phoneController.text);
    if (normalizedPhone == null) return;

    setState(() => _isSaving = true);
    try {
      final uploader = ref.read(mediaUploaderProvider);
      final imageUrls = await uploader.uploadImages(
        _imageUrlsController.text
            .split(RegExp(r'[\r\n]+'))
            .map((url) => url.trim())
            .where((url) => url.isNotEmpty)
            .toList(),
      );
      final oldListing = widget.listing;
      final listing = Listing(
        id: oldListing?.id ?? '',
        ownerId: oldListing?.ownerId ?? _ownerIdController.text.trim(),
        ownerName: oldListing?.ownerName ?? '',
        ownerPhone: normalizedPhone,
        type: _type,
        category: _category!,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        priceUgx: int.parse(_priceController.text.trim()),
        priceUnit: _priceUnit,
        area: _area!,
        address: oldListing?.address,
        geo: oldListing?.geo,
        bedrooms: _type == ListingType.property
            ? int.tryParse(_bedroomsController.text.trim())
            : null,
        bathrooms: _type == ListingType.property
            ? int.tryParse(_bathroomsController.text.trim())
            : null,
        amenities: List.unmodifiable(_amenities),
        imageUrls: imageUrls,
        thumbnailUrl: imageUrls.isEmpty ? '' : imageUrls.first,
        videoUrl: oldListing?.videoUrl,
        status: ListingStatus.pending,
        rejectionReason: oldListing?.rejectionReason,
        ratingAvg: oldListing?.ratingAvg ?? 0,
        ratingCount: oldListing?.ratingCount ?? 0,
        searchKeywords: const [],
        isFeatured: oldListing?.isFeatured ?? false,
        createdAt: oldListing?.createdAt,
        updatedAt: oldListing?.updatedAt,
      );
      final repository = ref.read(listingsRepositoryProvider);
      if (_isEditing) {
        await repository.update(listing);
      } else {
        await repository.create(
          listing,
          ownerId: isAdmin ? _ownerIdController.text.trim() : null,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? ListingCopy.updated : ListingCopy.created),
        ),
      );
      context.pop(true);
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? ListingCopy.required : null;

  String? _optionalPositiveInt(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = int.tryParse(value.trim());
    return parsed == null || parsed <= 0 ? ListingCopy.invalidCount : null;
  }

  String? _validOrNull(String? value, List<String> values) =>
      values.contains(value) ? value : null;

  Future<bool> _confirmDiscard() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(ListingCopy.confirmDiscardTitle),
          content: const Text(ListingCopy.confirmDiscardMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(ListingCopy.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(ListingCopy.confirm),
            ),
          ],
        ),
      ) ??
      false;
}
