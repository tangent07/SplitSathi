import 'package:uuid/uuid.dart';

class DirectPayment {
  final String id;
  final String friend;
  final double amount;
  final bool youPaid; // true = you paid them, false = they paid you
  final String note;
  final DateTime date;

  DirectPayment({
    required this.id,
    required this.friend,
    required this.amount,
    required this.youPaid,
    required this.note,
    required this.date,
  });

  factory DirectPayment.create({
    required String friend,
    required double amount,
    required bool youPaid,
    required String note,
  }) {
    return DirectPayment(
      id: const Uuid().v4(),
      friend: friend,
      amount: amount,
      youPaid: youPaid,
      note: note,
      date: DateTime.now(),
    );
  }

  factory DirectPayment.fromJson(Map<String, dynamic> json) {
    return DirectPayment(
      id: json['id'],
      friend: json['friend'],
      amount: (json['amount'] as num).toDouble(),
      youPaid: json['youPaid'] ?? true,
      note: json['note'] ?? '',
      date: DateTime.parse(json['date']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'friend': friend,
    'amount': amount,
    'youPaid': youPaid,
    'note': note,
    'date': date.toIso8601String(),
  };
}