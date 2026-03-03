import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles all Supabase authentication API calls.
///
/// This service abstracts the Supabase client so that the rest of the app
/// does not depend directly on the Supabase SDK – making it easy to swap
/// providers or write unit tests with mocks.
class AuthService {
  final SupabaseClient _client;

  /// Creates an [AuthService] backed by the given [SupabaseClient].
  /// Defaults to the globally-initialised Supabase client.
  AuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Returns the currently signed-in [User], or `null` if nobody is signed in.
  User? get currentUser => _client.auth.currentUser;

  /// Stream of [AuthState] changes (sign-in, sign-out, token refresh, etc.).
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Signs up a new user with [email] and [password].
  ///
  /// Throws an [AuthException] on failure (e.g. email already in use).
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return _client.auth.signUp(email: email, password: password);
  }

  /// Signs in an existing user with [email] and [password].
  ///
  /// Throws an [AuthException] on failure (e.g. invalid credentials).
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Signs out the currently authenticated user.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
