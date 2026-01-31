import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../models/message_model.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _apiService;
  final WebSocketService _wsService;
  String? _authToken;

  final List<Message> _messages = [];
  final List<ChatSession> _sessions = [];
  ChatSession? _currentSession;
  bool _isLoading = false;
  bool _isStreaming = false;
  String? _error;

  ChatProvider({
    required ApiService apiService,
    required WebSocketService wsService,
    String? authToken,
  })  : _apiService = apiService,
        _wsService = wsService,
        _authToken = authToken {
    _init();
  }

  List<Message> get messages => List.unmodifiable(_messages);
  List<ChatSession> get sessions => List.unmodifiable(_sessions);
  ChatSession? get currentSession => _currentSession;
  bool get isLoading => _isLoading;
  bool get isStreaming => _isStreaming;
  String? get error => _error;

  void _init() {
    if (_authToken != null) {
      _apiService.setAuthToken(_authToken);
    }

    // Listen to WebSocket messages
    _wsService.messageStream.listen(_handleWebSocketMessage);
  }

  void setAuthToken(String? token) {
    _authToken = token;
    _apiService.setAuthToken(token);
    notifyListeners();
  }

  Future<void> createSession() async {
    final session = ChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 'current_user',
      title: 'New Chat',
      createdAt: DateTime.now(),
      messages: [],
    );

    _sessions.add(session);
    _currentSession = session;
    _messages.clear();
    notifyListeners();

    // Connect WebSocket for this session
    await _wsService.connect(
      userId: 'current_user',
      sessionId: session.id,
    );
  }

  Future<void> sendMessage(String content, {String messageType = 'text'}) async {
    if (_currentSession == null) {
      await createSession();
    }

    final userMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sessionId: _currentSession!.id,
      userId: 'current_user',
      content: content,
      messageType: MessageType.values.firstWhere(
        (e) => e.name == messageType,
        orElse: () => MessageType.text,
      ),
      timestamp: DateTime.now(),
    );

    _messages.add(userMessage);
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Send via WebSocket for real-time updates
      _wsService.sendMessage({
        'content': content,
        'message_type': messageType,
      });
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void _handleWebSocketMessage(Map<String, dynamic> data) {
    try {
      final message = Message.fromJson(data);

      // Update or add message
      final existingIndex = _messages.indexWhere((m) => m.id == message.id);
      if (existingIndex >= 0) {
        _messages[existingIndex] = message;
      } else {
        _messages.add(message);
      }

      _isLoading = !message.isFinal;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error handling WebSocket message: $e');
      }
    }
  }

  Future<void> loadSessions() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final sessionsData = await _apiService.getSessions();
      _sessions.clear();
      
      for (final sessionData in sessionsData) {
        _sessions.add(ChatSession(
          id: sessionData['id'],
          userId: sessionData['user_id'],
          title: sessionData['title'] ?? 'New Chat',
          createdAt: DateTime.parse(sessionData['created_at']),
          messages: [],
        ));
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendFile(String filePath, String fileName) async {
    if (_currentSession == null) {
      await createSession();
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _apiService.uploadFile(
        filePath: filePath,
        sessionId: _currentSession!.id,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectSession(String sessionId) {
    _currentSession = _sessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => _currentSession!,
    );
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _wsService.dispose();
    super.dispose();
  }
}
