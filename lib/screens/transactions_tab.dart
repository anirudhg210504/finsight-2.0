import 'package:flutter/material.dart';
import 'package:finsight/models/transaction_model.dart';
import 'package:finsight/screens/add_transaction_screen.dart';
import 'package:finsight/services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionsTab extends StatefulWidget {
  const TransactionsTab({super.key});

  @override
  State<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<TransactionsTab> {
  Future<List<TransactionModel>>? _transactionsFuture;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _transactionsFuture = _fetchTransactionsFromSupabase();
    });
  }

  Future<List<TransactionModel>> _fetchTransactionsFromSupabase() async {
    final user = _authService.currentUser;
    if (user == null) {
      return [];
    }

    final response = await Supabase.instance.client
        .from('transactions')
        .select()
        .eq('user_id', user.id)
        .order('transaction_date', ascending: false);

    final transactions = (response as List)
        .map((map) => TransactionModel.fromJson(map))
        .toList();

    return transactions;
  }

  // --- THIS FUNCTION IS NOW FIXED ---
  Future<void> _deleteFromSupabase(String transactionId) async {
    // 1. Get the current user
    final user = _authService.currentUser;
    if (user == null) {
      // If no user, don't even try.
      _loadTransactions(); // Refresh to be safe
      return;
    }

    try {
      await Supabase.instance.client
          .from('transactions')
          .delete()
          .eq('id', transactionId)       // Match the transaction ID
          .eq('user_id', user.id);  // --- AND match the current user's ID ---

      // No need to call _loadTransactions() on success,
      // as the item is already gone from the local list.

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting from server: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        // If server delete fails, refresh list to get back in sync
        _loadTransactions();
      }
    }
  }

  void _navigateAndRefresh() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AddTransactionScreen()),
    );
    _loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Transactions"),
        backgroundColor: const Color(0xFF006241),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: FutureBuilder<List<TransactionModel>>(
        future: _transactionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                "No transactions found.\nClick the '+' button to add one.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          final transactions = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _loadTransactions,
            child: ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final transaction = transactions[index];
                final isCredit = transaction.type == TransactionType.credit;

                return Dismissible(
                  key: ValueKey(transaction.id!),
                  direction: DismissDirection.endToStart,

                  onDismissed: (direction) {
                    final removedTransaction = transactions.removeAt(index);
                    setState(() {});

                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      SnackBar(
                        content: const Text('Transaction deleted'),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () {
                            setState(() {
                              transactions.insert(index, removedTransaction);
                            });
                          },
                        ),
                      ),
                    )
                        .closed
                        .then((reason) {
                      if (reason != SnackBarClosedReason.action) {
                        // This will now work correctly!
                        _deleteFromSupabase(removedTransaction.id!);
                      }
                    });
                  },

                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),

                  child: Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: ListTile(
                      leading: Icon(
                        isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isCredit ? Colors.green : Colors.red,
                      ),
                      title: Text(
                        transaction.senderAddress,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        transaction.messageBody,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        currencyFormatter.format(transaction.amount),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isCredit ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateAndRefresh,
        backgroundColor: const Color(0xFF006241),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}