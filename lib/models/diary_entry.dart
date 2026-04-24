import 'package:uuid/uuid.dart';

class DiaryCategory {
  final String id;
  final String userId; // <-- NEW: Security Name Tag
  String name;
  String icon;

  DiaryCategory({
    required this.id,
    required this.userId,
    required this.name,
    required this.icon,
  });

  factory DiaryCategory.create({
    required String userId,
    required String name,
    required String icon,
  }) {
    return DiaryCategory(
      id: const Uuid().v4(),
      userId: userId,
      name: name,
      icon: icon,
    );
  }

  factory DiaryCategory.fromJson(Map<String, dynamic> json) {
    return DiaryCategory(
      id: json['id'],
      userId: json['userId'] ?? '', // Fallback for old data
      name: json['name'],
      icon: json['icon'] ?? '📦',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'name': name,
    'icon': icon,
  };
}

class DiaryEntry {
  final String id;
  final String userId; // <-- NEW: Security Name Tag
  final String catId;
  final String note;
  final double amount;
  final DateTime date;
  final bool deleted;

  DiaryEntry({
    required this.id,
    required this.userId,
    required this.catId,
    required this.amount,
    required this.note,
    required this.date,
    this.deleted = false,
  });

  factory DiaryEntry.create({
    required String userId,
    required String catId,
    required double amount,
    required String note,
  }) {
    return DiaryEntry(
      id: const Uuid().v4(),
      userId: userId,
      catId: catId,
      amount: amount,
      note: note,
      date: DateTime.now(),
    );
  }

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      id: json['id'],
      userId: json['userId'] ?? '', // Fallback for old data
      catId: json['catId'],
      amount: (json['amount'] as num).toDouble(),
      note: json['note'] ?? '',
      date: DateTime.parse(json['date']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'catId': catId,
    'amount': amount,
    'note': note,
    'date': date.toIso8601String(),
  };

  // Helper getters
  String get dateStr =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String get monthStr =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';
}