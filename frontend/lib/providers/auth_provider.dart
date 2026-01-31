import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/message_model.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;

  User? _user;
  String? _token;
  bool _isLoading = true;
  String? _error;

  AuthProvider({required ApiService apiService}) : _apiService = apiService {
    _checkAuth();
  }

  User? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _token != null && _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> _checkAuth() async {
    try {
      // TODO: Check for stored token
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // TODO: Implement actual login with Supabase
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call

      _token = 'dummy_token';
      _user = User(
        id: 'user_123',
        email: email,
      );

      _apiService.setAuthToken(_token);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    _apiService.setAuthToken(null);
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
