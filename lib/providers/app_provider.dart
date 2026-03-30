import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add Firestore import
import '../models/group.dart';
import '../models/diary_entry.dart';
import '../models/direct_payment.dart';

class AppProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _isDark = false;
  List<Group> _groups = [];
  List<DiaryCategory> _diaryCats = [];
  List<DiaryEntry> _diaryEntries = [];
  List<DirectPayment> _directPayments = [];

  // Stream Subscriptions to keep data synced in real-time
  StreamSubscription? _groupSub;
  StreamSubscription? _diaryCatSub;
  StreamSubscription? _diaryEntrySub;
  StreamSubscription? _paymentSub;

  AppProvider(this._prefs) {
    _isDark = _prefs.getBool('isDark') ?? false;
    _listenToGroups();
    _listenToDiary();
    _listenToDirectPayments();
  }

  @override
  void dispose() {
    // Clean up streams when app closes
    _groupSub?.cancel();
    _diaryCatSub?.cancel();
    _diaryEntrySub?.cancel();
    _paymentSub?.cancel();
    super.dispose();
  }

  // GETTERS
  bool get isDark => _isDark;
  List<Group> get groups => _groups;
  List<DiaryCategory> get diaryCats => _diaryCats;
  List<DiaryEntry> get diaryEntries => _diaryEntries;
  List<DirectPayment> get directPayments => _directPayments;

  // DARK MODE (Stays local)
  void toggleDarkMode() {
    _isDark = !_isDark;
    _prefs.setBool('isDark', _isDark);
    notifyListeners();
  }

  // ================= GROUPS =================
  void _listenToGroups() {
    _groupSub = _db.collection('groups').snapshots().listen((snapshot) {
      _groups = snapshot.docs.map((doc) => Group.fromJson(doc.data())).toList();
      notifyListeners();
    });
  }

  void addGroup(Group group) {
    _db.collection('groups').doc(group.id).set(group.toJson());
  }

  void updateGroup(Group group) {
    _db.collection('groups').doc(group.id).update(group.toJson());
  }

  void deleteGroup(String groupId) {
    _db.collection('groups').doc(groupId).delete();
  }

  void addExpense(String groupId, Expense expense) {
    final g = _groups.firstWhere((g) => g.id == groupId);
    g.expenses.add(expense);
    // Update the whole expenses array in Firestore
    _db.collection('groups').doc(groupId).update({
      'expenses': g.expenses.map((e) => e.toJson()).toList()
    });
  }

  void updateExpense(String groupId, Expense expense) {
    final g = _groups.firstWhere((g) => g.id == groupId);
    final idx = g.expenses.indexWhere((e) => e.id == expense.id);
    if (idx != -1) {
      g.expenses[idx] = expense;
      _db.collection('groups').doc(groupId).update({
        'expenses': g.expenses.map((e) => e.toJson()).toList()
      });
    }
  }

  void deleteExpense(String groupId, String expenseId) {
    final g = _groups.firstWhere((g) => g.id == groupId);
    final idx = g.expenses.indexWhere((e) => e.id == expenseId);
    if (idx != -1) {
      g.expenses[idx] = g.expenses[idx].copyWith(
        deleted: true,
        deletedAt: DateTime.now(),
      );
      _db.collection('groups').doc(groupId).update({
        'expenses': g.expenses.map((e) => e.toJson()).toList()
      });
    }
  }

  // ================= DIARY =================
  void _listenToDiary() {
    // Listen to Categories
    _diaryCatSub = _db.collection('diaryCats').snapshots().listen((snapshot) {
      _diaryCats = snapshot.docs.map((doc) => DiaryCategory.fromJson(doc.data())).toList();
      if (_diaryCats.isEmpty) _initDefaultCats();
      notifyListeners();
    });

    // Listen to Entries
    _diaryEntrySub = _db.collection('diaryEntries').snapshots().listen((snapshot) {
      _diaryEntries = snapshot.docs.map((doc) => DiaryEntry.fromJson(doc.data())).toList();
      notifyListeners();
    });
  }

  void _initDefaultCats() {
    final defaultCats = [
      DiaryCategory(id: 'c1', name: 'Living', icon: '🏠'),
      DiaryCategory(id: 'c2', name: 'Food', icon: '🍽️'),
      DiaryCategory(id: 'c3', name: 'Transport', icon: '🚗'),
      DiaryCategory(id: 'c4', name: 'Lifestyle', icon: '🎬'),
      DiaryCategory(id: 'c5', name: 'Finance', icon: '💰'),
    ];
    for (var cat in defaultCats) {
      addDiaryCategory(cat);
    }
  }

  void addDiaryCategory(DiaryCategory cat) {
    _db.collection('diaryCats').doc(cat.id).set(cat.toJson());
  }

  void updateDiaryCategory(DiaryCategory cat) {
    _db.collection('diaryCats').doc(cat.id).update(cat.toJson());
  }

  void deleteDiaryCategory(String catId) {
    _db.collection('diaryCats').doc(catId).delete();
    // Also delete associated entries from Firestore
    final entriesToDelete = _diaryEntries.where((e) => e.catId == catId);
    for (var entry in entriesToDelete) {
      deleteDiaryEntry(entry.id);
    }
  }

  void addDiaryEntry(DiaryEntry entry) {
    _db.collection('diaryEntries').doc(entry.id).set(entry.toJson());
  }

  void deleteDiaryEntry(String entryId) {
    _db.collection('diaryEntries').doc(entryId).delete();
  }

  // ================= DIRECT PAYMENTS =================
  void _listenToDirectPayments() {
    _paymentSub = _db.collection('directPayments').snapshots().listen((snapshot) {
      _directPayments = snapshot.docs.map((doc) => DirectPayment.fromJson(doc.data())).toList();
      notifyListeners();
    });
  }

  void addDirectPayment(DirectPayment payment) {
    _db.collection('directPayments').doc(payment.id).set(payment.toJson());
  }
}