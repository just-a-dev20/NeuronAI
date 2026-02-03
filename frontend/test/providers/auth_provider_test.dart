import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuronai/providers/auth_provider.dart';
import 'package:neuronai/services/api_service.dart';

class MockApiService implements ApiService {
  String? _authToken;
  Map<String, dynamic>? _loginResult;
  Exception? _loginError;

  void setLoginResult(Map<String, dynamic> result) {
    _loginResult = result;
    _loginError = null;
  }

  void setLoginError(Exception error) {
    _loginError = error;
    _loginResult = null;
  }

  @override
  void setAuthToken(String? token) {
    _authToken = token;
  }

  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    if (_loginError != null) {
      throw _loginError!;
    }
    return _loginResult ??
        {'token': 'default-token', 'user_id': 'default-user'};
  }

  @override
  Future<Map<String, dynamic>> sendMessage(Map<String, dynamic> data) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Map<String, dynamic>>> getSessions() async {
    throw UnimplementedError();
  }

  @override
  Future<void> uploadFile({
    required String filePath,
    required String sessionId,
    Function(int, int)? onProgress,
  }) async {
    throw UnimplementedError();
  }
}

void main() {
  late AuthProvider authProvider;
  late MockApiService mockApiService;

  setUp(() {
    mockApiService = MockApiService();
    authProvider = AuthProvider(apiService: mockApiService);
  });

  group('AuthProvider Initialization', () {
    test('should initialize with default values', () async {
      expect(authProvider.user, isNull);
      expect(authProvider.token, isNull);
      expect(authProvider.isAuthenticated, false);
      expect(authProvider.isLoading, false);
      expect(authProvider.error, isNull);
    });
  });

  group('AuthProvider Login', () {
    test('should set loading state during login', () async {
      mockApiService.setLoginResult({
        'token': 'test-token',
        'user_id': 'user-123',
      });

      final loginFuture = authProvider.login('test@example.com', 'password');
      expect(authProvider.isLoading, true);
      expect(authProvider.error, isNull);

      await loginFuture;

      expect(authProvider.isLoading, false);
    });

    test('should update user and token on successful login', () async {
      mockApiService.setLoginResult({
        'token': 'test-token',
        'user_id': 'user-123',
      });

      await authProvider.login('test@example.com', 'password');

      expect(authProvider.token, 'test-token');
      expect(authProvider.user?.id, 'user-123');
      expect(authProvider.user?.email, 'test@example.com');
      expect(authProvider.isAuthenticated, true);
      expect(authProvider.isLoading, false);
      expect(authProvider.error, isNull);
    });

    test('should handle login error', () async {
      mockApiService.setLoginError(Exception('Invalid credentials'));

      await authProvider.login('test@example.com', 'wrong-password');

      expect(authProvider.isLoading, false);
      expect(authProvider.error, isNotNull);
      expect(authProvider.isAuthenticated, false);
      expect(authProvider.user, isNull);
      expect(authProvider.token, isNull);
    });

    test('should notify listeners on state change', () async {
      mockApiService.setLoginResult({
        'token': 'test-token',
        'user_id': 'user-123',
      });

      var listenerCalled = false;
      authProvider.addListener(() {
        listenerCalled = true;
      });

      await authProvider.login('test@example.com', 'password');

      expect(listenerCalled, true);
    });
  });

  group('AuthProvider Logout', () {
    test('should clear user and token on logout', () async {
      mockApiService.setLoginResult({
        'token': 'test-token',
        'user_id': 'user-123',
      });

      await authProvider.login('test@example.com', 'password');
      expect(authProvider.isAuthenticated, true);

      await authProvider.logout();

      expect(authProvider.user, isNull);
      expect(authProvider.token, isNull);
      expect(authProvider.isAuthenticated, false);
    });

    test('should notify listeners on logout', () async {
      mockApiService.setLoginResult({
        'token': 'test-token',
        'user_id': 'user-123',
      });

      await authProvider.login('test@example.com', 'password');

      var listenerCalled = false;
      authProvider.addListener(() {
        if (authProvider.user == null && authProvider.token == null) {
          listenerCalled = true;
        }
      });

      await authProvider.logout();

      expect(listenerCalled, true);
    });
  });

  group('AuthProvider Clear Error', () {
    test('should clear error when called', () async {
      mockApiService.setLoginError(Exception('Test error'));

      await authProvider.login('test@example.com', 'password');
      expect(authProvider.error, isNotNull);

      authProvider.clearError();

      expect(authProvider.error, isNull);
    });

    test('should notify listeners when clearing error', () async {
      mockApiService.setLoginError(Exception('Test error'));

      await authProvider.login('test@example.com', 'password');
      expect(authProvider.error, isNotNull);

      var listenerCalled = false;
      authProvider.addListener(() {
        if (authProvider.error == null) {
          listenerCalled = true;
        }
      });

      authProvider.clearError();

      expect(listenerCalled, true);
    });
  });

  group('AuthProvider Authentication State', () {
    test('should be authenticated when token and user are set', () async {
      mockApiService.setLoginResult({
        'token': 'test-token',
        'user_id': 'user-123',
      });

      await authProvider.login('test@example.com', 'password');

      expect(authProvider.isAuthenticated, true);
    });

    test('should not be authenticated when token is null', () {
      expect(authProvider.isAuthenticated, false);
    });

    test('should not be authenticated when user is null', () async {
      mockApiService.setLoginResult({
        'token': 'test-token',
        'user_id': 'user-123',
      });

      await authProvider.login('test@example.com', 'password');
      await authProvider.logout();

      expect(authProvider.isAuthenticated, false);
    });

    test('should not be authenticated when only token is set', () async {
      mockApiService.setLoginResult({
        'token': 'test-token',
        'user_id': 'user-123',
      });

      await authProvider.login('test@example.com', 'password');
      authProvider.logout();

      expect(authProvider.isAuthenticated, false);
    });
  });

  group('AuthProvider Getters', () {
    test('should return user correctly', () async {
      mockApiService.setLoginResult({
        'token': 'test-token',
        'user_id': 'user-123',
      });

      await authProvider.login('test@example.com', 'password');

      final user = authProvider.user;
      expect(user, isNotNull);
      expect(user!.id, 'user-123');
      expect(user.email, 'test@example.com');
    });

    test('should return token correctly', () async {
      mockApiService.setLoginResult({
        'token': 'test-token',
        'user_id': 'user-123',
      });

      await authProvider.login('test@example.com', 'password');

      expect(authProvider.token, 'test-token');
    });

    test('should return isLoading correctly', () async {
      mockApiService.setLoginResult({
        'token': 'test-token',
        'user_id': 'user-123',
      });

      final loginFuture = authProvider.login('test@example.com', 'password');
      expect(authProvider.isLoading, true);

      await loginFuture;
      expect(authProvider.isLoading, false);
    });
  });
}
