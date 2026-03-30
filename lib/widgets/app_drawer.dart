import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // The Header - We will update this with real Firebase user data later!
          const UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blueAccent,
            ),
            accountName: Text(
              "Guest User",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            accountEmail: Text("guest@splitsathi.com"),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 40, color: Colors.blueAccent),
            ),
          ),
          
          // Menu Items
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile'),
            onTap: () {
              Navigator.pop(context); // Closes the drawer
              // TODO: Navigate to Profile Screen
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context); 
              // TODO: Navigate to Settings Screen
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Helpdesk'),
            onTap: () {
              Navigator.pop(context); 
              // TODO: Navigate to Helpdesk
            },
          ),
          const Divider(), // Adds a nice line separator
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text(
              'Logout',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
            onTap: () {
              Navigator.pop(context); 
              // TODO: Add Firebase Logout Logic here later
            },
          ),
        ],
      ),
    );
  }
}