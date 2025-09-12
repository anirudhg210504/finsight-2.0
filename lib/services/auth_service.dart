import 'package:supabase_flutter/supabase_flutter.dart';

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
}