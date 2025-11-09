// lib/screens/profile_tab.dart
import 'package:flutter/material.dart';
import 'package:finsight/services/auth_service.dart';
import 'package:finsight/screens/login_screen.dart';
import 'package:intl/intl.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _authService = AuthService();
  final _limitController = TextEditingController();
  bool _isLoading = true;
  double _currentLimit = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final profile = await _authService.getProfile();
      if (mounted) {
        setState(() {
          _currentLimit = (profile['monthly_limit'] as num).toDouble();
          _limitController.text = _currentLimit.toStringAsFixed(0);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading profile: ${e.toString()}'))
        );
      }
    }
  }

  Future<void> _saveLimit() async {
    FocusScope.of(context).unfocus(); // Hide keyboard
    final newLimit = double.tryParse(_limitController.text);
    if (newLimit == null || newLimit < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid number.'))
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.updateMonthlyLimit(newLimit);
      if (mounted) {
        setState(() {
          _currentLimit = newLimit;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Limit saved!'), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving limit: ${e.toString()}'))
        );
      }
    }
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: const Color(0xFF006241),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () async {
              await _authService.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Logged in as:",
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              user?.email ?? 'No user logged in',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 32),

            // --- NEW SPENDING LIMIT UI ---
            Text(
              'Monthly Spending Limit',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Set a limit to get alerts when you\'re approaching or over your budget.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _limitController,
              decoration: const InputDecoration(
                labelText: 'Monthly Limit',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveLimit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006241),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Save Limit', style: TextStyle(color: Colors.white)),
            ),
            // --- END OF NEW UI ---
          ],
        ),
      ),
    );
  }
}