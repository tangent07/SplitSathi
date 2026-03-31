import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. Create a brand new group (NOW WITH EMOJIS AND MEMBERS!)
  Future<void> createGroup(String groupName, String emoji, List<String> members) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return; 

    try {
      await _db.collection('groups').add({
        'name': groupName,
        'emoji': emoji,           // <--- Now saves the emoji!
        'members': members,       // <--- Now saves the full member list!
        'createdBy': currentUser.uid, 
        'createdAt': FieldValue.serverTimestamp(), 
      });
      debugPrint("Success: Group created in Firestore!");
    } catch (e) {
      debugPrint("Error creating group: $e");
    }
  }
}