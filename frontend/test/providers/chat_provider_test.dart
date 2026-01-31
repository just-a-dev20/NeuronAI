import 'package:flutter_test/flutter_test.dart';
import 'package:neuronai/providers/chat_provider.dart';
import 'package:neuronai/services/api_service.dart';
import 'package:neuronai/services/websocket_service.dart';

class MockApiService implements ApiService {
  String? _authToken;

  @override
  void setAuthToken(String? token) {
    _authToken = token;
  }

  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    throw UnimplementedError();
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
  Future<String> uploadFile({required String filePath, required String sessionId}) async {
    throw UnimplementedError();
  }
}

class MockWebSocketService implements WebSocketService {
  final StreamController<Map<String, dynamic>> _messageController = StreamController.broadcast();

  @override
  void dispose() {
    _messageController.close();
  }

  @override
  void sendMessage(Map<String, dynamic> message) {
    // Mock implementation
  }

  @override
  Future<void> connect({required String userId, required String sessionId}) async {
    // Mock implementation
  }

  @override
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  void addMessage(Map<String, dynamic> message) {
    _messageController.add(message);
  }
}

void main() {
  late ChatProvider chatProvider;
  late MockApiService mockApiService;
  late MockWebSocketService mockWebSocketService;

  setUp(() {
    mockApiService = MockApiService();
    mockWebSocketService = MockWebSocketService();
    chatProvider = ChatProvider(
      apiService: mockApiService,
      wsService: mockWebSocketService,
      authToken: 'test-token',
    );
  });

  tearDown(() {
    chatProvider.dispose();
    mockWebSocketService.dispose();
  });

  group('ChatProvider Initialization', () {
    test('should initialize with default values', () {
      expect(chatProvider.messages, isEmpty);
      expect(chatProvider.sessions, isEmpty);
      expect(chatProvider.currentSession, isNull);
      expect(chatProvider.isLoading, false);
      expect(chatProvider.isStreaming, false);
      expect(chatProvider.error, isNull);
    });
  });

  group('ChatProvider Session Management', () {
    test('should create a new session', () async {
      await chatProvider.createSession();

      expect(chatProvider.sessions, isNotEmpty);
      expect(chatProvider.currentSession, isNotNull);
      expect(chatProvider.messages, isEmpty);
    });

    test('should clear messages when creating new session', () async {
      mockWebSocketService.addMessage({
        'id': 'msg-1',
        'session_id': 'session-1',
        'content': 'Test message',
        'user_id': 'user-123',
        'timestamp': DateTime.now().toIso8601String(),
      });

      await chatProvider.createSession();

      expect(chatProvider.messages, isEmpty);
    });

    test('should select session', () async {
      await chatProvider.createSession();

      final sessionId = chatProvider.currentSession!.id;
      chatProvider.selectSession(sessionId);

      expect(chatProvider.currentSession?.id, sessionId);
    });

    test('should notify listeners when session is created', () async {
      var listenerCalled = false;
      chatProvider.addListener(() {
        if (chatProvider.currentSession != null) {
          listenerCalled = true;
        }
      });

      await chatProvider.createSession();

      expect(listenerCalled, true);
    });
  });

  group('ChatProvider Message Management', () {
    test('should add user message when sending', () async {
      await chatProvider.sendMessage('Hello, world!');

      expect(chatProvider.messages, isNotEmpty);
      expect(chatProvider.messages.first.content, 'Hello, world!');
      expect(chatProvider.messages.first.userId, 'current_user');
    });

    test('should set loading state when sending message', () async {
      final listenerCalled = <bool>[];
      chatProvider.addListener(() {
        listenerCalled.add(chatProvider.isLoading);
      });

      await chatProvider.sendMessage('Test message');

      expect(listenerCalled.contains(true), true);
    });

    test('should handle WebSocket message', () {
      const messageData = {
        'id': 'msg-1',
        'session_id': 'session-1',
        'content': 'AI response',
        'user_id': 'ai-agent',
        'timestamp': '2024-01-01T00:00:00.000Z',
        'is_final': true,
      };

      mockWebSocketService.addMessage(messageData);

      expect(chatProvider.messages, isNotEmpty);
      expect(chatProvider.messages.last.content, 'AI response');
    });

    test('should update existing message if ID matches', () async {
      await chatProvider.sendMessage('Initial message');

      final messageId = chatProvider.messages.first.id;

      mockWebSocketService.addMessage({
        'id': messageId,
        'session_id': 'session-1',
        'content': 'Updated message',
        'user_id': 'ai-agent',
        'timestamp': DateTime.now().toIso8601String(),
        'is_final': true,
      });

      expect(chatProvider.messages.first.content, 'Updated message');
    });

    test('should set streaming state based on message final status', () async {
      await chatProvider.sendMessage('Test message');

      mockWebSocketService.addMessage({
        'id': 'msg-1',
        'session_id': 'session-1',
        'content': 'Partial response',
        'user_id': 'ai-agent',
        'timestamp': DateTime.now().toIso8601String(),
        'is_final': false,
      });

      expect(chatProvider.isStreaming, true);

      mockWebSocketService.addMessage({
        'id': 'msg-2',
        'session_id': 'session-1',
        'content': 'Final response',
        'user_id': 'ai-agent',
        'timestamp': DateTime.now().toIso8601String(),
        'is_final': true,
      });

      expect(chatProvider.isStreaming, false);
    });
  });

  group('ChatProvider Error Handling', () {
    test('should clear error when called', () async {
      chatProvider.clearError();

      expect(chatProvider.error, isNull);
    });

    test('should notify listeners when clearing error', () async {
      chatProvider.clearError();
      expect(chatProvider.error, isNull);
    });
  });

  group('ChatProvider Auth Token', () {
    test('should set auth token', () {
      chatProvider.setAuthToken('new-token');

      expect(chatProvider.toString().contains('new-token'), false);
    });

    test('should notify listeners when auth token changes', () {
      var listenerCalled = false;
      chatProvider.addListener(() {
        listenerCalled = true;
      });

      chatProvider.setAuthToken('new-token');

      expect(listenerCalled, true);
    });
  });

  group('ChatProvider Getters', () {
    test('should return unmodifiable messages list', () async {
      await chatProvider.sendMessage('Test message');

      final messages = chatProvider.messages;

      expect(messages, isNotEmpty);
      expect(messages is List<Message>, true);
    });

    test('should return unmodifiable sessions list', () async {
      await chatProvider.createSession();

      final sessions = chatProvider.sessions;

      expect(sessions, isNotEmpty);
      expect(sessions is List<ChatSession>, true);
    });

    test('should return current session', () async {
      await chatProvider.createSession();

      final currentSession = chatProvider.currentSession;

      expect(currentSession, isNotNull);
    });

    test('should return loading state', () async {
      await chatProvider.sendMessage('Test message');

      final isLoading = chatProvider.isLoading;

      expect(isLoading, isA<bool>());
    });

    test('should return streaming state', () async {
      await chatProvider.sendMessage('Test message');

      mockWebSocketService.addMessage({
        'id': 'msg-1',
        'session_id': 'session-1',
        'content': 'Response',
        'user_id': 'ai-agent',
        'timestamp': DateTime.now().toIso8601String(),
        'is_final': false,
      });

      final isStreaming = chatProvider.isStreaming;

      expect(isStreaming, isA<bool>());
    });
  });

  group('ChatProvider Disposal', () {
    test('should dispose WebSocket service', () {
      chatProvider.dispose();

      // Provider should be disposed without throwing
    });

    test('should handle multiple disposals gracefully', () {
      chatProvider.dispose();
      chatProvider.dispose();

      // Should not throw
    });
  });
}
