import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/app_data.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});
  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users - Admin'),
        backgroundColor: Colors.red[800],
      ),
      body: Column(
        children: [
          // STATS
          Card(
            margin: const EdgeInsets.all(12),
            child: ListTile(
              title: Text('Total Rentals: ${AppData.listings.length}'),
              subtitle: Text(
                'Total Providers: ${AppData.users.where((u) => u.role == 'provider').length}',
              ),
            ),
          ),

          // PENDING APPROVALS
          const Padding(
            padding: EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Pending Approvals',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ...AppData.listings
                    .where((l) => !l.isApproved)
                    .map(
                      (listing) => Card(
                        child: ListTile(
                          title: Text(listing.title),
                          subtitle: Text(
                            'By ${listing.providerName} - Awaiting approval',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.check,
                                  color: Colors.green,
                                ),
                                onPressed: () {
                                  setState(() => listing.isApproved = true);
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  setState(
                                    () => AppData.listings.remove(listing),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'All Users & Providers',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ...AppData.users.map(
                  (user) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(user.role[0].toUpperCase()),
                      ),
                      title: Text(user.name),
                      subtitle: Text('${user.role} - ${user.email}'),
                      trailing: user.role == 'admin'
                          ? null
                          : Switch(
                              value: user.isApproved,
                              onChanged: (val) {
                                setState(() => user.isApproved = val);
                              },
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[800],
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddProviderScreen()),
              ),
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text(
                'Add New Provider',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AddProviderScreen extends StatefulWidget {
  const AddProviderScreen({super.key});
  @override
  State<AddProviderScreen> createState() => _AddProviderScreenState();
}

class _AddProviderScreenState extends State<AddProviderScreen> {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Provider')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Provider Name'),
            ),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Provider Email / Phone',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                AppData.users.add(
                  AppUser(
                    id: DateTime.now().toString(),
                    name: nameCtrl.text,
                    email: emailCtrl.text,
                    role: 'provider',
                    isApproved: true,
                  ),
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Provider added! They can now login and upload',
                    ),
                  ),
                );
              },
              child: const Text('Create Provider Account'),
            ),
          ],
        ),
      ),
    );
  }
}
