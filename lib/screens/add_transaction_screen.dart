import 'package:flutter/material.dart';
import 'package:finsight/models/transaction_model.dart';
import 'package:finsight/services/auth_service.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import 'package:supabase_flutter/supabase_flutter.dart';

class AddTransactionScreen extends StatefulWidget {
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
  String? _selectedCategory;
  bool _isLoading = false;
  late final bool _isEditMode;
  late DateTime _selectedDateTime; // Holds the chosen date and time

  final List<String> _categories = [
    'Shopping', 'Food & Drinks', 'Travel', 'Entertainment', 'Bills & Utilities',
    'Groceries', 'Health & Wellness', 'Transport', 'Income', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.prefillData != null && widget.prefillData!.id != null;

    if (_isEditMode) {
      _selectedDateTime = widget.prefillData!.transactionDate;
    } else {
      _selectedDateTime = DateTime.now();
    }

    if (widget.prefillData != null) {
      _senderController.text = widget.prefillData!.senderAddress;
      _bodyController.text = widget.prefillData!.messageBody;
      _amountController.text = widget.prefillData!.amount.toStringAsFixed(2);
      _selectedType = widget.prefillData!.type;
      if (_categories.contains(widget.prefillData!.category)) {
        _selectedCategory = widget.prefillData!.category;
      } else if (widget.prefillData!.category != null && widget.prefillData!.category!.isNotEmpty) {
        if (!_categories.contains(widget.prefillData!.category!)) {
          _categories.add(widget.prefillData!.category!);
        }
        _selectedCategory = widget.prefillData!.category;
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && picked != _selectedDateTime) {
      setState(() {
        _selectedDateTime = DateTime(
          picked.year, picked.month, picked.day,
          _selectedDateTime.hour, _selectedDateTime.minute,
        );
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (picked != null) {
      setState(() {
        _selectedDateTime = DateTime(
          _selectedDateTime.year, _selectedDateTime.month, _selectedDateTime.day,
          picked.hour, picked.minute,
        );
      });
    }
  }

  // --- THIS FUNCTION HAS THE DEBUG PRINT ---
  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) { return; }
    setState(() => _isLoading = true);

    final user = AuthService().currentUser;
    if (user == null) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: User not logged in.')));
      setState(() => _isLoading = false);
      return;
    }
    final amount = double.tryParse(_amountController.text);
    if (amount == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid amount.')));
      setState(() => _isLoading = false);
      return;
    }

    final Map<String, dynamic> data = {
      'user_id': user.id,
      'sender_address': _senderController.text,
      'message_body': _bodyController.text,
      'amount': amount,
      'type': _selectedType == TransactionType.credit ? 'credit' : 'debit',
      'category': _selectedCategory,
      'transaction_date': _selectedDateTime.toIso8601String(), // Using the selected date/time
    };

    // --- DEBUG PRINT STATEMENTS ---
    print("--- Saving Data ---");
    print("Is Edit Mode: $_isEditMode");
    print("Data being sent: $data");
    // --- END OF DEBUG PRINT ---

    try {
      if (_isEditMode) {
        await Supabase.instance.client
            .from('transactions')
            .update(data)
            .eq('id', widget.prefillData!.id!)
            .eq('user_id', user.id);
      } else {
        await Supabase.instance.client
            .from('transactions')
            .insert(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode
                ? 'Transaction updated successfully!'
                : 'Transaction saved successfully!'),
          ),
        );
        Navigator.of(context).pop(); // Go back to the list
        if (widget.prefillData != null && !_isEditMode) {
          Navigator.of(context).pop();
        }
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
  // --- END OF UPDATED FUNCTION ---

  String _getAppBarTitle() { return _isEditMode ? 'Edit Transaction' : (widget.prefillData != null ? 'Confirm Transaction' : 'Add Manual Transaction'); }
  String _getButtonText() { return _isEditMode ? 'Update Transaction' : (widget.prefillData != null ? 'Confirm & Save' : 'Save Transaction'); }

  @override
  Widget build(BuildContext context) {
    final DateFormat dateFormatter = DateFormat('EEE, MMM d, yyyy');
    final DateFormat timeFormatter = DateFormat('h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        backgroundColor: const Color(0xFF006241),
        titleTextStyle: const TextStyle( color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,),
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
                  onPressed: (index) { setState(() { _selectedType = index == 0 ? TransactionType.debit : TransactionType.credit; }); },
                  borderRadius: BorderRadius.circular(8),
                  selectedColor: Colors.white,
                  fillColor: _selectedType == TransactionType.debit ? Colors.red : Colors.green,
                  children: const [
                    Padding( padding: EdgeInsets.symmetric(horizontal: 16), child: Text('DEBIT'), ),
                    Padding( padding: EdgeInsets.symmetric(horizontal: 16), child: Text('CREDIT'), ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context),
                        child: InputDecorator(
                          decoration: const InputDecoration( labelText: 'Date', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today), ),
                          child: Text(dateFormatter.format(_selectedDateTime)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(context),
                        child: InputDecorator(
                          decoration: const InputDecoration( labelText: 'Time', border: OutlineInputBorder(), prefixIcon: Icon(Icons.access_time), ),
                          child: Text(timeFormatter.format(_selectedDateTime)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration( labelText: 'Amount (e.g., 500.00)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.currency_rupee), ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) { return 'Please enter an amount'; }
                    if (double.tryParse(value) == null) { return 'Please enter a valid number'; }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _senderController,
                  decoration: const InputDecoration( labelText: 'Sender / Merchant', border: OutlineInputBorder(), ),
                  validator: (value) {
                    if (value == null || value.isEmpty) { return 'Please enter a sender'; }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration( labelText: 'Category', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category), ),
                  hint: const Text('Select a category'),
                  items: _categories.map((String category) {
                    return DropdownMenuItem<String>( value: category, child: Text(category), );
                  }).toList(),
                  onChanged: (newValue) { setState(() { _selectedCategory = newValue; }); },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bodyController,
                  maxLines: 4,
                  decoration: InputDecoration( labelText: 'Description / Original Text', border: const OutlineInputBorder(), filled: _isEditMode ? false : (widget.prefillData != null), fillColor: _isEditMode ? null : Colors.grey[100],),
                  readOnly: (widget.prefillData != null && !_isEditMode), // Prevent editing OCR text
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                  onPressed: _saveTransaction,
                  style: ElevatedButton.styleFrom( backgroundColor: const Color(0xFF006241), padding: const EdgeInsets.symmetric(vertical: 16), ),
                  child: Text( _getButtonText(), style: const TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}