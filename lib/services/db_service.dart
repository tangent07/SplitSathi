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

  // 2. Save a new expense inside a specific group
  Future<void> addExpense(String groupId, String name, double amount, String paidBy, List<String> splitAmong, String category) async {
    try {
      // Notice we go into groups -> specific group -> expenses collection
      await _db.collection('groups').doc(groupId).collection('expenses').add({
        'name': name,
        'amount': amount,
        'paidBy': paidBy,
        'splitAmong': splitAmong,
        'category': category,
        'date': FieldValue.serverTimestamp(), // Official Google server time
        'deleted': false, // For your awesome swipe-to-delete feature later!
      });
      debugPrint("Success: Expense saved to cloud!");
    } catch (e) {
      debugPrint("Error saving expense: $e");
    }
  }

  // 3. Update an existing expense
  Future<void> updateExpense(String groupId, String expenseId, String name, double amount, String paidBy, List<String> splitAmong, String category) async {
    try {
      // Notice we are targeting the specific expenseId document now!
      await _db.collection('groups').doc(groupId).collection('expenses').doc(expenseId).update({
        'name': name,
        'amount': amount,
        'paidBy': paidBy,
        'splitAmong': splitAmong,
        'category': category,
      });
      debugPrint("Success: Expense updated in cloud!");
    } catch (e) {
      debugPrint("Error updating expense: $e");
    }
  }

  // 4. Soft Delete an expense (Creates your awesome ghost record!)
  Future<void> deleteExpense(String groupId, String expenseId) async {
    try {
      await _db.collection('groups').doc(groupId).collection('expenses').doc(expenseId).update({
        'deleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      });
      debugPrint("Success: Expense ghosted in cloud!");
    } catch (e) {
      debugPrint("Error deleting expense: $e");
    }
  }

  // 5. Save a Settlement (Creates a Ghost Record)
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
      debugPrint("Success: Settlement saved to cloud!");
    } catch (e) {
      debugPrint("Error saving settlement: $e");
    }
  }
}