import 'package:flutter/material.dart';
import 'package:finsight/services/auth_service.dart';
import 'package:finsight/screens/login_screen.dart'; // Import LoginScreen for navigation

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: const Color(0xFF006241),
        titleTextStyle: const TextStyle( // Added for white text
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: Colors.white), // Ensure back arrow is white
        actions: [ // Added the actions list for the button
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white), // Ensure icon is white
            tooltip: 'Logout', // Added tooltip for accessibility
            onPressed: () async {
              await AuthService().signOut();
              // Navigate back to login screen after logout
              // The StreamBuilder in main.dart might handle this automatically,
              // but explicit navigation ensures it happens immediately.
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false, // Remove all previous routes
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Logged in as:",
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                user?.email ?? 'No user logged in',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}