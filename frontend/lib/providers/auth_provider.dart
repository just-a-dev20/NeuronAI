import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import '../models/message_model.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

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
      final storedToken = await _secureStorage.read(key: 'auth_token');
      final storedUserId = await _secureStorage.read(key: 'user_id');
      final storedEmail = await _secureStorage.read(key: 'user_email');

      if (storedToken != null && storedUserId != null) {
        _token = storedToken;
        _user = User(id: storedUserId, email: storedEmail ?? '');
        _apiService.setAuthToken(_token);
      }

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
      final result = await _apiService.login(email, password);

      _token = result['token'];
      _user = User(id: result['user_id'], email: email);

      await _secureStorage.write(key: 'auth_token', value: _token);
      await _secureStorage.write(key: 'user_id', value: result['user_id']);
      await _secureStorage.write(key: 'user_email', value: email);

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

    await _secureStorage.delete(key: 'auth_token');
    await _secureStorage.delete(key: 'user_id');
    await _secureStorage.delete(key: 'user_email');

    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
