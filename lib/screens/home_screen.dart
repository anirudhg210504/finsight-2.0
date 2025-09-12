import 'package:flutter/material.dart';
import 'home_tab.dart';
import 'transactions_tab.dart';
import 'reports_tab.dart';
import 'profile_tab.dart';
import 'package:flutter/material.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // We are creating a simpler list of tabs without the broken SMS parts
  final List<Widget> _tabs = [
    const HomeTab(),
    const TransactionsTab(),
    const ReportsTab(),
    const ProfileTab(),
    // The placeholder for the 5th tab is now a simple centered text
    const Center(child: Text("SMS functionality will be added back later.")),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: _tabs[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          selectedItemColor: const Color(0xFF006241),
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed, // Ensures all labels are visible
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              label: 'Transactions',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              label: 'Reports',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Profile',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.sms),
              label: 'SMS Inbox',
            ),
          ],
        ),
      ),
    );
  }
}