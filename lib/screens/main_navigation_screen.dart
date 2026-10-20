import 'package:flutter/material.dart';

import 'jumia_style_home_screen.dart';
import 'provider_detail_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final String userRole;
  final String userId;

  const MainNavigationScreen({
    super.key,
    this.userRole = 'tenant',
    this.userId = '',
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  List<Widget> _getScreens() {
    if (widget.userRole == 'landlord' || widget.userRole == 'provider') {
      return [
        const JumiaStyleHomeScreen(),
        ProviderDashboardScreen(
          userId: widget.userId,
          userRole: widget.userRole,
        ),
        const ProfileScreen(),
      ];
    }

    return const [JumiaStyleHomeScreen(), ProfileScreen()];
  }

  @override
  Widget build(BuildContext context) {
    final screens = _getScreens();

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.deepOrange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 42,
              backgroundColor: Colors.deepOrange,
              child: Icon(Icons.person, size: 42, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'Welcome back',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Arua Rentals & Services',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),
            _profileTile('Phone', '+256 700 000 000'),
            _profileTile('Role', 'Tenant / Provider'),
            _profileTile('Default payment', 'Mobile Money'),
            _profileTile('Saved address', 'Arua City'),
          ],
        ),
      ),
    );
  }

  Widget _profileTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value, style: TextStyle(color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}
