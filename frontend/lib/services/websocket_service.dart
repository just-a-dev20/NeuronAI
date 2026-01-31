import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  Timer? _pingTimer;
  bool _isConnected = false;

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect({
    required String userId,
    required String sessionId,
    String baseUrl = 'ws://localhost:8080',
  }) async {
    try {
      final wsUrl = '$baseUrl/ws?user_id=$userId&session_id=$sessionId';

      if (kIsWeb) {
        _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      } else {
        _channel = IOWebSocketChannel.connect(Uri.parse(wsUrl));
      }

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message) as Map<String, dynamic>;
            _messageController.add(data);
          } catch (e) {
            if (kDebugMode) {
              print('Error parsing WebSocket message: $e');
            }
          }
        },
        onError: (error) {
          if (kDebugMode) {
            print('WebSocket error: $error');
          }
          _isConnected = false;
          _connectionController.add(false);
        },
        onDone: () {
          _isConnected = false;
          _connectionController.add(false);
          _pingTimer?.cancel();
        },
      );

      _isConnected = true;
      _connectionController.add(true);

      // Start ping timer to keep connection alive
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_isConnected) {
          sendMessage({'type': 'ping'});
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('WebSocket connection error: $e');
      }
      _isConnected = false;
      _connectionController.add(false);
      rethrow;
    }
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  void disconnect() {
    _pingTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _connectionController.add(false);
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _connectionController.close();
  }
}
