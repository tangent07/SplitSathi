import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/group.dart';
import '../models/diary_entry.dart';
import '../models/direct_payment.dart';

/// App-wide state.
class AppProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---- App-level preferences ----
  bool _hapticsEnabled = true;
  bool _isDark = false;
  String _currency = '₹';

  // ---- Data (cleared on logout) ----
  List<Group> _groups = [];
  List<DiaryCategory> _diaryCats = [];
  List<DiaryEntry> _diaryEntries = [];
  List<DirectPayment> _directPayments = [];

  // ---- Stream subs ----
  StreamSubscription? _groupSub;
  StreamSubscription? _diaryCatSub;
  StreamSubscription? _diaryEntrySub;
  StreamSubscription? _paymentSub;

  // ---- Auth sub ----
  StreamSubscription<User?>? _authSub;
  String? _activeUid;

  AppProvider(this._prefs) {
    _isDark = _prefs.getBool('isDark') ?? false;
    _hapticsEnabled = _prefs.getBool('haptics') ?? true;
    _currency = _prefs.getString('currency') ?? '₹';
    _textSize = _prefs.getString('textSize') ?? 'M';

    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _cancelDataStreams();
    super.dispose();
  }

  // ================= GETTERS =================
  bool get hapticsEnabled => _hapticsEnabled;
  bool get isDark => _isDark;
  String get currency => _currency;

  List<Group> get groups => _groups;
  List<DiaryCategory> get diaryCats => _diaryCats;
  List<DiaryEntry> get diaryEntries => _diaryEntries;
  List<DirectPayment> get directPayments => _directPayments;

  // ================= AUTH LIFECYCLE =================
  void _onAuthChanged(User? user) {
    if (user == null) {
      _cancelDataStreams();
      _clearData();
      _activeUid = null;
      notifyListeners();
      return;
    }
    if (_activeUid == user.uid) return;

    _cancelDataStreams();
    _clearData();
    _activeUid = user.uid;
    _listenToGroups();
    _listenToDiary();
    _listenToDirectPayments();
    notifyListeners();
  }

  void _cancelDataStreams() {
    _groupSub?.cancel();
    _diaryCatSub?.cancel();
    _diaryEntrySub?.cancel();
    _paymentSub?.cancel();
    _groupSub = null;
    _diaryCatSub = null;
    _diaryEntrySub = null;
    _paymentSub = null;
  }

  void _clearData() {
    _groups = [];
    _diaryCats = [];
    _diaryEntries = [];
    _directPayments = [];
  }

  void clearAllData() {
    _cancelDataStreams();
    _clearData();
    _activeUid = null;
    notifyListeners();
  }

  // ================= PREFERENCES =================
  String _textSize = 'M'; // 'XS', 'S', 'M', 'L', 'XL'

  void toggleDarkMode() {
    _isDark = !_isDark;
    _prefs.setBool('isDark', _isDark);
    notifyListeners();
  }

  void setHaptics(bool value) {
    _hapticsEnabled = value;
    _prefs.setBool('haptics', value);
    notifyListeners();
  }

  void setCurrency(String newCurrency) {
    _currency = newCurrency;
    _prefs.setString('currency', _currency);
    notifyListeners();
  }

  // ================= GROUPS =================
  void _listenToGroups() {
    _groupSub = _db.collection('groups').snapshots().listen((snapshot) {
      _groups =
          snapshot.docs.map((doc) => Group.fromJson(doc.data())).toList();
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
    _diaryCatSub = _db.collection('diaryCats').snapshots().listen((snapshot) {
      _diaryCats = snapshot.docs
          .map((doc) => DiaryCategory.fromJson(doc.data()))
          .toList();
      if (_diaryCats.isEmpty) _initDefaultCats();
      notifyListeners();
    });

    _diaryEntrySub = _db.collection('diaryEntries').snapshots().listen((snapshot) {
      _diaryEntries = snapshot.docs
          .map((doc) => DiaryEntry.fromJson(doc.data()))
          .toList();
      notifyListeners();
    });
  }

  void _initDefaultCats() {
    if (_activeUid == null) return; // Safety check
    
    final defaultCats = [
      DiaryCategory(id: 'c1', userId: _activeUid!, name: 'Living', icon: '🏠'),
      DiaryCategory(id: 'c2', userId: _activeUid!, name: 'Food', icon: '🍽️'),
      DiaryCategory(id: 'c3', userId: _activeUid!, name: 'Transport', icon: '🚗'),
      DiaryCategory(id: 'c4', userId: _activeUid!, name: 'Lifestyle', icon: '🎬'),
      DiaryCategory(id: 'c5', userId: _activeUid!, name: 'Finance', icon: '💰'),
    ];
    for (final cat in defaultCats) {
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
    final entriesToDelete = _diaryEntries.where((e) => e.catId == catId);
    for (final entry in entriesToDelete) {
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
    _paymentSub =
        _db.collection('directPayments').snapshots().listen((snapshot) {
      _directPayments = snapshot.docs
          .map((doc) => DirectPayment.fromJson(doc.data()))
          .toList();
      notifyListeners();
    });
  }

  void addDirectPayment(DirectPayment payment) {
    _db.collection('directPayments').doc(payment.id).set(payment.toJson());
  }

  String get textSize => _textSize;
  
  double get textScale {
    switch (_textSize) {
      case 'XS': return 0.8;
      case 'S': return 0.9;
      case 'L': return 1.1;
      case 'XL': return 1.25;
      case 'M':
      default: return 1.0;
    }
  }

  void setTextSize(String size) {
    _textSize = size;
    _prefs.setString('textSize', size);
    notifyListeners();
  }
}