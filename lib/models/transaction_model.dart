import 'dart:convert';
import 'package:intl/intl.dart'; // ✅ For date formatting

enum TransactionType { credit, debit }

class TransactionModel {
  final String? id;
  final String userId;
  final String senderAddress;
  final String messageBody;
  final DateTime transactionDate;
  final double amount;
  final TransactionType type;
  final String? category; // --- ADDED THIS LINE ---

  TransactionModel({
    this.id,
    required this.userId,
    required this.senderAddress,
    required this.messageBody,
    required this.transactionDate,
    required this.amount,
    required this.type,
    this.category, // --- ADDED THIS LINE ---
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'sender_address': senderAddress,
      'message_body': messageBody,

      // ✅ Store only the local DATE (no time)
      'transaction_date':
      DateFormat("yyyy-MM-dd").format(transactionDate.toLocal()),

      'amount': amount,
      'type': type == TransactionType.credit ? 'credit' : 'debit',
      'category': category,
    };
  }

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id']?.toString(),
      userId: json['user_id'],
      senderAddress: json['sender_address'],
      messageBody: json['message_body'],

      // ✅ Parse only the date part as local time
      transactionDate: DateTime.parse(json['transaction_date']).toLocal(),

      amount: (json['amount'] as num).toDouble(),
      type: json['type'] == 'credit'
          ? TransactionType.credit
          : TransactionType.debit,
      category: json['category'],
    );
  }
}
