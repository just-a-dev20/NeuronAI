import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  String _apiUrl = 'http://localhost:8080';
  String _wsUrl = 'ws://localhost:8080';
  bool _autoPlayMedia = true;
  bool _showTypingIndicator = true;
  double _fontSize = 14.0;

  bool get isDarkMode => _isDarkMode;
  String get apiUrl => _apiUrl;
  String get wsUrl => _wsUrl;
  bool get autoPlayMedia => _autoPlayMedia;
  bool get showTypingIndicator => _showTypingIndicator;
  double get fontSize => _fontSize;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _apiUrl = prefs.getString('apiUrl') ?? 'http://localhost:8080';
    _wsUrl = prefs.getString('wsUrl') ?? 'ws://localhost:8080';
    _autoPlayMedia = prefs.getBool('autoPlayMedia') ?? true;
    _showTypingIndicator = prefs.getBool('showTypingIndicator') ?? true;
    _fontSize = prefs.getDouble('fontSize') ?? 14.0;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
    notifyListeners();
  }

  Future<void> setApiUrl(String value) async {
    _apiUrl = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('apiUrl', value);
    notifyListeners();
  }

  Future<void> setWsUrl(String value) async {
    _wsUrl = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wsUrl', value);
    notifyListeners();
  }

  Future<void> setAutoPlayMedia(bool value) async {
    _autoPlayMedia = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoPlayMedia', value);
    notifyListeners();
  }

  Future<void> setShowTypingIndicator(bool value) async {
    _showTypingIndicator = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showTypingIndicator', value);
    notifyListeners();
  }

  Future<void> setFontSize(double value) async {
    _fontSize = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', value);
    notifyListeners();
  }
}
