import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProviderWorkspaceScreen extends StatefulWidget {
  const ProviderWorkspaceScreen({super.key});

  @override
  State<ProviderWorkspaceScreen> createState() =>
      _ProviderWorkspaceScreenState();
}

class _ProviderWorkspaceScreenState extends State<ProviderWorkspaceScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final List<Uint8List> _selectedPhotos = [];
  final List<_ProviderListing> _listings = [];
  String _role = 'Landlord';

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final files = await _imagePicker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;

    final photos = await Future.wait(files.map((file) => file.readAsBytes()));
    if (!mounted) return;
    setState(() => _selectedPhotos.addAll(photos));
  }

  void _addListing() {
    final title = _titleController.text.trim();
    if (title.isEmpty || _selectedPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a title and at least one photo.')),
      );
      return;
    }

    setState(() {
      _listings.insert(
        0,
        _ProviderListing(
          role: _role,
          title: title,
          location: _locationController.text.trim(),
          price: _priceController.text.trim(),
          photos: List.of(_selectedPhotos),
        ),
      );
      _titleController.clear();
      _locationController.clear();
      _priceController.clear();
      _selectedPhotos.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Listing added to your workspace.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandlord = _role == 'Landlord';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider workspace'),
        backgroundColor: const Color.fromARGB(255, 177, 212, 226),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'Landlord',
                label: Text('Landlord'),
                icon: Icon(Icons.home_work_outlined),
              ),
              ButtonSegment(
                value: 'Service provider',
                label: Text('Service provider'),
                icon: Icon(Icons.handyman_outlined),
              ),
            ],
            selected: {_role},
            onSelectionChanged: (selection) =>
                setState(() => _role = selection.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 20),
          Text(
            isLandlord ? 'Add a property' : 'Add a service',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: isLandlord ? 'Property title' : 'Service title',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: 'Location',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: isLandlord ? 'Rent (UGX)' : 'Starting price (UGX)',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickPhotos,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(
              _selectedPhotos.isEmpty
                  ? 'Choose photos'
                  : 'Add more photos (${_selectedPhotos.length})',
            ),
          ),
          if (_selectedPhotos.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedPhotos.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _selectedPhotos[index],
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: IconButton.filled(
                        tooltip: 'Remove photo',
                        onPressed: () =>
                            setState(() => _selectedPhotos.removeAt(index)),
                        icon: const Icon(Icons.close, size: 16),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(28, 28),
                          padding: EdgeInsets.zero,
                          backgroundColor: Colors.black54,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _addListing,
            icon: const Icon(Icons.publish_outlined),
            label: const Text('Add to my listings'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0A4D68),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'My listings (${_listings.length})',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_listings.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Your added properties and services will appear here.',
              ),
            )
          else
            ..._listings.map(_listingTile),
        ],
      ),
    );
  }

  Widget _listingTile(_ProviderListing listing) {
    final priceLabel = listing.price.isEmpty
        ? listing.role
        : 'UGX ${listing.price} · ${listing.role}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.memory(
            listing.photos.first,
            width: 64,
            height: 64,
            fit: BoxFit.cover,
          ),
        ),
        title: Text(listing.title),
        subtitle: Text(
          [
            listing.location,
            priceLabel,
          ].where((value) => value.isNotEmpty).join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text('${listing.photos.length} photos'),
      ),
    );
  }
}

class _ProviderListing {
  final String role;
  final String title;
  final String location;
  final String price;
  final List<Uint8List> photos;

  const _ProviderListing({
    required this.role,
    required this.title,
    required this.location,
    required this.price,
    required this.photos,
  });
}
