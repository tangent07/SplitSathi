import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import 'home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  String _selectedCountryCode = '+91'; 
  bool _isLoading = false;

  // NEW: Smart variables to track what Firebase already knows!
  bool _isPhoneVerified = false;
  String _verifiedPhoneNumber = '';

  @override
  void initState() {
    super.initState();
    
    // Check what Firebase already knows about this user
    final user = AuthService().currentUser;
    if (user != null) {
      // 1. If Google Login: They have a name!
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        _nameController.text = user.displayName!;
      }
      
      // 2. If Phone Login: They have a verified phone number!
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        _isPhoneVerified = true;
        _verifiedPhoneNumber = user.phoneNumber!;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    
    // SMART CHECK: Use the verified number if we have it, otherwise stitch the new one
    final finalPhoneNumber = _isPhoneVerified 
        ? _verifiedPhoneNumber 
        : '$_selectedCountryCode ${_phoneController.text.trim()}';

    if (name.isEmpty || finalPhoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill in all fields!'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final user = AuthService().currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': name,
          'phone': finalPhoneNumber, // Save the final locked number
          'email': user.email ?? '',
          'photoUrl': user.photoURL ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'profileComplete': true, 
        }, SetOptions(merge: true));

        if (!mounted) return;
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      debugPrint("Error saving profile: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppProvider>().isDark;
    final bg = isDark ? AppColors.darkBg : AppColors.cream;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1C);
    final inputBg = isDark ? AppColors.darkSurface : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Almost there! 🎉',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 32, fontWeight: FontWeight.w900, color: textColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Let\'s complete your profile so your friends can easily find you.',
                style: TextStyle(fontSize: 16, color: isDark ? AppColors.darkMuted : AppColors.muted),
              ),
              const SizedBox(height: 48),

              // Name Input
              Text('YOUR FULL NAME', style: TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.orange)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  filled: true, fillColor: inputBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.person_outline, color: AppColors.orange),
                ),
              ),
              const SizedBox(height: 24),

              // DYNAMIC Phone Input Area
              Text('PHONE NUMBER', style: TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.orange)),
              const SizedBox(height: 8),
              
              if (_isPhoneVerified) ...[
                // THE LOCKED VERIFIED STATE
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface2 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user, color: Colors.green),
                      const SizedBox(width: 12),
                      Text(
                        _verifiedPhoneNumber,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1),
                      ),
                      const Spacer(),
                      const Text(
                        'Verified',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // THE EDITABLE GOOGLE LOGIN STATE
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: '98765 43210', 
                    hintStyle: TextStyle(
                      color: (isDark ? AppColors.darkMuted : AppColors.muted).withOpacity(0.4), 
                      fontWeight: FontWeight.w500
                    ),
                    filled: true, fillColor: inputBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 16.0, right: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone_outlined, color: AppColors.orange, size: 20),
                          const SizedBox(width: 8),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCountryCode,
                              icon: const Icon(Icons.arrow_drop_down, color: AppColors.orange),
                              dropdownColor: inputBg,
                              style: TextStyle(color: textColor, fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 15),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() => _selectedCountryCode = newValue);
                                }
                              },
                              items: AppConstants.countryCodes.map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(value: value, child: Text(value));
                              }).toList(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(width: 1.5, height: 24, color: (isDark ? AppColors.darkBorder : AppColors.border).withOpacity(0.5)),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 48),

              // Save Button
              _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
                  : GestureDetector(
                      onTap: _saveProfile,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(16)),
                        child: const Center(
                          child: Text('Complete Setup →', style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}