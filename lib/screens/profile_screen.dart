import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _user = AuthService().currentUser;
  
  bool _isSaving = false;
  String _originalEmail = "";

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // --- 1. SAVE NAME LOGIC ---
  Future<void> _saveProfileName() async {
    if (_user == null) return;
    
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
        'name': _nameController.text.trim(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Name updated successfully!'), backgroundColor: Colors.green.shade600),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- 2. EMAIL EDIT FLOW (STEP 1: GET NEW EMAIL) ---
  void _startEmailChangeFlow() {
    final newEmailCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change Email', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: newEmailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: "Enter new email address",
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              final newEmail = newEmailCtrl.text.trim();
              if (newEmail.isNotEmpty && newEmail != _originalEmail) {
                Navigator.pop(ctx); // Close step 1
                _showOtpDialog(newEmail); // Open step 2
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Send OTP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      )
    );
  }

  // --- 3. EMAIL EDIT FLOW (STEP 2: VERIFY OTP) ---
  void _showOtpDialog(String newEmail) {
    final otpCtrl = TextEditingController();
    // In a real app, your backend sends the email OTP here.
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Verify Email', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('We sent a 6-digit code to $newEmail. Enter it below to verify.'),
            const SizedBox(height: 24),
            TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                counterText: "",
                hintText: "000000",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              final enteredOtp = otpCtrl.text.trim();
              if (enteredOtp.length == 6) { 
                // MOCK VERIFICATION SUCCESS
                Navigator.pop(ctx); 
                await _saveNewEmailToDatabase(newEmail); 
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a 6-digit OTP.')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Verify & Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      )
    );
  }

  // --- 4. EMAIL EDIT FLOW (STEP 3: SAVE TO DB) ---
  Future<void> _saveNewEmailToDatabase(String verifiedEmail) async {
    HapticFeedback.mediumImpact();
    try {
      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
        'email': verifiedEmail,
      });
      setState(() {
        _originalEmail = verifiedEmail;
        _emailController.text = verifiedEmail;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Email updated successfully!'), backgroundColor: Colors.green.shade600));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showAvatarPicker() {
    // Premium minimalist avatars
    final List<String> avatarSeeds = ['Felix', 'Aneka', 'Jocelyn', 'Mimi', 'Jack', 'Eden', 'Leo', 'Jade'];
    final isDark = Provider.of<AppProvider>(context, listen: false).isDark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose an Avatar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, crossAxisSpacing: 16, mainAxisSpacing: 16
              ),
              itemCount: avatarSeeds.length + 1, // +1 for the "Initials" option
              itemBuilder: (context, index) {
                if (index == avatarSeeds.length) {
                  // The "Reset to Initials" button
                  return GestureDetector(
                    onTap: () => _updateAvatarInDatabase(''), // Empty string triggers the initials fallback
                    child: Container(
                      decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
                      child: const Center(child: Text('A-Z', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                    ),
                  );
                }
                
                final url = 'https://api.dicebear.com/7.x/notionists/png?seed=${avatarSeeds[index]}&backgroundColor=transparent';
                return GestureDetector(
                  onTap: () => _updateAvatarInDatabase(url),
                  child: CircleAvatar(backgroundColor: AppColors.orange.withOpacity(0.1), backgroundImage: NetworkImage(url)),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _updateAvatarInDatabase(String url) async {
    Navigator.pop(context); // close sheet
    HapticFeedback.lightImpact();
    try {
      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({'photoUrl': url});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppProvider>().isDark;

    if (_user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.cream,
      // Wrap in GestureDetector to dismiss keyboard
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(_user!.uid).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.orange));
            
            final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
            
            if (_nameController.text.isEmpty && !_isSaving) {
              _nameController.text = userData['name'] ?? '';
              _originalEmail = userData['email'] ?? '';
              _emailController.text = _originalEmail;
            }
            
            final photoUrl = userData['photoUrl'];
            final nameStr = userData['name'] ?? 'U';

            return SingleChildScrollView(
              child: Column(
                children: [
                  // --- PERFECTLY LAYERED HEADER ---
                  Stack(
                    clipBehavior: Clip.none, // Crucial: Allows avatar to break out of the orange box!
                    alignment: Alignment.bottomCenter,
                    children: [
                      // Orange Background
                      Container(
                        width: double.infinity,
                        height: 200,
                        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [AppColors.orange, Color(0xFFFB923C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
                            const Spacer(),
                            const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text('My Profile', style: TextStyle(fontFamily: 'Nunito', fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                            ),
                            const Spacer(),
                            const SizedBox(width: 48), // Balance for back button
                          ],
                        ),
                      ),
                    
                      // Overlapping Avatar with Edit Badge
                      Positioned(
                        bottom: -50,
                        child: GestureDetector(
                          onTap: _showAvatarPicker, // Opens the new picker!
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(color: isDark ? AppColors.darkBg : AppColors.cream, shape: BoxShape.circle),
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.white,
                                  backgroundImage: (photoUrl != null && photoUrl.toString().isNotEmpty) 
                                      ? NetworkImage(photoUrl) 
                                      : NetworkImage('https://ui-avatars.com/api/?name=${Uri.encodeComponent(nameStr)}&background=F97316&color=fff&bold=true&size=200') as ImageProvider,
                                ),
                              ),
                              // The little orange camera edit badge
                              Positioned(
                                bottom: 4, right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.orange, 
                                    shape: BoxShape.circle, 
                                    border: Border.all(color: isDark ? AppColors.darkBg : AppColors.cream, width: 3)
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Space for the overlapping avatar
                  const SizedBox(height: 70),

                  // --- FORM INPUTS ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInputLabel('FULL NAME', isDark),
                        _buildTextField(
                          controller: _nameController, 
                          icon: Icons.person_outline, 
                          isDark: isDark,
                        ),
                        
                        const SizedBox(height: 24),
                        
                        _buildInputLabel('EMAIL ADDRESS', isDark),
                        _buildTextField(
                          controller: _emailController, 
                          icon: Icons.email_outlined, 
                          isDark: isDark,
                          readOnly: true, // Lock this field
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.edit, color: AppColors.orange, size: 20),
                            onPressed: _startEmailChangeFlow, // Trigger OTP Flow
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Save Button (Only saves the name now, email is handled via OTP)
                        SizedBox(
                          width: double.infinity, height: 60,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveProfileName,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.orange,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 8, shadowColor: AppColors.orange.withOpacity(0.5),
                            ),
                            child: _isSaving 
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInputLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8), 
      child: Text(text, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5))
    );
  }

  Widget _buildTextField({required TextEditingController controller, required IconData icon, required bool isDark, bool readOnly = false, Widget? suffixIcon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? (readOnly ? Colors.white70 : Colors.white) : (readOnly ? Colors.black54 : Colors.black87)),
        decoration: InputDecoration(
          icon: Icon(icon, color: AppColors.orange, size: 22), 
          border: InputBorder.none,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}