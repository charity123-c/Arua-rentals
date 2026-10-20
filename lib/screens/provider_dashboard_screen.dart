import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'upload_media_screen.dart';

class ProviderDashboardScreen extends StatelessWidget {
  final String userId;
  final String userRole; // 'landlord' or 'provider'

  const ProviderDashboardScreen({
    super.key,
    required this.userId,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    String title = userRole == 'landlord' ? 'My Properties' : 'My Services';
    String uploadLabel = userRole == 'landlord'
        ? 'Add Property'
        : 'Add Service';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.deepOrange,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // StreamBuilder handles auto-refresh, but this is a nice UX touch
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Fetch ONLY the listings uploaded by this specific provider/landlord
        stream: FirebaseFirestore.instance
            .collection('listings')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          var myItems = snapshot.data?.docs ?? [];

          // --- EMPTY STATE UI ---
          if (myItems.isEmpty) {
            return _buildEmptyState(context, uploadLabel);
          }

          // --- LIST OF UPLOADS ---
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: myItems.length,
            itemBuilder: (context, index) {
              var doc = myItems[index];
              var data = doc.data() as Map<String, dynamic>;
              return _buildListingCard(context, doc.id, data);
            },
          );
        },
      ),
      // --- FLOATING ACTION BUTTON TO UPLOAD ---
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
        label: Text(uploadLabel),
      ),
    );
  }

  // --- WIDGET: Empty State ---
  Widget _buildEmptyState(BuildContext context, String uploadLabel) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 100,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 20),
            Text(
              "You haven't uploaded anything yet.",
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              "Tap the button below to add your first $uploadLabel and start earning!",
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET: Individual Listing Card ---
  Widget _buildListingCard(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    bool isVideo = data['mediaType'] == 'video';
    bool isApproved = data['isApproved'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Media Thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: data['imageUrl'] ?? '',
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => const SizedBox(
                    height: 160,
                    child: Icon(Icons.broken_image, size: 50),
                  ),
                ),
                // Video Overlay Icon
                if (isVideo)
                  Container(
                    height: 160,
                    width: double.infinity,
                    color: Colors.black26,
                    child: const Center(
                      child: Icon(
                        Icons.play_circle_fill,
                        color: Colors.white,
                        size: 60,
                      ),
                    ),
                  ),
                // Status Badge
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isApproved ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isApproved ? '✅ Live' : '⏳ Pending',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Details Section
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['title'] ?? 'No Title',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        data['location'] ?? 'Arua City',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      "UGX ${(data['price'] ?? 0).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showDeleteDialog(context, docId),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      label: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- FUNCTION: Delete Confirmation ---
  void _showDeleteDialog(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Listing?"),
        content: const Text(
          "This will permanently remove this property/service from the app.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('listings')
                  .doc(docId)
                  .delete();
              if (!context.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Listing deleted successfully")),
              );
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}
