import 'package:flutter/material.dart';
import 'package:finsight/screens/ocr_screen.dart'; // Import the new screen
import 'package:finsight/services/auth_service.dart'; // Import AuthService
import 'package:intl/intl.dart'; // Import for formatting
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import 'package:finsight/models/transaction_model.dart'; // Import TransactionModel

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _authService = AuthService();
  bool _isLoading = true;
  double _monthlyLimit = 0;
  double _totalSpent = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // 1. Fetch the user's profile and limit
      final profile = await _authService.getProfile();
      final limit = (profile['monthly_limit'] as num).toDouble();

      double spent = 0;
      if (limit > 0) {
        // 2. Fetch spending data only if a limit is set
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59); // Last day of month

        final response = await Supabase.instance.client
            .from('transactions')
            .select('amount')
            .eq('user_id', _authService.currentUser!.id)
            .eq('type', 'debit')
            .gte('transaction_date', startOfMonth.toIso8601String())
            .lte('transaction_date', endOfMonth.toIso8601String());

        // 3. Calculate total spent
        spent = (response as List)
            .fold(0.0, (sum, item) => sum + (item['amount'] as num).toDouble());
      }

      if (mounted) {
        setState(() {
          _monthlyLimit = limit;
          _totalSpent = spent;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Don't show an error, just fail silently
        print("Error loading dashboard data: $e");
      }
    }
  }

  // --- NEW: Helper to build the warning card ---
  Widget _buildBudgetWarningCard() {
    // If loading or no limit set, show nothing
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_monthlyLimit == 0) {
      return const SizedBox.shrink(); // No limit set, hide the card
    }

    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final percentage = _totalSpent / _monthlyLimit;

    // 1. Determine card color and status
    Color cardColor;
    Color textColor;
    String statusText;
    IconData statusIcon;

    if (percentage > 1.0) {
      cardColor = Colors.red.shade100;
      textColor = Colors.red.shade900;
      statusText = "You've exceeded your limit!";
      statusIcon = Icons.warning_rounded;
    } else if (percentage >= 0.9) {
      cardColor = Colors.orange.shade100;
      textColor = Colors.orange.shade900;
      statusText = "You're approaching your limit!";
      statusIcon = Icons.error_outline_rounded;
    } else {
      cardColor = Colors.green.shade100;
      textColor = Colors.green.shade900;
      statusText = "You're on track this month.";
      statusIcon = Icons.check_circle_outline_rounded;
    }

    return Card(
      color: cardColor,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: textColor),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "${currencyFormat.format(_totalSpent)} / ${currencyFormat.format(_monthlyLimit)}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: textColor.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 8),
            // Progress Bar
            LinearProgressIndicator(
              value: percentage.clamp(0.0, 1.0), // Cap at 1.0
              backgroundColor: Colors.black.withOpacity(0.1),
              color: Color.lerp(Colors.green, Colors.red, percentage.clamp(0.0, 1.0)),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Home"),
        backgroundColor: const Color(0xFF006241),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start, // Align to top
          children: [
            // --- ADDED THE WARNING CARD HERE ---
            _buildBudgetWarningCard(),
            const SizedBox(height: 30),
            // --- END OF ADDITION ---

            const Text(
              "Welcome to FinSight!",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF006241)),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.document_scanner_outlined, color: Colors.white),
              label: const Text(
                "Scan Receipt with OCR",
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006241),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  )
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const OcrScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}