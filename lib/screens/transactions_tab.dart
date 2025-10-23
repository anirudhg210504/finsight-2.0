import 'package:flutter/material.dart';
import 'package:finsight/models/transaction_model.dart';
import 'package:finsight/screens/add_transaction_screen.dart'; // Keep this import
import 'package:finsight/services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Ensure this is the class name!
class TransactionsTab extends StatefulWidget {
  const TransactionsTab({super.key});

  @override
  State<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<TransactionsTab> {
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;
  bool _isSelectionMode = false;
  final Set<String> _selectedTransactionIds = {};
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    if (!_isLoading) {
      setState(() => _isLoading = true);
    }

    try {
      final user = _authService.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _transactions = [];
            _isLoading = false;
          });
        }
        return;
      }

      final response = await Supabase.instance.client
          .from('transactions')
          .select()
          .eq('user_id', user.id)
          .order('transaction_date', ascending: false);

      final transactions = (response as List)
          .map((map) => TransactionModel.fromJson(map))
          .toList();

      if(mounted) {
        setState(() {
          _transactions = transactions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if(mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error loading data: ${e.toString()}"))
        );
      }
    }
  }

  Future<void> _deleteFromSupabase(String transactionId) async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client
          .from('transactions')
          .delete()
          .eq('id', transactionId)
          .eq('user_id', user.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting from server: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        _loadTransactions();
      }
    }
  }

  Future<void> _deleteMultipleFromSupabase() async {
    final user = _authService.currentUser;
    if (user == null) return;

    final idsToDelete = _selectedTransactionIds.toList();
    if (idsToDelete.isEmpty) return;

    setState(() {
      _transactions.removeWhere((tx) => _selectedTransactionIds.contains(tx.id!));
      _selectedTransactionIds.clear();
      _isSelectionMode = false;
    });

    try {
      await Supabase.instance.client
          .from('transactions')
          .delete()
          .filter('id', 'in', idsToDelete) // Corrected filter
          .eq('user_id', user.id);

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transactions deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting from server: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
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

  void _navigateToEditScreen(TransactionModel transaction) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(prefillData: transaction),
      ),
    );
    _loadTransactions();
  }

  void _handleLongPress(TransactionModel transaction) {
    if (!_isSelectionMode) {
      setState(() {
        _isSelectionMode = true;
        _selectedTransactionIds.add(transaction.id!);
      });
    }
  }

  void _handleTap(TransactionModel transaction) {
    if (_isSelectionMode) {
      setState(() {
        if (_selectedTransactionIds.contains(transaction.id!)) {
          _selectedTransactionIds.remove(transaction.id!);
        } else {
          _selectedTransactionIds.add(transaction.id!);
        }

        if (_selectedTransactionIds.isEmpty) {
          _isSelectionMode = false;
        }
      });
    } else {
      _navigateToEditScreen(transaction);
    }
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete ${_selectedTransactionIds.length} selected transaction(s)? This cannot be undone.'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteMultipleFromSupabase();
            },
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    if (_isSelectionMode) {
      return AppBar(
        backgroundColor: Colors.blueGrey[800],
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            setState(() {
              _isSelectionMode = false;
              _selectedTransactionIds.clear();
            });
          },
        ),
        title: Text(
          '${_selectedTransactionIds.length} selected',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            tooltip: 'Delete selected items',
            onPressed: _showDeleteConfirmationDialog,
          ),
        ],
      );
    } else {
      return AppBar(
        title: const Text("Transactions"),
        backgroundColor: const Color(0xFF006241),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final dateFormatter = DateFormat('MMM d, yyyy h:mm a');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _buildBody(currencyFormatter, dateFormatter),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
        onPressed: _navigateAndRefresh,
        backgroundColor: const Color(0xFF006241),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildBody(NumberFormat currencyFormatter, DateFormat dateFormatter) {
    if (_isLoading) { return const Center(child: CircularProgressIndicator()); }
    if (_transactions.isEmpty) {
      return const Center(
        child: Text(
          "No transactions found.\nClick the '+' button to add one.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: ListView.builder(
        itemCount: _transactions.length,
        itemBuilder: (context, index) {
          final transaction = _transactions[index];
          final isCredit = transaction.type == TransactionType.credit;
          final isSelected = _selectedTransactionIds.contains(transaction.id!);

          return Dismissible(
            key: ValueKey(transaction.id!),
            direction: _isSelectionMode ? DismissDirection.none : DismissDirection.endToStart,
            onDismissed: (direction) {
              final removedTransaction = _transactions.removeAt(index);
              setState(() {});

              ScaffoldMessenger.of(context)
                  .showSnackBar(
                SnackBar(
                  content: const Text('Transaction deleted'),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () {
                      setState(() {
                        _transactions.insert(index, removedTransaction);
                      });
                    },
                  ),
                ),
              )
                  .closed
                  .then((reason) {
                if (reason != SnackBarClosedReason.action) {
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
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: isSelected ? Colors.blue[50] : null,
              child: ListTile(
                onLongPress: () => _handleLongPress(transaction),
                onTap: () => _handleTap(transaction),
                leading: isSelected
                    ? const Icon(Icons.check_circle, color: Colors.blue)
                    : Icon(
                  isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isCredit ? Colors.green : Colors.red,
                ),
                title: Text(
                  transaction.senderAddress,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.messageBody,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (transaction.category != null && transaction.category!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          transaction.category!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        dateFormatter.format(transaction.transactionDate.toLocal()),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
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
  }
} // End of _TransactionsTabState