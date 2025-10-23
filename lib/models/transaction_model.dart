import 'dart:convert';

enum TransactionType { credit, debit }

class TransactionModel {
  final String? id; // --- ADDED THIS LINE ---
  final String userId;
  final String senderAddress;
  final String messageBody;
  final DateTime transactionDate;
  final double amount;
  final TransactionType type;

  TransactionModel({
    this.id, // --- ADDED THIS LINE ---
    required this.userId,
    required this.senderAddress,
    required this.messageBody,
    required this.transactionDate,
    required this.amount,
    required this.type,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'sender_address': senderAddress,
      'message_body': messageBody,
      'transaction_date': transactionDate.toIso8601String(),
      'amount': amount,
      'type': type == TransactionType.credit ? 'credit' : 'debit',
      // We don't include 'id' in toJson, as Supabase generates it on creation
    };
  }

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id']?.toString(), // --- ADDED THIS LINE ---
      userId: json['user_id'],
      senderAddress: json['sender_address'],
      messageBody: json['message_body'],
      transactionDate: DateTime.parse(json['transaction_date']),
      amount: (json['amount'] as num).toDouble(),
      type: json['type'] == 'credit'
          ? TransactionType.credit
          : TransactionType.debit,
    );
  }
}