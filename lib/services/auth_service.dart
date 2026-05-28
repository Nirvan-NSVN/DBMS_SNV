import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient client = Supabase.instance.client;

  /// Current authenticated user (null if not logged in).
  User? get currentUser => client.auth.currentUser;

  /// Whether any user is currently signed in.
  bool get isLoggedIn => currentUser != null;

  /// Sign in with email and password.
  Future<AuthResponse> signIn(String email, String password) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign up with email and password (creates a customer account).
  /// Extra fields are stored in raw_user_meta_data for the server-side trigger.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    String address = '',
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      data: {
        'name': name,
        'phone': int.parse(phone),
        'address': address,
      },
    );
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Check if the currently logged-in user is a staff member.
  Future<bool> isStaff() async {
    final user = currentUser;
    if (user == null) return false;
    return user.appMetadata['role'] == 'staff';
  }

  /// Check if the currently logged-in user is an admin.
  Future<bool> isAdmin() async {
    final user = currentUser;
    if (user == null) return false;
    return user.appMetadata['role'] == 'admin';
  }

  /// Returns a valid access token, refreshing the session if needed.
  Future<String> getAccessToken() async {
    final session = client.auth.currentSession ?? (await client.auth.refreshSession()).session;
    if (session == null) throw Exception('Not authenticated. Please log in again.');
    return session.accessToken;
  }
}
