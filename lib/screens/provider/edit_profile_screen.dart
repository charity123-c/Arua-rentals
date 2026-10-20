import 'package:flutter/material.dart';

import '../../services/app_data.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController nameCtrl, phoneCtrl, bioCtrl;
  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: AppData.currentUser.name);
    phoneCtrl = TextEditingController(text: AppData.currentUser.phone);
    bioCtrl = TextEditingController(text: AppData.currentUser.bio);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Update My Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
            TextButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Use image_picker to upload real photo'),
                  ),
                );
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Change Photo'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name / Business Name',
              ),
            ),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            TextField(
              controller: bioCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText:
                    'Bio e.g. I am a plumber in Arua with 5 years experience',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);

                  AppData.currentUser.name = nameCtrl.text;
                  AppData.currentUser.phone = phoneCtrl.text;
                  AppData.currentUser.bio = bioCtrl.text;
                  if (!context.mounted) return;
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Profile Updated Successfully!'),
                    ),
                  );
                },
                child: const Text('SAVE PROFILE'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
