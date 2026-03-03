import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';

/// Possible states for an authentication operation.
enum AuthStatus { idle, loading, success, error }

/// ViewModel for authentication screens (Login, Sign-Up).
///
/// Follows the MVVM pattern: the UI binds to this ViewModel via [Provider]/
/// [ChangeNotifier] and never touches [AuthService] directly.
class AuthViewModel extends ChangeNotifier {
  final AuthService _authService;

  AuthStatus _status = AuthStatus.idle;
  String? _errorMessage;

  AuthViewModel({AuthService? authService})
      : _authService = authService ?? AuthService();

  /// Current authentication operation status.
  AuthStatus get status => _status;

  /// Human-readable error message when [status] is [AuthStatus.error].
  String? get errorMessage => _errorMessage;

  /// `true` while an operation is in progress.
  bool get isLoading => _status == AuthStatus.loading;

  // ---------------------------------------------------------------------------
  // Sign-up
  // ---------------------------------------------------------------------------

  /// Registers a new account with [email] and [password].
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> signUp({
    required String email,
    required String password,
  }) async {
    _setLoading();
    try {
      await _authService.signUp(email: email, password: password);
      _setSuccess();
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('An unexpected error occurred.');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Sign-in
  // ---------------------------------------------------------------------------

  /// Signs in with [email] and [password].
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading();
    try {
      await _authService.signIn(email: email, password: password);
      _setSuccess();
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('An unexpected error occurred.');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Sign-out
  // ---------------------------------------------------------------------------

  /// Signs out the current user.
  Future<void> signOut() async {
    _setLoading();
    try {
      await _authService.signOut();
      _setSuccess();
    } on AuthException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('An unexpected error occurred.');
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _setLoading() {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setSuccess() {
    _status = AuthStatus.success;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _status = AuthStatus.error;
    _errorMessage = message;
    notifyListeners();
  }

  /// Resets the status back to [AuthStatus.idle].
  void reset() {
    _status = AuthStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }
}
