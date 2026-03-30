import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. Create a brand new group
  Future<void> createGroup(String groupName) async {
    // Get the currently logged-in user
    final User? currentUser = _auth.currentUser;
    
    // Safety check: If they aren't logged in, stop right here.
    if (currentUser == null) return; 

    try {
      // Add a new document to the 'groups' collection
      await _db.collection('groups').add({
        'name': groupName,
        'createdBy': currentUser.uid, // We record who made it
        'members': [currentUser.uid], // The creator is automatically the first member!
        'createdAt': FieldValue.serverTimestamp(), // Official Google server time
      });
      print("Success: Group created in Firestore!");
    } catch (e) {
      print("Error creating group: $e");
    }
  }
}