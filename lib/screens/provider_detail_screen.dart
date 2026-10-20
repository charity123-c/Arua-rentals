import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'upload_media_screen.dart';

class ProviderDashboardScreen extends StatelessWidget {
  final String userId;
  final String userRole;

  const ProviderDashboardScreen({
    super.key,
    required this.userId,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${userRole == 'landlord' ? 'Landlord' : 'Service Provider'} Dashboard',
        ),
        backgroundColor: Colors.deepOrange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('listings')
            .where('userId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final myItems = snapshot.data!.docs;

          if (myItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "You haven't uploaded any ${userRole == 'landlord' ? 'properties' : 'services'} yet.",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: myItems.length,
            itemBuilder: (context, index) {
              final item = myItems[index].data() as Map<String, dynamic>;
              final isVideo = item['mediaType'] == 'video';

              return Card(
                child: ListTile(
                  leading: isVideo
                      ? const Icon(Icons.videocam, color: Colors.red, size: 40)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            item['imageUrl'],
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        ),
                  title: Text(
                    item['title'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "UGX ${item['price']} • ${isVideo ? 'Video' : 'Photo'}",
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {},
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  UploadMediaScreen(userId: userId, userRole: userRole),
            ),
          );
        },
        backgroundColor: Colors.deepOrange,
        icon: const Icon(Icons.add_a_photo),
        label: const Text("Upload New"),
      ),
    );
  }
}