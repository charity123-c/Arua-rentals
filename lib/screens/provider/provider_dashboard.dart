import 'package:flutter/material.dart';

import '../../services/app_data.dart';
import '../upload_listing_screen.dart';

class ProviderDashboard extends StatefulWidget {
  const ProviderDashboard({super.key});
  @override
  State<ProviderDashboard> createState() => _ProviderDashboardState();
}

class _ProviderDashboardState extends State<ProviderDashboard> {
  @override
  Widget build(BuildContext context) {
    final myListings = AppData.listings
        .where((l) => l.providerId == AppData.currentUser.id)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('Provider Panel - ${AppData.currentUser.name}'),
        backgroundColor: const Color(0xFF0A4D68),
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: ListTile(
              title: const Text('Your Listings'),
              trailing: Text('${myListings.length} houses'),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: myListings.length,
              itemBuilder: (c, i) {
                final l = myListings[i];
                return ListTile(
                  title: Text(l.title),
                  subtitle: Text(
                    l.isApproved ? 'Approved ✅' : 'Pending Approval ⏳',
                  ),
                  trailing: const Icon(Icons.image),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UploadListingScreen()),
          );
          setState(() {});
        },
        label: const Text('Upload House Photo'),
        icon: const Icon(Icons.add_a_photo),
      ),
    );
  }
}
