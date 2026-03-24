import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/group.dart';
import '../models/diary_entry.dart';
import '../models/direct_payment.dart';

class AppProvider extends ChangeNotifier {
  final SharedPreferences _prefs;

  bool _isDark = false;
  List<Group> _groups = [];
  List<DiaryCategory> _diaryCats = [];
  List<DiaryEntry> _diaryEntries = [];
  List<DirectPayment> _directPayments = [];

  AppProvider(this._prefs) {
    _isDark = _prefs.getBool('isDark') ?? false;
    _loadGroups();
    _loadDiary();
    _loadDirectPayments();
    _initDefaultCats();
  }

  // GETTERS
  bool get isDark => _isDark;
  List<Group> get groups => _groups;
  List<DiaryCategory> get diaryCats => _diaryCats;
  List<DiaryEntry> get diaryEntries => _diaryEntries;
  List<DirectPayment> get directPayments => _directPayments;

  // DARK MODE
  void toggleDarkMode() {
    _isDark = !_isDark;
    _prefs.setBool('isDark', _isDark);
    notifyListeners();
  }

  // GROUPS
  void _loadGroups() {
    final data = _prefs.getString('groups');
    if (data != null) {
      final list = jsonDecode(data) as List;
      _groups = list.map((e) => Group.fromJson(e)).toList();
    }
    notifyListeners();
  }

  void _saveGroups() {
    _prefs.setString('groups', jsonEncode(_groups.map((g) => g.toJson()).toList()));
  }

  void addGroup(Group group) {
    _groups.insert(0, group);
    _saveGroups();
    notifyListeners();
  }

  void updateGroup(Group group) {
    final idx = _groups.indexWhere((g) => g.id == group.id);
    if (idx != -1) {
      _groups[idx] = group;
      _saveGroups();
      notifyListeners();
    }
  }

  void deleteGroup(String groupId) {
    _groups.removeWhere((g) => g.id == groupId);
    _saveGroups();
    notifyListeners();
  }

  void addExpense(String groupId, Expense expense) {
    final g = _groups.firstWhere((g) => g.id == groupId);
    g.expenses.add(expense);
    _saveGroups();
    notifyListeners();
  }

  void updateExpense(String groupId, Expense expense) {
    final g = _groups.firstWhere((g) => g.id == groupId);
    final idx = g.expenses.indexWhere((e) => e.id == expense.id);
    if (idx != -1) {
      g.expenses[idx] = expense;
      _saveGroups();
      notifyListeners();
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
      _saveGroups();
      notifyListeners();
    }
  }

  // DIARY
  void _initDefaultCats() {
    if (_diaryCats.isEmpty) {
      _diaryCats = [
        DiaryCategory(id: 'c1', name: 'Living', icon: '🏠'),
        DiaryCategory(id: 'c2', name: 'Food', icon: '🍽️'),
        DiaryCategory(id: 'c3', name: 'Transport', icon: '🚗'),
        DiaryCategory(id: 'c4', name: 'Lifestyle', icon: '🎬'),
        DiaryCategory(id: 'c5', name: 'Finance', icon: '💰'),
      ];
      _saveDiary();
    }
  }

  void _loadDiary() {
    final catsData = _prefs.getString('diaryCats');
    if (catsData != null) {
      final list = jsonDecode(catsData) as List;
      _diaryCats = list.map((e) => DiaryCategory.fromJson(e)).toList();
    }
    final entriesData = _prefs.getString('diaryEntries');
    if (entriesData != null) {
      final list = jsonDecode(entriesData) as List;
      _diaryEntries = list.map((e) => DiaryEntry.fromJson(e)).toList();
    }
    notifyListeners();
  }

  void _saveDiary() {
    _prefs.setString('diaryCats', jsonEncode(_diaryCats.map((c) => c.toJson()).toList()));
    _prefs.setString('diaryEntries', jsonEncode(_diaryEntries.map((e) => e.toJson()).toList()));
  }

  void addDiaryCategory(DiaryCategory cat) {
    _diaryCats.add(cat);
    _saveDiary();
    notifyListeners();
  }

  void updateDiaryCategory(DiaryCategory cat) {
    final idx = _diaryCats.indexWhere((c) => c.id == cat.id);
    if (idx != -1) {
      _diaryCats[idx] = cat;
      _saveDiary();
      notifyListeners();
    }
  }

  void deleteDiaryCategory(String catId) {
    _diaryCats.removeWhere((c) => c.id == catId);
    _diaryEntries.removeWhere((e) => e.catId == catId);
    _saveDiary();
    notifyListeners();
  }

  void addDiaryEntry(DiaryEntry entry) {
    _diaryEntries.add(entry);
    _saveDiary();
    notifyListeners();
  }

  void deleteDiaryEntry(String entryId) {
    _diaryEntries.removeWhere((e) => e.id == entryId);
    _saveDiary();
    notifyListeners();
  }

  // DIRECT PAYMENTS
  void _loadDirectPayments() {
    final data = _prefs.getString('directPayments');
    if (data != null) {
      final list = jsonDecode(data) as List;
      _directPayments = list.map((e) => DirectPayment.fromJson(e)).toList();
    }
    notifyListeners();
  }

  void _saveDirectPayments() {
    _prefs.setString('directPayments', jsonEncode(_directPayments.map((p) => p.toJson()).toList()));
  }

  void addDirectPayment(DirectPayment payment) {
    _directPayments.add(payment);
    _saveDirectPayments();
    notifyListeners();
  }
}