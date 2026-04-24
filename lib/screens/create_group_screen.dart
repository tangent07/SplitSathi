import 'add_friend_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

class CreateGroupSheet extends StatefulWidget {
  const CreateGroupSheet({super.key});

  @override
  State<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<CreateGroupSheet> {
  final _nameController = TextEditingController();
  String _selectedEmoji = '🍕';
  
  final Set<Map<String, dynamic>> _selectedFriends = {}; 
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _toggleFriend(Map<String, dynamic> friendData) {
    setState(() {
      if (_selectedFriends.any((f) => f['uid'] == friendData['uid'])) {
        _selectedFriends.removeWhere((f) => f['uid'] == friendData['uid']);
      } else {
        _selectedFriends.add(friendData);
      }
    });
  }

  Future<void> _createGroup() async {
    final groupName = _nameController.text.trim();
    if (groupName.isEmpty) {
      _showToast('Please enter a group name!');
      return;
    }

    // --- OPTION 2 BYPASS: Removed the requirement to have at least 1 friend selected ---
    // Now you can create a "Solo Group" to test the UI!

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final myUid = AuthService().currentUser!.uid;
      
      // We always add "You" to the list of member names
      List<String> membersList = ['You'];

      // We always add your UID to the list of member UIDs for security rules
      List<String> memberUids = [myUid]; 

      for (var friend in _selectedFriends) {
        membersList.add(friend['name']);
        memberUids.add(friend['uid']); // Add friend UIDs so they can access the group too
      }

      await FirebaseFirestore.instance.collection('groups').add({
        'name': groupName,
        'icon': _selectedEmoji,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': myUid,
        'members': memberUids, // <-- CRUCIAL: Pass the UIDs here for the security rules!
        'memberNames': membersList, // Keep names separate for easy display
        'totalExpenses': 0.0,
      });

      if (mounted) {
        Navigator.pop(context);
        // Note: SnackBar here will show on the Home Screen after the sheet closes, which is fine!
      }
    } catch (e) {
      _showToast('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showToast(String msg) {
    if (!mounted) return;
    // FIX 3: To make the SnackBar show over the BottomSheet, we need to ensure 
    // it attaches to the root navigator if possible, or just let it show on the Scaffold below.
    // Since we are popping the sheet on success anyway, showing it on the main Scaffold is okay for errors.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppProvider>().isDark;
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1C);
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    final inputBg = isDark ? AppColors.darkSurface2 : const Color(0xFFFFF7ED);
    
    final myUid = AuthService().currentUser?.uid ?? '';

    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(
        left: 20, 
        right: 20, 
        top: 16, 
        // FIX 1: Padding at the bottom adjusts when the keyboard opens
        bottom: MediaQuery.of(context).viewInsets.bottom + 24 
      ),
      // Removed fixed height! It will now take up the space it needs up to a maximum.
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Wrap content vertically
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text('Create Group', style: TextStyle(fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.w900, color: textColor)),
          const SizedBox(height: 20),

          // FIX 2: Wrapped the scrollable content to prevent overflow and hiding elements
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('GROUP NAME'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    style: TextStyle(color: textColor, fontFamily: 'Inter', fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: 'e.g. Goa Trip, Office Lunch...',
                      hintStyle: TextStyle(color: (isDark ? AppColors.darkMuted : AppColors.muted).withOpacity(0.5)),
                      filled: true, fillColor: inputBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.orange, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _label('PICK AN EMOJI'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: AppConstants.groupEmojis.map((emoji) {
                      final isSelected = emoji == _selectedEmoji;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedEmoji = emoji);
                        },
                        child: Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.orange.withOpacity(0.15) : inputBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSelected ? AppColors.orange : borderColor, width: isSelected ? 2 : 1.5),
                          ),
                          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  _label('GROUP MEMBERS'),
                  const SizedBox(height: 12),

                  GestureDetector(
                    onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const AddFriendSheet()),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: inputBg, 
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.orange.withOpacity(0.5), width: 1.5),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.person_add_alt_1, color: AppColors.orange, size: 20),
                          SizedBox(width: 12),
                          Text('Search or add a new friend...', style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.orange)),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),

                  // To display the list inside SingleChildScrollView, we use shrinkWrap
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(myUid).collection('connections').orderBy('name').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(color: AppColors.orange)));
                      
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const SizedBox.shrink(); // Completely removes the text and spacing
                      }
                      final friends = snapshot.data!.docs;

                      return ListView.builder(
                        shrinkWrap: true, // Needed inside SingleChildScrollView
                        physics: const NeverScrollableScrollPhysics(), // Let outer scroll handle it
                        itemCount: friends.length,
                        itemBuilder: (context, index) {
                          final friendData = friends[index].data() as Map<String, dynamic>;
                          final isSelected = _selectedFriends.any((f) => f['uid'] == friendData['uid']);

                          return GestureDetector(
                            onTap: () => _toggleFriend(friendData),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.orange.withOpacity(0.1) : Colors.transparent,
                                border: Border.all(color: isSelected ? AppColors.orange : borderColor, width: 1.5),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40, height: 40,
                                    decoration: BoxDecoration(color: isSelected ? AppColors.orange : (isDark ? AppColors.darkSurface2 : Colors.grey[200]), borderRadius: BorderRadius.circular(12)),
                                    child: Center(
                                      child: Text(
                                        (friendData['name'] != null && friendData['name'].toString().trim().isNotEmpty) ? friendData['name'].toString().trim()[0].toUpperCase() : '?', 
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isSelected ? Colors.white : textColor)
                                      )
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(friendData['name'] ?? 'Unknown', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w800, color: textColor)),
                                        Text(friendData['email'] ?? friendData['phone'] ?? '', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkMuted : AppColors.muted)),
                                      ],
                                    ),
                                  ),
                                  if (isSelected) const Icon(Icons.check_circle, color: AppColors.orange),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),

          GestureDetector(
            onTap: _isLoading ? null : _createGroup,
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(color: _isLoading ? Colors.grey : AppColors.orange, borderRadius: BorderRadius.circular(14)),
              child: Center(child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Create Group ➔', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white))
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(text, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.orange, letterSpacing: 0.5));
  }
}