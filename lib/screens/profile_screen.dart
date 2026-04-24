import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../widgets/phone_link_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _user = AuthService().currentUser;

  bool _isSavingName = false;
  bool _isEditingName = false;
  bool _isLinkingGoogle = false;
  bool _isUploadingPic = false; // <-- NEW: Tracks image upload state
  bool _nameInitialized = false;
  String _savedName = '';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // -------- PROFILE PICTURE (NEW!) --------

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      // Compress the image so it uploads fast and saves database space
      final pickedFile = await picker.pickImage(source: source, maxWidth: 800, imageQuality: 80);
      if (pickedFile == null) return;

      setState(() => _isUploadingPic = true);
      
      final user = _user;
      if (user == null) return;

      // 1. Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child('user_profiles').child('${user.uid}.jpg');
      final File imageFile = File(pickedFile.path);
      
      await storageRef.putFile(imageFile);
      final downloadUrl = await storageRef.getDownloadURL();

      // 2. Update Auth and Firestore with the new URL
      await user.updatePhotoURL(downloadUrl);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'photoUrl': downloadUrl});

      _showSuccess('Profile picture updated! 📸');
    } catch (e) {
      _showError('Failed to upload picture. Please try again.');
    } finally {
      if (mounted) setState(() => _isUploadingPic = false);
    }
  }

  // 👇 NEW: Function to remove picture and revert to initials 👇
  Future<void> _removeProfilePicture() async {
    final user = _user;
    if (user == null) return;

    setState(() => _isUploadingPic = true);

    try {
      // 1. Delete from Firebase Storage (if it exists)
      try {
        final storageRef = FirebaseStorage.instance.ref().child('user_profiles').child('${user.uid}.jpg');
        await storageRef.delete();
      } catch (e) {
        debugPrint("Storage delete skipped or failed: $e");
      }

      // 2. Update Auth (Set to null)
      await user.updatePhotoURL(null);

      // 3. Update Firestore (Set to null)
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'photoUrl': null});

      _showSuccess('Profile picture removed! 🗑️');
    } catch (e) {
      _showError('Failed to remove picture. Please try again.');
    } finally {
      if (mounted) setState(() => _isUploadingPic = false);
    }
  }

  // 👇 UPDATED: Accepts photoUrl and shows the Delete button conditionally 👇
  void _showImagePickerOptions(dynamic photoUrl) {
    // Check if a photo is currently set
    final hasPhoto = (photoUrl != null && photoUrl.toString().isNotEmpty);

    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Update Profile Picture', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.orange.withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.orange),
                ),
                title: const Text('Take a Photo', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.orange.withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.orange),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(ImageSource.gallery);
                },
              ),
              
              // Only show remove option if they actually have a photo!
              if (hasPhoto) ...[
                const Divider(),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  ),
                  title: const Text('Remove Current Picture', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _removeProfilePicture(); // Call removal function
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // -------- NAME --------

  void _startEditName() {
    setState(() => _isEditingName = true);
  }

  void _cancelEditName() {
    FocusScope.of(context).unfocus();
    setState(() {
      _nameController.text = _savedName;
      _isEditingName = false;
    });
  }

  Future<void> _saveProfileName() async {
    final user = _user;
    if (user == null) return;

    final name = _nameController.text.trim();

    if (name.isEmpty) {
      _showError('Name cannot be empty');
      return;
    }
    if (name.length < 2) {
      _showError('Please enter a valid name');
      return;
    }

    setState(() => _isSavingName = true);
    HapticFeedback.mediumImpact();

    try {
      await user.updateDisplayName(name);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'name': name});

      if (mounted) {
        FocusScope.of(context).unfocus();
        setState(() {
          _savedName = name;
          _isEditingName = false;
        });
        _showSuccess('Name updated');
      }
    } catch (e) {
      if (mounted) _showError('Could not update name. Please try again.');
    } finally {
      if (mounted) setState(() => _isSavingName = false);
    }
  }

  // -------- LINK EMAIL (Google) --------

  Future<void> _linkEmail() async {
    if (_isLinkingGoogle) return;
    setState(() => _isLinkingGoogle = true);
    HapticFeedback.mediumImpact();

    final result = await AuthService().linkGoogleToCurrentUser();

    if (!mounted) return;
    setState(() => _isLinkingGoogle = false);

    if (result.isSuccess) {
      _showSuccess('Email linked successfully 🎉');
      return;
    }
    if (result.cancelled) return;
    _showError(result.errorMessage ?? 'Could not link email.');
  }

  // -------- LINK PHONE (OTP) --------

  Future<void> _linkPhone() async {
    final success = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PhoneLinkSheet(),
    );

    if (!mounted) return;
    if (success == true) {
      _showSuccess('Phone number linked successfully 🎉');
    }
  }

  // -------- UI FEEDBACK --------

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // -------- BUILD --------

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppProvider>().isDark;
    final user = _user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.orange)),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.cream,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: AppColors.orange));
            }

            final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};

            if (!_nameInitialized) {
              final nm = (userData['name'] ?? '') as String;
              _nameController.text = nm;
              _savedName = nm;
              _nameInitialized = true;
            }

            final photoUrl = userData['photoUrl'];
            final nameStr = userData['name'] ?? 'U';
            final email = (userData['email'] ?? '') as String;
            final phone = (userData['phone'] ?? '') as String;

            return SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(isDark, photoUrl, nameStr),
                  const SizedBox(height: 70),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel('FULL NAME', isDark),
                        _buildNameField(isDark),
                        if (_isEditingName) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: _isSavingName ? null : _cancelEditName,
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey.shade600,
                                ),
                                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 44,
                                child: ElevatedButton(
                                  onPressed: _isSavingName ? null : _saveProfileName,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.orange,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                  ),
                                  child: _isSavingName
                                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 32),
                        _buildSectionLabel('LINKED ACCOUNTS', isDark),
                        const SizedBox(height: 8),
                        _buildSlotCard(
                          isDark: isDark,
                          icon: Icons.email_rounded,
                          label: 'Email',
                          value: email,
                          emptyCta: 'Add Email',
                          onAdd: _linkEmail,
                          isLoading: _isLinkingGoogle,
                        ),
                        const SizedBox(height: 12),
                        _buildSlotCard(
                          isDark: isDark,
                          icon: Icons.phone_rounded,
                          label: 'Phone Number',
                          value: phone,
                          emptyCta: 'Add Phone Number',
                          onAdd: _linkPhone,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Linked accounts are permanent and cannot be changed. Add carefully.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // -------- UI HELPERS --------

  Widget _buildHeader(bool isDark, dynamic photoUrl, String nameStr) {
    return SizedBox(
      height: 250, // Total height (200 orange + 50 for the avatar overlap)
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // 1. The Orange Background
          Container(
            width: double.infinity,
            height: 200,
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.orange, Color(0xFFFB923C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'My Profile',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
          ),
          
          // 2. The Profile Picture Stack (Now fully inside clickable bounds!)
          Positioned(
            bottom: 0, // Sits exactly at the bottom of the 250px box
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: isDark ? AppColors.darkBg : AppColors.cream, shape: BoxShape.circle),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    backgroundImage: (photoUrl != null && photoUrl.toString().isNotEmpty)
                        ? NetworkImage(photoUrl)
                        : NetworkImage('https://ui-avatars.com/api/?name=${Uri.encodeComponent(nameStr)}&background=F97316&color=fff&bold=true&size=200') as ImageProvider,
                  ),
                  
                  if (_isUploadingPic)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
                        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                      ),
                    ),

                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _showImagePickerOptions(photoUrl),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.orange,
                          shape: BoxShape.circle,
                          border: Border.all(color: isDark ? AppColors.darkBg : AppColors.cream, width: 3),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildNameField(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: _nameController,
        readOnly: !_isEditingName,
        textCapitalization: TextCapitalization.words,
        autofocus: _isEditingName,
        textAlignVertical: TextAlignVertical.center, 
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDark ? (_isEditingName ? Colors.white : Colors.white70) : (_isEditingName ? Colors.black87 : Colors.black54),
        ),
        decoration: InputDecoration(
          isDense: true, 
          contentPadding: const EdgeInsets.symmetric(vertical: 14), 
          icon: const Icon(Icons.person_outline, color: AppColors.orange, size: 22),
          border: InputBorder.none,
          hintText: 'Your full name',
          suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          suffixIcon: _isEditingName
              ? null
              : IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.edit, color: AppColors.orange, size: 20),
                  onPressed: _startEditName,
                  tooltip: 'Edit name',
                ),
        ),
      ),
    );
  }

  Widget _buildSlotCard({
    required bool isDark,
    required IconData icon,
    required String label,
    required String value,
    required String emptyCta,
    required VoidCallback onAdd,
    bool isLoading = false,
  }) {
    final isFilled = value.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppColors.orange.withOpacity(isFilled ? 0.1 : 0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.orange, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.2)),
                if (isFilled) ...[
                  const SizedBox(height: 2),
                  Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (isFilled)
            Icon(Icons.lock_rounded, size: 18, color: Colors.grey.shade400)
          else
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: isLoading ? null : onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: isLoading
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(emptyCta, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}