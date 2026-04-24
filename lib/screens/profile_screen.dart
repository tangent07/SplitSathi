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
  bool _nameInitialized = false;
  String _savedName = '';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

            final userData =
                snapshot.data?.data() as Map<String, dynamic>? ?? {};

            // Initialise the name field once from Firestore.
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
                                onPressed: _isSavingName
                                    ? null
                                    : _cancelEditName,
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey.shade600,
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 44,
                                child: ElevatedButton(
                                  onPressed: _isSavingName
                                      ? null
                                      : _saveProfileName,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.orange,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                  ),
                                  child: _isSavingName
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2),
                                        )
                                      : const Text(
                                          'Save',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                        ),
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
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
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
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
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
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'My Profile',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),
        ),
        Positioned(
          bottom: -50,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBg : AppColors.cream,
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white,
              backgroundImage: (photoUrl != null &&
                      photoUrl.toString().isNotEmpty)
                  ? NetworkImage(photoUrl)
                  : NetworkImage(
                          'https://ui-avatars.com/api/?name=${Uri.encodeComponent(nameStr)}&background=F97316&color=fff&bold=true&size=200')
                      as ImageProvider,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildNameField(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: TextField(
        controller: _nameController,
        readOnly: !_isEditingName,
        textCapitalization: TextCapitalization.words,
        autofocus: _isEditingName,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDark
              ? (_isEditingName ? Colors.white : Colors.white70)
              : (_isEditingName ? Colors.black87 : Colors.black54),
        ),
        decoration: InputDecoration(
          icon:
              const Icon(Icons.person_outline, color: AppColors.orange, size: 22),
          border: InputBorder.none,
          hintText: 'Your full name',
          suffixIcon: _isEditingName
              ? null
              : IconButton(
                  icon: const Icon(Icons.edit,
                      color: AppColors.orange, size: 20),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          // Leading icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.orange.withOpacity(isFilled ? 0.1 : 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.orange, size: 20),
          ),
          const SizedBox(width: 14),
          // Middle: label + value (if filled) OR just label (if empty)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                    letterSpacing: 1.2,
                  ),
                ),
                if (isFilled) ...[
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Trailing: lock icon if filled, Add button if empty
          if (isFilled)
            Icon(Icons.lock_rounded,
                size: 18, color: Colors.grey.shade400)
          else
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: isLoading ? null : onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        emptyCta,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}