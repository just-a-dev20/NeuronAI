# NeuronAI Frontend Documentation

## Overview

The NeuronAI frontend is a cross-platform Flutter application supporting Android, iPad, and Linux Desktop.

## Architecture

```
lib/
├── main.dart                    # Application entry
├── models/
│   └── message_model.dart       # Data models
├── providers/
│   ├── auth_provider.dart       # Authentication state
│   ├── chat_provider.dart       # Chat state management
│   └── settings_provider.dart   # App settings
├── services/
│   ├── api_service.dart         # HTTP API client
│   └── websocket_service.dart   # WebSocket client
├── screens/
│   ├── login_screen.dart        # Authentication UI
│   └── chat_screen.dart         # Main chat interface
└── widgets/
    ├── chat_input.dart          # Message input
    └── message_bubble.dart      # Message display
```

## State Management

### Provider Pattern

The app uses Provider for state management with three main providers:

#### AuthProvider

Manages user authentication state:

```dart
class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;
  
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String? _token;
  String? _userId;
  
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get token => _token;
  String? get userId => _userId;
  
  AuthProvider({required ApiService apiService}) 
      : _apiService = apiService {
    _checkAuthStatus();
  }
  
  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final response = await _apiService.login(email, password);
      _token = response.token;
      _userId = response.userId;
      _isAuthenticated = true;
      
      await _saveToken(_token!);
    } catch (e) {
      _isAuthenticated = false;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> logout() async {
    _token = null;
    _userId = null;
    _isAuthenticated = false;
    await _clearToken();
    notifyListeners();
  }
  
  Future<void> _checkAuthStatus() async {
    final token = await _getToken();
    if (token != null) {
      _token = token;
      _isAuthenticated = true;
    }
    _isLoading = false;
    notifyListeners();
  }
}
```

#### ChatProvider

Manages chat state and messaging:

```dart
class ChatProvider extends ChangeNotifier {
  final ApiService _apiService;
  final WebSocketService _wsService;
  final String? _authToken;
  
  List<Message> _messages = [];
  bool _isLoading = false;
  bool _isStreaming = false;
  String? _currentSessionId;
  
  List<Message> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isStreaming => _isStreaming;
  
  ChatProvider({
    required ApiService apiService,
    required WebSocketService wsService,
    String? authToken,
  })  : _apiService = apiService,
        _wsService = wsService,
        _authToken = authToken {
    _initWebSocket();
  }
  
  void _initWebSocket() {
    if (_authToken != null) {
      _wsService.connect(_authToken);
      _wsService.messages.listen(_handleWebSocketMessage);
    }
  }
  
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;
    
    final userMessage = Message(
      id: _generateId(),
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
    );
    
    _messages.add(userMessage);
    _isLoading = true;
    notifyListeners();
    
    try {
      await _wsService.sendMessage(
        sessionId: _currentSessionId ?? _generateId(),
        content: content,
      );
    } catch (e) {
      _messages.add(Message(
        id: _generateId(),
        content: "Error: Failed to send message",
        isUser: false,
        isError: true,
        timestamp: DateTime.now(),
      ));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void _handleWebSocketMessage(dynamic data) {
    final message = WebSocketMessage.fromJson(data);
    
    switch (message.type) {
      case 'chat_response':
        _handleChatResponse(message.payload);
        break;
      case 'stream_chunk':
        _handleStreamChunk(message.payload);
        break;
      case 'error':
        _handleError(message.error);
        break;
    }
  }
  
  void _handleStreamChunk(Map<String, dynamic> payload) {
    final chunk = payload['chunk'] as String;
    final isFinal = payload['is_final'] as bool;
    
    if (_messages.isNotEmpty && !_messages.last.isUser) {
      // Append to existing AI message
      final lastMessage = _messages.last;
      _messages[_messages.length - 1] = lastMessage.copyWith(
        content: lastMessage.content + chunk,
      );
    } else {
      // Create new AI message
      _messages.add(Message(
        id: payload['message_id'] ?? _generateId(),
        content: chunk,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    }
    
    _isStreaming = !isFinal;
    notifyListeners();
  }
  
  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }
}
```

#### SettingsProvider

Manages app settings:

```dart
class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String _apiBaseUrl = 'http://localhost:8080';
  bool _streamResponses = true;
  
  ThemeMode get themeMode => _themeMode;
  String get apiBaseUrl => _apiBaseUrl;
  bool get streamResponses => _streamResponses;
  
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _saveSettings();
    notifyListeners();
  }
  
  Future<void> setApiBaseUrl(String url) async {
    _apiBaseUrl = url;
    await _saveSettings();
    notifyListeners();
  }
  
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values[prefs.getInt('themeMode') ?? 0];
    _apiBaseUrl = prefs.getString('apiBaseUrl') ?? 'http://localhost:8080';
    _streamResponses = prefs.getBool('streamResponses') ?? true;
    notifyListeners();
  }
  
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', _themeMode.index);
    await prefs.setString('apiBaseUrl', _apiBaseUrl);
    await prefs.setBool('streamResponses', _streamResponses);
  }
}
```

