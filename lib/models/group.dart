import 'package:uuid/uuid.dart';

class Group {
  final String id;
  String name;
  String emoji;
  List<String> members;
  List<Expense> expenses;
  DateTime createdAt;

  Group({
    required this.id,
    required this.name,
    required this.emoji,
    required this.members,
    required this.expenses,
    required this.createdAt,
  });

  factory Group.create({
    required String name,
    required String emoji,
    required List<String> members,
  }) {
    return Group(
      id: const Uuid().v4(),
      name: name,
      emoji: emoji,
      members: members,
      expenses: [],
      createdAt: DateTime.now(),
    );
  }

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'],
      name: json['name'],
      emoji: json['emoji'] ?? '🍕',
      members: List<String>.from(json['members']),
      expenses: (json['expenses'] as List? ?? [])
          .map((e) => Expense.fromJson(e))
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'members': members,
    'expenses': expenses.map((e) => e.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  // Get last activity date
  DateTime get lastActivity {
    if (expenses.isEmpty) return createdAt;
    return expenses
        .map((e) => e.date)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  // Active expenses only
  List<Expense> get activeExpenses =>
      expenses.where((e) => !e.deleted).toList();
}

class Expense {
  final String id;
  String name;
  double amount;
  String paidBy;
  List<String> splitAmong;
  String category;
  DateTime date;
  bool deleted;
  DateTime? deletedAt;
  bool isSettlement;
  bool isGhost;
  String? ghostText;

  Expense({
    required this.id,
    required this.name,
    required this.amount,
    required this.paidBy,
    required this.splitAmong,
    required this.category,
    required this.date,
    this.deleted = false,
    this.deletedAt,
    this.isSettlement = false,
    this.isGhost = false,
    this.ghostText,
  });

  factory Expense.create({
    required String name,
    required double amount,
    required String paidBy,
    required List<String> splitAmong,
    required String category,
  }) {
    return Expense(
      id: const Uuid().v4(),
      name: name,
      amount: amount,
      paidBy: paidBy,
      splitAmong: splitAmong,
      category: category,
      date: DateTime.now(),
    );
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'],
      name: json['name'],
      amount: (json['amount'] as num).toDouble(),
      paidBy: json['paidBy'],
      splitAmong: List<String>.from(json['splitAmong']),
      category: json['category'] ?? '💸',
      date: DateTime.parse(json['date']),
      deleted: json['deleted'] ?? false,
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'])
          : null,
      isSettlement: json['isSettlement'] ?? false,
      isGhost: json['isGhost'] ?? false,
      ghostText: json['ghostText'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amount': amount,
    'paidBy': paidBy,
    'splitAmong': splitAmong,
    'category': category,
    'date': date.toIso8601String(),
    'deleted': deleted,
    'deletedAt': deletedAt?.toIso8601String(),
    'isSettlement': isSettlement,
    'isGhost': isGhost,
    'ghostText': ghostText,
  };

  Expense copyWith({
    String? name,
    double? amount,
    String? paidBy,
    List<String>? splitAmong,
    String? category,
    bool? deleted,
    DateTime? deletedAt,
    bool? isSettlement,
    bool? isGhost,
    String? ghostText,
  }) {
    return Expense(
      id: id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      paidBy: paidBy ?? this.paidBy,
      splitAmong: splitAmong ?? this.splitAmong,
      category: category ?? this.category,
      date: date,
      deleted: deleted ?? this.deleted,
      deletedAt: deletedAt ?? this.deletedAt,
      isSettlement: isSettlement ?? this.isSettlement,
      isGhost: isGhost ?? this.isGhost,
      ghostText: ghostText ?? this.ghostText,
    );
  }
}