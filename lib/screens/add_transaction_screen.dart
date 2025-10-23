import 'package:flutter/material.dart';
import 'package:finsight/models/transaction_model.dart';
import 'package:finsight/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddTransactionScreen extends StatefulWidget {
  // We add an optional parameter to receive pre-filled data
  final TransactionModel? prefillData;

  const AddTransactionScreen({super.key, this.prefillData});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _senderController = TextEditingController();
  final _bodyController = TextEditingController();
  final _amountController = TextEditingController();
  TransactionType _selectedType = TransactionType.debit;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // When the screen loads, check if we have pre-fill data
    if (widget.prefillData != null) {
      _senderController.text = widget.prefillData!.senderAddress;
      _bodyController.text = widget.prefillData!.messageBody;
      _amountController.text = widget.prefillData!.amount.toStringAsFixed(2);
      _selectedType = widget.prefillData!.type;
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    final user = AuthService().currentUser;

    if (user == null) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: User not logged in.')),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null) {
      setState(() => _isLoading = false);
      return;
    }

    final newTransaction = TransactionModel(
      userId: user.id,
      senderAddress: _senderController.text,
      messageBody: _bodyController.text,
      transactionDate: DateTime.now(), // We could also try parsing this
      amount: amount,
      type: _selectedType,
    );

    try {
      await Supabase.instance.client
          .from('transactions')
          .insert(newTransaction.toJson());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction saved successfully!')),
        );
        // Pop twice: once to close this screen, once to close the OCR screen
        Navigator.of(context).pop();
        Navigator.of(context).pop(); // Go all the way back to the home screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Supabase Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.prefillData != null ? 'Confirm Transaction' : 'Add Manual Transaction'),
        backgroundColor: const Color(0xFF006241),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ToggleButtons(
                  isSelected: [
                    _selectedType == TransactionType.debit,
                    _selectedType == TransactionType.credit,
                  ],
                  onPressed: (index) {
                    setState(() {
                      _selectedType = index == 0
                          ? TransactionType.debit
                          : TransactionType.credit;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  selectedColor: Colors.white,
                  fillColor: _selectedType == TransactionType.debit
                      ? Colors.red
                      : Colors.green,
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('DEBIT'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('CREDIT'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount (e.g., 500.00)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.currency_rupee),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an amount';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _senderController,
                  decoration: const InputDecoration(
                    labelText: 'Sender / Merchant',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a sender';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bodyController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Original Text (from OCR)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                  onPressed: _saveTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006241),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                      widget.prefillData != null ? 'Confirm & Save' : 'Save Transaction',
                      style: const TextStyle(color: Colors.white)
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}