import 'package:uuid/uuid.dart';

class DiaryCategory {
  final String id;
  String name;
  String icon;

  DiaryCategory({
    required this.id,
    required this.name,
    required this.icon,
  });

  factory DiaryCategory.create({
    required String name,
    required String icon,
  }) {
    return DiaryCategory(
      id: const Uuid().v4(),
      name: name,
      icon: icon,
    );
  }

  factory DiaryCategory.fromJson(Map<String, dynamic> json) {
    return DiaryCategory(
      id: json['id'],
      name: json['name'],
      icon: json['icon'] ?? '📦',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
  };
}

class DiaryEntry {
  final String id;
  final String catId;
  double amount;
  String note;
  DateTime date;

  DiaryEntry({
    required this.id,
    required this.catId,
    required this.amount,
    required this.note,
    required this.date,
  });

  factory DiaryEntry.create({
    required String catId,
    required double amount,
    required String note,
  }) {
    return DiaryEntry(
      id: const Uuid().v4(),
      catId: catId,
      amount: amount,
      note: note,
      date: DateTime.now(),
    );
  }

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      id: json['id'],
      catId: json['catId'],
      amount: (json['amount'] as num).toDouble(),
      note: json['note'] ?? '',
      date: DateTime.parse(json['date']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
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