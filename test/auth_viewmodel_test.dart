import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:games/services/auth_service.dart';
import 'package:games/viewmodels/auth_viewmodel.dart';

import 'auth_viewmodel_test.mocks.dart';

// Generate mocks for AuthService.
@GenerateMocks([AuthService])
void main() {
  late MockAuthService mockAuthService;
  late AuthViewModel viewModel;

  setUp(() {
    mockAuthService = MockAuthService();
    viewModel = AuthViewModel(authService: mockAuthService);
  });

  group('AuthViewModel – initial state', () {
    test('status is idle on creation', () {
      expect(viewModel.status, AuthStatus.idle);
    });

    test('isLoading is false on creation', () {
      expect(viewModel.isLoading, isFalse);
    });

    test('errorMessage is null on creation', () {
      expect(viewModel.errorMessage, isNull);
    });
  });

  group('AuthViewModel – signIn', () {
    test('returns true and sets status to success on valid credentials',
        () async {
      // Arrange: stub signIn to return a successful AuthResponse.
      when(mockAuthService.signIn(
        email: 'user@example.com',
        password: 'password123',
      )).thenAnswer((_) async => AuthResponse());

      // Act
      final result = await viewModel.signIn(
        email: 'user@example.com',
        password: 'password123',
      );

      // Assert
      expect(result, isTrue);
      expect(viewModel.status, AuthStatus.success);
      expect(viewModel.errorMessage, isNull);
    });

    test('returns false and sets error message on AuthException', () async {
      // Arrange: stub signIn to throw an AuthException.
      when(mockAuthService.signIn(
        email: 'bad@example.com',
        password: 'wrong',
      )).thenThrow(AuthException('Invalid login credentials'));

      // Act
      final result = await viewModel.signIn(
        email: 'bad@example.com',
        password: 'wrong',
      );

      // Assert
      expect(result, isFalse);
      expect(viewModel.status, AuthStatus.error);
      expect(viewModel.errorMessage, 'Invalid login credentials');
    });

    test('returns false and sets generic error on unexpected exception',
        () async {
      when(mockAuthService.signIn(
        email: 'x@x.com',
        password: 'x',
      )).thenThrow(Exception('network error'));

      final result =
          await viewModel.signIn(email: 'x@x.com', password: 'x');

      expect(result, isFalse);
      expect(viewModel.status, AuthStatus.error);
      expect(viewModel.errorMessage, 'An unexpected error occurred.');
    });
  });

  group('AuthViewModel – signUp', () {
    test('returns true and sets status to success on successful registration',
        () async {
      when(mockAuthService.signUp(
        email: 'new@example.com',
        password: 'secret123',
      )).thenAnswer((_) async => AuthResponse());

      final result = await viewModel.signUp(
        email: 'new@example.com',
        password: 'secret123',
      );

      expect(result, isTrue);
      expect(viewModel.status, AuthStatus.success);
    });

    test('returns false and sets error on AuthException', () async {
      when(mockAuthService.signUp(
        email: 'exists@example.com',
        password: 'pass',
      )).thenThrow(AuthException('User already registered'));

      final result = await viewModel.signUp(
        email: 'exists@example.com',
        password: 'pass',
      );

      expect(result, isFalse);
      expect(viewModel.errorMessage, 'User already registered');
    });
  });

  group('AuthViewModel – signOut', () {
    test('sets status to success after successful sign-out', () async {
      when(mockAuthService.signOut()).thenAnswer((_) async {});

      await viewModel.signOut();

      expect(viewModel.status, AuthStatus.success);
    });

    test('sets error on AuthException during sign-out', () async {
      when(mockAuthService.signOut())
          .thenThrow(AuthException('Logout failed'));

      await viewModel.signOut();

      expect(viewModel.status, AuthStatus.error);
      expect(viewModel.errorMessage, 'Logout failed');
    });
  });

  group('AuthViewModel – reset', () {
    test('resets status to idle and clears error message', () async {
      // Put viewModel into error state first.
      when(mockAuthService.signIn(
        email: 'bad@example.com',
        password: 'wrong',
      )).thenThrow(AuthException('Invalid login credentials'));
      await viewModel.signIn(email: 'bad@example.com', password: 'wrong');

      viewModel.reset();

      expect(viewModel.status, AuthStatus.idle);
      expect(viewModel.errorMessage, isNull);
    });
  });
}
