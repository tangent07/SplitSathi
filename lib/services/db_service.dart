import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. Create a brand new group
  Future<void> createGroup(String groupName, String emoji, List<String> members) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return; 
    try {
      await _db.collection('groups').add({
        'name': groupName,
        'emoji': emoji,
        'members': members,
        'createdBy': currentUser.uid, 
        'createdAt': FieldValue.serverTimestamp(), 
      });
    } catch (e) {
      debugPrint("Error creating group: $e");
    }
  }

  // 2. Save a new expense inside a specific group
  Future<void> addExpense(String groupId, String name, double amount, String paidBy, List<String> splitAmong, String category) async {
    try {
      await _db.collection('groups').doc(groupId).collection('expenses').add({
        'name': name,
        'amount': amount,
        'paidBy': paidBy,
        'splitAmong': splitAmong,
        'category': category,
        'date': FieldValue.serverTimestamp(),
        'deleted': false,
      });
    } catch (e) {
      debugPrint("Error saving expense: $e");
    }
  }

  // 3. Update an existing expense
  Future<void> updateExpense(String groupId, String expenseId, String name, double amount, String paidBy, List<String> splitAmong, String category) async {
    try {
      await _db.collection('groups').doc(groupId).collection('expenses').doc(expenseId).update({
        'name': name,
        'amount': amount,
        'paidBy': paidBy,
        'splitAmong': splitAmong,
        'category': category,
      });
    } catch (e) {
      debugPrint("Error updating expense: $e");
    }
  }

  // 4. Soft Delete an expense
  Future<void> deleteExpense(String groupId, String expenseId) async {
    try {
      await _db.collection('groups').doc(groupId).collection('expenses').doc(expenseId).update({
        'deleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error deleting expense: $e");
    }
  }

  // 5. Save a Settlement
  Future<void> addSettlement(String groupId, String name, double amount, String paidBy, String paidTo, String category, String ghostText) async {
    try {
      await _db.collection('groups').doc(groupId).collection('expenses').add({
        'name': name,
        'amount': amount,
        'paidBy': paidBy,
        'splitAmong': [paidTo],
        'category': category,
        'date': FieldValue.serverTimestamp(),
        'deleted': false,
        'isSettlement': true,
        'isGhost': true,
        'ghostText': ghostText,
      });
    } catch (e) {
      debugPrint("Error saving settlement: $e");
    }
  }

  // 6. Update an existing group
  Future<void> updateGroup(String groupId, String name, String emoji, List<String> members) async {
    try {
      await _db.collection('groups').doc(groupId).update({
        'name': name,
        'emoji': emoji,
        'members': members,
      });
    } catch (e) {
      debugPrint("Error updating group: $e");
    }
  }

  // 7. Delete a group forever
  Future<void> deleteGroup(String groupId) async {
    try {
      await _db.collection('groups').doc(groupId).delete();
    } catch (e) {
      debugPrint("Error deleting group: $e");
    }
  }

  // --- PRIVATE MONEY DIARY FUNCTIONS (INSIDE THE CLASS) ---

  // 8. Save a private entry linked only to the User's UID
  Future<void> addPrivateDiaryEntry(String uid, String name, double amount, String category, DateTime date) async {
    try {
      await _db.collection('users').doc(uid).collection('private_diary').add({
        'name': name,
        'amount': amount,
        'category': category,
        'date': date,
        'deleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error saving diary entry: $e");
    }
  }
  Future<void> deletePrivateDiaryEntry(String uid, String entryId) async {
    await _db.collection('users').doc(uid).collection('private_diary').doc(entryId).update({
      'deleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  // 9. Stream the private entries for the UI
  Stream<QuerySnapshot> getPrivateDiaryStream(String uid) {
    return _db.collection('users').doc(uid)
        .collection('private_diary')
        .orderBy('date', descending: true)
        .snapshots();
  }
  
  // --- PRIVATE CATEGORY MANAGEMENT ---

  // 1. Fetch categories
  Stream<QuerySnapshot> getPrivateCategoriesStream(String uid) {
    return _db.collection('users').doc(uid).collection('categories').snapshots();
  }

  // 2. Add/Update category
  Future<void> savePrivateCategory(String uid, String name, String icon, {String? docId}) async {
    final ref = _db.collection('users').doc(uid).collection('categories');
    if (docId != null) {
      await ref.doc(docId).update({'name': name, 'icon': icon});
    } else {
      await ref.add({'name': name, 'icon': icon, 'createdAt': FieldValue.serverTimestamp()});
    }
  }

  // 3. Delete category
  Future<void> deletePrivateCategory(String uid, String docId) async {
    await _db.collection('users').doc(uid).collection('categories').doc(docId).delete();
  }

  // --- BOOTSTRAP DEFAULT CATEGORIES ---
  Future<void> setupDefaultCategories(String uid) async {
    final ref = _db.collection('users').doc(uid).collection('categories');
    final snapshot = await ref.get();

    // Only add if the user has 0 categories
    if (snapshot.docs.isEmpty) {
      final batch = _db.batch();
      final defaults = [
        {'name': 'Living', 'icon': '🏠'},
        {'name': 'Food', 'icon': '🍽️'},
        {'name': 'Transport', 'icon': '🚗'},
        {'name': 'Lifestyle', 'icon': '🎬'},
        {'name': 'Finance', 'icon': '💰'},
      ];

      for (var cat in defaults) {
        batch.set(ref.doc(), {
          ...cat,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }  
}