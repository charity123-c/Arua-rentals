import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UploadMediaScreen extends StatefulWidget {
  final String userId;
  final String userRole;

  const UploadMediaScreen({
    super.key,
    required this.userId,
    required this.userRole,
  });

  @override
  UploadMediaScreenState createState() => UploadMediaScreenState();
}

class UploadMediaScreenState extends State<UploadMediaScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedFile;
  String _mediaType = 'image'; // 'image' or 'video'
  bool _isUploading = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  Future<void> _pickMedia() async {
    if (_mediaType == 'image') {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) setState(() => _selectedFile = File(image.path));
    } else {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) setState(() => _selectedFile = File(video.path));
    }
  }

  Future<void> _uploadToFirebase() async {
    if (_selectedFile == null || _titleController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select media and enter a title")),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final String folder = widget.userRole == 'landlord'
          ? 'properties'
          : 'services';
      final Reference ref = FirebaseStorage.instance.ref().child(
        '$folder/$fileName',
      );
      final UploadTask task = ref.putFile(_selectedFile!);
      final TaskSnapshot snapshot = await task;
      final String url = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('listings').add({
        'userId': widget.userId,
        'userRole': widget.userRole,
        'title': _titleController.text,
        'price': double.tryParse(_priceController.text) ?? 0,
        'imageUrl': url,
        'mediaType': _mediaType,
        'createdAt': FieldValue.serverTimestamp(),
        'rating': 0.0,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Uploaded successfully!")));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Upload Media"),
        backgroundColor: Colors.deepOrange,
      ),
      body: _isUploading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Toggle between Image and Video
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text("Photo"),
                        selected: _mediaType == 'image',
                        selectedColor: Colors.deepOrange,
                        onSelected: (val) => setState(() {
                          _mediaType = 'image';
                          _selectedFile = null;
                        }),
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text("Video"),
                        selected: _mediaType == 'video',
                        selectedColor: Colors.deepOrange,
                        onSelected: (val) => setState(() {
                          _mediaType = 'video';
                          _selectedFile = null;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Media Preview Area
                  GestureDetector(
                    onTap: _pickMedia,
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: _selectedFile == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _mediaType == 'image'
                                      ? Icons.add_a_photo
                                      : Icons.videocam,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                                const Text("Tap to select"),
                              ],
                            )
                          : (_mediaType == 'image'
                                ? Image.file(_selectedFile!, fit: BoxFit.cover)
                                : const Icon(
                                    Icons.play_circle_fill,
                                    size: 60,
                                    color: Colors.red,
                                  )),
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: "Title",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Price (UGX)",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _uploadToFirebase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                      ),
                      child: const Text(
                        "PUBLISH",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