## Services

### ApiService

HTTP client using Dio:

```dart
class ApiService {
  late final Dio _dio;
  String? _authToken;
  
  ApiService({String baseUrl = 'http://localhost:8080'}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    
    _setupInterceptors();
  }
  
  void _setupInterceptors() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_authToken != null) {
          options.headers['Authorization'] = 'Bearer $_authToken';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          // Handle token expiration
        }
        return handler.next(error);
      },
    ));
  }
  
  void setAuthToken(String? token) {
    _authToken = token;
  }
  
  Future<LoginResponse> login(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    
    return LoginResponse.fromJson(response.data);
  }
  
  Future<ChatResponse> sendMessage(ChatRequest request) async {
    final response = await _dio.post('/api/v1/chat', data: request.toJson());
    return ChatResponse.fromJson(response.data);
  }
  
  Stream<ChatChunk> streamMessage(ChatRequest request) async* {
    final response = await _dio.post(
      '/api/v1/chat/stream',
      data: request.toJson(),
      options: Options(responseType: ResponseType.stream),
    );
    
    await for (final chunk in response.data.stream) {
      final lines = utf8.decode(chunk).trim().split('\n');
      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          yield ChatChunk.fromJson(jsonDecode(data));
        }
      }
    }
  }
}
```

### WebSocketService

WebSocket client with auto-reconnection:

```dart
class WebSocketService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<dynamic>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  
  Timer? _reconnectTimer;
  String? _authToken;
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  
  Stream<dynamic> get messages => _messageController.stream;
  Stream<bool> get connectionStatus => _connectionController.stream;
  bool get isConnected => _isConnected;
  
  void connect(String authToken) {
    _authToken = authToken;
    _connect();
  }
  
  void _connect() {
    if (_authToken == null) return;
    
    try {
      final wsUrl = Uri.parse('ws://localhost:8080/ws?token=$_authToken');
      _channel = WebSocketChannel.connect(wsUrl);
      
      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDisconnected,
      );
      
      _isConnected = true;
      _reconnectAttempts = 0;
      _connectionController.add(true);
    } catch (e) {
      _onError(e);
    }
  }
  
  void _onMessage(dynamic data) {
    try {
      final message = jsonDecode(data);
      _messageController.add(message);
    } catch (e) {
      debugPrint('Failed to parse WebSocket message: $e');
    }
  }
  
  void _onError(dynamic error) {
    debugPrint('WebSocket error: $error');
    _isConnected = false;
    _connectionController.add(false);
    _scheduleReconnect();
  }
  
  void _onDisconnected() {
    debugPrint('WebSocket disconnected');
    _isConnected = false;
    _connectionController.add(false);
    _scheduleReconnect();
  }
  
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('Max reconnection attempts reached');
      return;
    }
    
    _reconnectAttempts++;
    final delay = Duration(seconds: pow(2, _reconnectAttempts).toInt());
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _connect);
  }
  
  void sendMessage({
    required String sessionId,
    required String content,
    String messageType = 'text',
  }) {
    if (!_isConnected) throw Exception('WebSocket not connected');
    
    final message = {
      'type': 'chat',
      'payload': {
        'session_id': sessionId,
        'content': content,
        'message_type': messageType,
      },
    };
    
    _channel!.sink.add(jsonEncode(message));
  }
  
  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    _connectionController.add(false);
  }
  
  void dispose() {
    disconnect();
    _messageController.close();
    _connectionController.close();
  }
}
```

## UI Components

### ChatScreen

Main chat interface:

```dart
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NeuronAI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettings(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chat, child) {
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: chat.messages.length,
                  itemBuilder: (context, index) {
                    final message = chat.messages.reversed.toList()[index];
                    return MessageBubble(message: message);
                  },
                );
              },
            ),
          ),
          const ChatInput(),
        ],
      ),
    );
  }
  
  void _logout(BuildContext context) {
    context.read<AuthProvider>().logout();
  }
  
  void _showSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }
}
```

### MessageBubble

Message display widget:

```dart
class MessageBubble extends StatelessWidget {
  final Message message;
  
  const MessageBubble({
    required this.message,
    super.key,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: !isUser ? const Radius.circular(4) : null,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.isError)
              Icon(
                Icons.error,
                color: theme.colorScheme.error,
                size: 16,
              ),
            MarkdownBody(
              data: message.content,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: theme.textTheme.bodyMedium,
                code: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.timestamp),
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
```

