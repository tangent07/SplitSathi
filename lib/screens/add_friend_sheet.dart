import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_contacts/flutter_contacts.dart'; // NEW
import 'package:url_launcher/url_launcher.dart'; // NEW

import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

class AddFriendSheet extends StatefulWidget {
  const AddFriendSheet({super.key});

  @override
  State<AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<AddFriendSheet> {
  final _searchController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _foundUser;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- 1. MANUAL SEARCH (Email or Phone) ---
  Future<void> _searchUser() async {
    final input = _searchController.text.trim();
    if (input.isEmpty) return;

    setState(() {
      _isLoading = true;
      _foundUser = null;
      _errorMessage = null;
    });

    try {
      final myUid = AuthService().currentUser?.uid;
      QuerySnapshot query;
      
      if (input.contains('@')) {
        query = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: input.toLowerCase()).limit(1).get();
      } else {
        query = await FirebaseFirestore.instance.collection('users').where('phone', isEqualTo: input).limit(1).get();
      }

      if (query.docs.isEmpty) {
        setState(() => _errorMessage = "No user found with this info.");
      } else {
        final userData = query.docs.first.data() as Map<String, dynamic>;
        userData['uid'] = query.docs.first.id;
        userData['isRegistered'] = true; // Flag for the UI button
        
        if (userData['uid'] == myUid) {
          setState(() => _errorMessage = "You can't add yourself!");
        } else {
          setState(() => _foundUser = userData);
        }
      }
    } catch (e) {
      setState(() => _errorMessage = "Error searching for user.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- 2. CONTACTS SEARCH (V2.0 Logic) ---
  Future<void> _openContactsAndSearch() async {
    final status = await FlutterContacts.permissions.request(PermissionType.readWrite);
    if (status != PermissionStatus.granted) {
      setState(() => _errorMessage = "Contact permission denied.");
      return;
    }

    final String? pickedId = await FlutterContacts.native.showPicker();
    if (pickedId == null) return; 

    final contact = await FlutterContacts.get(
      pickedId, 
      properties: {ContactProperty.name, ContactProperty.phone}
    );

    if (contact == null || contact.phones.isEmpty) {
      setState(() => _errorMessage = "This contact doesn't have a phone number saved.");
      return;
    }

    setState(() {
      _isLoading = true;
      _foundUser = null;
      _errorMessage = null;
    });

    try {
      String rawNumber = contact.phones.first.number;
      String cleanNumber = rawNumber.replaceAll(RegExp(r'\s+|-|\(|\)'), '');

      final query = await FirebaseFirestore.instance.collection('users').where('phone', isEqualTo: cleanNumber).limit(1).get();

      if (query.docs.isEmpty) {
        setState(() {
          _foundUser = {
            'name': contact.displayName,
            'phone': cleanNumber,
            'isRegistered': false, 
          };
        });
      } else {
        final userData = query.docs.first.data() as Map<String, dynamic>;
        userData['uid'] = query.docs.first.id;
        userData['isRegistered'] = true; 
        
        if (userData['uid'] == AuthService().currentUser?.uid) {
          setState(() => _errorMessage = "That's your own number!");
        } else {
          setState(() => _foundUser = userData);
        }
      }
    } catch (e) {
      setState(() => _errorMessage = "Error checking contact.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- 3. SEND SMS INVITE ---
  Future<void> _sendSmsInvite(String phoneNumber) async {
    final message = "Hey! I'm using SplitSathi to split our bills. Download it here: https://splitsathi.app";
    final uri = Uri.parse("sms:$phoneNumber?body=${Uri.encodeComponent(message)}");
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open SMS app.')));
    }
  }

  // --- 4. ADD TO NETWORK ---
  Future<void> _addFriend() async {
    if (_foundUser == null) return;
    
    final myUid = AuthService().currentUser?.uid;
    if (myUid == null) return;

    HapticFeedback.mediumImpact();
    
    await FirebaseFirestore.instance
        .collection('users')
        .doc(myUid)
        .collection('connections')
        .doc(_foundUser!['uid'])
        .set({
      'uid': _foundUser!['uid'],
      'name': _foundUser!['name'],
      'email': _foundUser!['email'] ?? '',
      'phone': _foundUser!['phone'] ?? '',
      'addedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${_foundUser!['name']} to your network! 🎉'), backgroundColor: AppColors.success));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppProvider>().isDark;
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1C);
    final inputBg = isDark ? AppColors.darkSurface2 : const Color(0xFFFFF7ED);
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Container(
      padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text('Add to Network', style: TextStyle(fontFamily: 'Nunito', fontSize: 22, fontWeight: FontWeight.w900, color: textColor)),
          const SizedBox(height: 8),
          Text('Search by exact Email or Phone Number.', style: TextStyle(fontSize: 15, color: isDark ? AppColors.darkMuted : AppColors.muted)),
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: textColor, fontFamily: 'Nunito', fontWeight: FontWeight.w700),
                  keyboardType: TextInputType.emailAddress, 
                  decoration: InputDecoration(
                    hintText: 'Email or Phone Number...',
                    hintStyle: TextStyle(color: isDark ? AppColors.darkMuted : AppColors.muted),
                    filled: true, fillColor: inputBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.orange, width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _searchUser,
                child: Container(
                  height: 50, width: 50,
                  decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(12)),
                  child: _isLoading 
                    ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                    : const Icon(Icons.search, color: Colors.white),
                ),
              )
            ],
          ),
          
          const SizedBox(height: 16),
          
          // --- THE "OR" DIVIDER ---
          Row(
            children: [
              Expanded(child: Divider(color: borderColor)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('OR', style: TextStyle(color: isDark ? AppColors.darkMuted : AppColors.muted, fontSize: 12, fontWeight: FontWeight.w800))),
              Expanded(child: Divider(color: borderColor)),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // --- THE CONTACTS BUTTON ---
          GestureDetector(
            onTap: _openContactsAndSearch,
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor, width: 1.5)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.perm_contact_calendar_rounded, color: AppColors.orange, size: 20),
                  const SizedBox(width: 8),
                  Text('Choose from Contacts', style: TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w800, color: textColor)),
                ],
              ),
            ),
          ),
          
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 13)),
          ],

          if (_foundUser != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border.all(color: AppColors.success.withOpacity(0.3), width: 1.5), borderRadius: BorderRadius.circular(16), color: AppColors.success.withOpacity(0.05)),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(14)),
                    child: Center(
                      child: Text(
                        // SAFE FALLBACK: If name is missing or empty, show a '?'
                        (_foundUser!['name'] != null && _foundUser!['name'].toString().trim().isNotEmpty) 
                            ? _foundUser!['name'].toString().trim()[0].toUpperCase() 
                            : '?', 
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)
                      )
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // SAFE FALLBACK: Show 'Unknown User' instead of crashing
                        Text(_foundUser!['name'] ?? 'Unknown User', style: TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
                        Text(_foundUser!['email'] ?? _foundUser!['phone'] ?? '', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkMuted : AppColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // --- SMART ACTION BUTTON ---
            if (_foundUser!['isRegistered'] == true) 
              GestureDetector(
                onTap: _addFriend,
                child: Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(14)),
                  child: const Center(child: Text('Add to Network', style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white))),
                ),
              )
            else
              GestureDetector(
                onTap: () => _sendSmsInvite(_foundUser!['phone']),
                child: Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(14)),
                  child: const Center(child: Text('Send SMS Invite ✉️', style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white))),
                ),
              ),
          ]
        ],
      ),
    );
  }
}