import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart'; // for kDebugMode

class AuthService {
  final GoTrueClient _supabaseAuth = Supabase.instance.client.auth;

  User? get currentUser => _supabaseAuth.currentUser;

  Future<User?> signIn(String email, String password) async {
    final response = await _supabaseAuth.signInWithPassword(
      email: email,
      password: password,
    );
    return response.user;
  }

  Future<User?> register(String email, String password) async {
    final response = await _supabaseAuth.signUp(
      email: email,
      password: password,
    );
    return response.user;
  }

  Future<void> signOut() async {
    await _supabaseAuth.signOut();
  }

  // --- ADD THESE NEW FUNCTIONS ---

  // Fetches the user's profile, creating one if it doesn't exist
  Future<Map<String, dynamic>> getProfile() async {
    if (currentUser == null) throw Exception('No user logged in');

    try {
      // Try to get the profile
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', currentUser!.id)
          .single();
      return response;
    } catch (e) {
      // If it fails (likely 'count_gte_one' error), the profile doesn't exist.
      // Let's create it.
      final response = await Supabase.instance.client
          .from('profiles')
          .insert({'id': currentUser!.id, 'monthly_limit': 0})
          .select()
          .single();
      return response;
    }
  }

  // This is needed for the Profile tab
  Future<void> updateMonthlyLimit(double limit) async {
    if (currentUser == null) throw Exception('No user logged in');

    await Supabase.instance.client
        .from('profiles')
        .update({'monthly_limit': limit})
        .eq('id', currentUser!.id);
  }
}