### ChatInput

Message input widget:

```dart
class ChatInput extends StatefulWidget {
  const ChatInput({super.key});
  
  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isComposing = false;
  
  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: _handleAttachment,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: (text) {
                  setState(() {
                    _isComposing = text.trim().isNotEmpty;
                  });
                },
                onSubmitted: _isComposing ? _handleSubmit : null,
              ),
            ),
            Consumer<ChatProvider>(
              builder: (context, chat, child) {
                if (chat.isLoading) {
                  return const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                
                return IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isComposing ? _handleSubmit : null,
                  color: _isComposing
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _handleSubmit([String? text]) {
    final message = text ?? _controller.text;
    if (message.trim().isEmpty) return;
    
    context.read<ChatProvider>().sendMessage(message);
    _controller.clear();
    setState(() {
      _isComposing = false;
    });
    _focusNode.requestFocus();
  }
  
  void _handleAttachment() {
    // Implement file picker
  }
}
```

## Platform-Specific Considerations

### Android

**Permissions** (AndroidManifest.xml):
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

**Build Configuration:**
```bash
flutter build apk --release
flutter build appbundle --release
```

### iOS/iPad

**Permissions** (Info.plist):
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

**Build Configuration:**
```bash
flutter build ios --release
```

### Linux Desktop

**Dependencies:**
```bash
sudo apt-get install libblkid-dev liblzma-dev
```

**Build Configuration:**
```bash
flutter build linux --release
```

## Testing

### Unit Tests

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class MockApiService extends Mock implements ApiService {}
class MockWebSocketService extends Mock implements WebSocketService {}

void main() {
  group('ChatProvider', () {
    late ChatProvider provider;
    late MockApiService mockApi;
    late MockWebSocketService mockWs;
    
    setUp(() {
      mockApi = MockApiService();
      mockWs = MockWebSocketService();
      provider = ChatProvider(
        apiService: mockApi,
        wsService: mockWs,
        authToken: 'test-token',
      );
    });
    
    test('should add user message when sending', () async {
      when(mockWs.sendMessage(any, any, any)).thenAnswer((_) async {});
      
      await provider.sendMessage('Hello');
      
      expect(provider.messages.length, 1);
      expect(provider.messages.first.content, 'Hello');
      expect(provider.messages.first.isUser, true);
    });
    
    test('should clear messages', () {
      provider.clearMessages();
      expect(provider.messages, isEmpty);
    });
  });
}
```

### Widget Tests

```dart
void main() {
  testWidgets('MessageBubble displays correctly', (tester) async {
    final message = Message(
      id: '1',
      content: 'Hello',
      isUser: true,
      timestamp: DateTime.now(),
    );
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(message: message),
        ),
      ),
    );
    
    expect(find.text('Hello'), findsOneWidget);
  });
}
```

### Integration Tests

```dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  testWidgets('full chat flow', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    
    // Login
    await tester.enterText(find.byType(TextField).first, 'user@example.com');
    await tester.enterText(find.byType(TextField).last, 'password');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    
    // Send message
    await tester.enterText(find.byType(TextField), 'Hello AI');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    
    // Verify message appears
    expect(find.text('Hello AI'), findsOneWidget);
  });
}
```

## Performance Optimization

### Best Practices

1. **Use const constructors** where possible
2. **Implement ListView.builder** for long lists
3. **Use RepaintBoundary** for complex widgets
4. **Cache expensive operations**
5. **Lazy load images**
6. **Debounce user input**
7. **Use Isolate for heavy computations**

### Example Optimizations

```dart
// Use const
const MessageBubble(message: message)  // Good
MessageBubble(message: message)        // Avoid

// ListView.builder for long lists
ListView.builder(
  itemCount: messages.length,
  itemBuilder: (context, index) => MessageBubble(
    message: messages[index],
  ),
)

// RepaintBoundary for complex widgets
RepaintBoundary(
  child: MarkdownBody(data: longContent),
)

// Debounce input
final _debouncer = Debouncer(milliseconds: 500);

onChanged: (text) {
  _debouncer.run(() {
    // Perform search or validation
  });
}
```

## Building & Deployment

### Build Commands

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release

# Linux
flutter build linux --release

# Web
flutter build web --release
```

### CI/CD Pipeline

See `.github/workflows/ci.yml` for automated builds.

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Provider Package](https://pub.dev/packages/provider)
- [Dio Package](https://pub.dev/packages/dio)
- [WebSocket Channel](https://pub.dev/packages/web_socket_channel)
- [Flutter Markdown](https://pub.dev/packages/flutter_markdown)
