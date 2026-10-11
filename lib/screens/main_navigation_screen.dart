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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircleAvatar(
              radius: 42,
              backgroundColor: Colors.deepOrange,
              child: Icon(Icons.person, size: 42, color: Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              'Welcome back',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Account details will appear here.'),
          ],
        ),
      ),
    );
  }
}
