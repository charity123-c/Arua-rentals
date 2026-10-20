import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/phone_normalizer.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/data/app_user.dart';
import '../../auth/presentation/auth_providers.dart';
import 'app_config_providers.dart';
import '../data/listing.dart';
import 'listing_copy.dart';
import 'listings_providers.dart';

class ListingFormScreen extends ConsumerStatefulWidget {
  const ListingFormScreen({
    this.listing,
    this.adminMode = false,
    super.key,
  });

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
      _imageUrlsController,
      _ownerIdController,
    ]) {
      controller.addListener(_markDirty);
    }
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

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentAppUserProvider).asData?.value;
    final isAdmin = widget.adminMode &&
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
          title: Text(_isEditing ? ListingCopy.editTitle : ListingCopy.createTitle),
        ),
        body: ref.watch(appConfigProvider).when(
          loading: () => const LoadingView(),
          error: (error, stackTrace) => ErrorView(
            message: error is AppException
                ? error.message
                : ListingCopy.invalidOwner,
            retryLabel: ListingCopy.save,
            onRetry: () => ref.invalidate(appConfigProvider),
          ),
          data: (config) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
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
              DropdownButtonFormField<ListingType>(
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
              ),
              DropdownButtonFormField<String>(
                initialValue: _validOrNull(
                  _category,
                  config.activeCategoryLabels,
                ),
                decoration: const InputDecoration(
                  labelText: ListingCopy.category,
                ),
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
              ),
              DropdownButtonFormField<String>(
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
              ),
              _textField(
                controller: _priceController,
                label: ListingCopy.price,
                keyboardType: TextInputType.number,
                validator: (value) {
                  final parsed = int.tryParse(value?.trim() ?? '');
                  return parsed == null || parsed <= 0
                      ? ListingCopy.invalidPrice
                      : null;
                },
              ),
              DropdownButtonFormField<ListingPriceUnit>(
                initialValue: _priceUnit,
                decoration: const InputDecoration(
                  labelText: ListingCopy.priceUnit,
                ),
                items: [
                  for (final unit in ListingPriceUnit.values)
                    DropdownMenuItem(
                      value: unit,
                      child: Text(unit.name),
                    ),
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
              ),
              if (_type == ListingType.property) ...[
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
              Text(ListingCopy.amenities, style: Theme.of(context).textTheme.titleMedium),
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
                spacing: 8,
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
              _textField(
                controller: _phoneController,
                label: ListingCopy.contactPhone,
                keyboardType: TextInputType.phone,
                validator: (value) => normalizeUgandanPhone(value ?? '') == null
                    ? ListingCopy.invalidPhone
                    : null,
              ),
              _textField(
                controller: _imageUrlsController,
                label: ListingCopy.imageUrls,
                helperText: ListingCopy.imageUrlHelp,
                maxLines: 3,
              ),
              if (isAdmin && !_isEditing)
                _textField(
                  controller: _ownerIdController,
                  label: ListingCopy.ownerId,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? ListingCopy.invalidOwner
                      : null,
                ),
              if (isAdmin && !_isEditing)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(ListingCopy.adminCreateApproved),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _isSaving ? null : () => _save(isAdmin),
                child: _isSaving
                    ? const CircularProgressIndicator()
                    : const Text(ListingCopy.save),
              ),
            ],
          ),
        ),
        ),
      ),
    );
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
    padding: const EdgeInsets.only(bottom: 12),
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
