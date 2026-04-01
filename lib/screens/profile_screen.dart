import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // A list of 12 beautiful, open-source avatars!
  static const List<String> _avatars = [
    'https://api.dicebear.com/7.x/avataaars/png?seed=Felix&backgroundColor=ffdfbf',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Aneka&backgroundColor=c0aede',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Jack&backgroundColor=b6e3f4',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Jude&backgroundColor=ffdfbf',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Avery&backgroundColor=d1d4f9',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Destiny&backgroundColor=c0aede',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Caleb&backgroundColor=b6e3f4',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Molly&backgroundColor=ffdfbf',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Sam&backgroundColor=d1d4f9',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Oliver&backgroundColor=c0aede',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Leo&backgroundColor=b6e3f4',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Mia&backgroundColor=d1d4f9',
  ];

  // --- THE NEW AVATAR PICKER SHEET ---
  void _showAvatarPicker(BuildContext context, String uid, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Little drag handle
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Text(
                'Choose an Avatar',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 24),
              // The Grid of Avatars
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _avatars.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () async {
                      // Save the chosen avatar straight to Firestore!
                      await FirebaseFirestore.instance.collection('users').doc(uid).update({
                        'photoUrl': _avatars[index],
                      });
                      if (context.mounted) Navigator.pop(context); // Close sheet
                    },
                    child: CircleAvatar(
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: NetworkImage(_avatars[index]),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  // The Edit Name Dialog
  void _showEditNameDialog(BuildContext context, String uid, String currentName) {
    final nameController = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Name', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.bold)),
          content: TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
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
                final newName = nameController.text.trim();
                if (newName.isNotEmpty) {
                  await FirebaseFirestore.instance.collection('users').doc(uid).update({'name': newName});
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
    final isDark = context.watch<AppProvider>().isDark;
    final bg = isDark ? AppColors.darkBg : AppColors.cream;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1C);
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;
    
    final user = AuthService().currentUser;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.orange));
                }

                final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                final name = userData['name'] ?? 'Guest User';
                final email = userData['email'] ?? 'No email linked';
                final phone = userData['phone'] ?? 'No phone linked';
                final photoUrl = userData['photoUrl'];

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      
                      // Avatar Area with Edit Badge
                      GestureDetector(
                        onTap: () => _showAvatarPicker(context, user.uid, isDark),
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: AppColors.orange.withOpacity(0.2),
                              backgroundImage: (photoUrl != null && photoUrl.toString().isNotEmpty) 
                                  ? NetworkImage(photoUrl) 
                                  : null,
                              child: (photoUrl == null || photoUrl.toString().isEmpty)
                                  ? const Icon(Icons.person, size: 60, color: AppColors.orange) 
                                  : null,
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.orange,
                                shape: BoxShape.circle,
                                border: Border.all(color: bg, width: 3),
                              ),
                              child: const Icon(Icons.edit, size: 20, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Name & Edit Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name,
                            style: TextStyle(fontFamily: 'Nunito', fontSize: 28, fontWeight: FontWeight.w900, color: textColor),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _showEditNameDialog(context, user.uid, name),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: AppColors.orange.withOpacity(0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.edit, size: 18, color: AppColors.orange),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Info Cards
                      Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                        ),
                        child: Column(
                          children: [
                            _buildInfoRow(Icons.phone_outlined, 'Phone Number', phone, textColor, isDark),
                            Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.border),
                            _buildInfoRow(Icons.email_outlined, 'Email Address', email, textColor, isDark),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color textColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.orange),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkMuted : AppColors.muted)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: textColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}