import '../screens/settings_screen.dart';
import '../screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  // A quick popup dialog to let the user type in their email
  void _showEmailDialog(BuildContext context, String uid, String currentEmail) {
    final emailController = TextEditingController(text: currentEmail);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add your email', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.bold)),
          content: TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'e.g. hello@splitsathi.com',
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final newEmail = emailController.text.trim();
                if (newEmail.isNotEmpty) {
                  // Save the new email directly to their Firestore profile!
                  await FirebaseFirestore.instance.collection('users').doc(uid).update({
                    'email': newEmail,
                  });
                  if (context.mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    return Drawer(
      child: user == null 
        ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
        : StreamBuilder<DocumentSnapshot>(
            // Listen LIVE to this specific user's database document
            stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.orange));
              }

              // Extract their real data from Firestore
              final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
              final name = userData['name'] ?? 'Guest User';
              final email = userData['email'] ?? '';
              final photoUrl = userData['photoUrl'];

              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  // 1. The Live Header!
                  UserAccountsDrawerHeader(
                    decoration: const BoxDecoration(
                      color: AppColors.orange, // Branded to your app!
                    ),
                    accountName: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, fontFamily: 'Nunito'),
                    ),
                    // Make the email area tappable!
                    accountEmail: GestureDetector(
                      onTap: () => _showEmailDialog(context, user.uid, email),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            email.isNotEmpty ? email : 'Enter your email',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: email.isNotEmpty ? FontWeight.w600 : FontWeight.w800,
                              color: email.isNotEmpty ? Colors.white : Colors.white.withOpacity(0.8),
                              decoration: email.isEmpty ? TextDecoration.underline : TextDecoration.none,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit, 
                            size: 14, 
                            color: Colors.white.withOpacity(0.8)
                          ),
                        ],
                      ),
                    ),
                    currentAccountPicture: CircleAvatar(
                      backgroundColor: Colors.white,
                      backgroundImage: (photoUrl != null && photoUrl.toString().isNotEmpty) 
                          ? NetworkImage(photoUrl) 
                          : null,
                      child: (photoUrl == null || photoUrl.toString().isEmpty)
                          ? const Icon(Icons.person, size: 40, color: AppColors.orange) 
                          : null,
                    ),
                  ),
                  
                  // Menu Items
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context); 
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ProfileScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context); // Close the drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SettingsScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('Helpdesk', style: TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context); 
                    },
                  ),
                  const Divider(), 
                  
                  // 4. The Logout Button
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent),
                    title: const Text(
                      'Logout',
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                    ),
                    onTap: () async {
                      Navigator.pop(context); 
                      await AuthService().signOut(); 
                    },
                  ),
                ],
              );
            },
          ),
    );
  }
}