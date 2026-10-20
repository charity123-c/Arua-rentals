import 'package:flutter/material.dart';

import '../../services/app_data.dart';
import '../../models/listing_model.dart';

class UploadListingScreen extends StatefulWidget {
  const UploadListingScreen({super.key});
  @override
  State<UploadListingScreen> createState() => _UploadListingScreenState();
}

class _UploadListingScreenState extends State<UploadListingScreen> {
  final titleCtrl = TextEditingController();
  final locCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  String? imageName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload New Rental')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title e.g. 2 Bedroom in Arua',
              ),
            ),
            TextField(
              controller: locCtrl,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            TextField(
              controller: priceCtrl,
              decoration: const InputDecoration(labelText: 'Price per month'),
            ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              onPressed: () {
                setState(
                  () => imageName = 'house_${DateTime.now().millisecond}.jpg',
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Photo selected (mock). In real app, use image_picker',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.photo_library),
              label: Text(imageName ?? 'Select Photo'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A4D68),
                ),
                onPressed: () {
                  AppData.listings.add(
                    Listing(
                      id: DateTime.now().toString(),
                      title: titleCtrl.text,
                      location: locCtrl.text,
                      price: priceCtrl.text,
                      providerId: AppData.currentUser.id,
                      providerName: AppData.currentUser.name,
                      imagePath: imageName ?? '',
                      isApproved: false,
                    ),
                  );
                  Navigator.pop(context);
                },
                child: const Text(
                  'Submit for Admin Approval',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
