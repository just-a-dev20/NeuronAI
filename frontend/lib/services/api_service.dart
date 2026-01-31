import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  late final Dio _dio;
  String? _authToken;

  ApiService({String baseUrl = 'http://localhost:8080'}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

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

  Future<Map<String, dynamic>> healthCheck() async {
    final response = await _dio.get('/health');
    return response.data;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post('/api/v1/auth/login', data: {
      'email': email,
      'password': password,
    });
    return response.data;
  }

  Future<List<Map<String, dynamic>>> getSessions() async {
    final response = await _dio.get('/api/v1/sessions');
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<Map<String, dynamic>> sendMessage({
    required String sessionId,
    required String content,
    String messageType = 'text',
    Map<String, dynamic>? metadata,
  }) async {
    final response = await _dio.post('/api/v1/chat', data: {
      'session_id': sessionId,
      'content': content,
      'message_type': messageType,
      'metadata': metadata,
    });
    return response.data;
  }

  Stream<Map<String, dynamic>> streamMessage({
    required String sessionId,
    required String content,
    String messageType = 'text',
  }) async* {
    final response = await _dio.post(
      '/api/v1/chat/stream',
      data: {
        'session_id': sessionId,
        'content': content,
        'message_type': messageType,
      },
      options: Options(
        responseType: ResponseType.stream,
      ),
    );

    final stream = response.data.stream as Stream<List<int>>;
    final buffer = StringBuffer();

    await for (final chunk in stream) {
      buffer.write(utf8.decode(chunk));

      while (true) {
        final lineEnd = buffer.toString().indexOf('\n\n');
        if (lineEnd == -1) break;

        final event = buffer.toString().substring(0, lineEnd);
        buffer.clear();
        buffer.write(buffer.toString().substring(lineEnd + 2));

        if (event.startsWith('data: ')) {
          final data = event.substring(6);
          try {
            yield jsonDecode(data) as Map<String, dynamic>;
          } catch (e) {
            if (kDebugMode) {
              print('Error parsing SSE data: $e');
            }
          }
        }
      }
    }
  }

  Future<void> uploadFile({
    required String filePath,
    required String sessionId,
    Function(int, int)? onProgress,
  }) async {
    final file = File(filePath);
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      'session_id': sessionId,
    });

    await _dio.post(
      '/api/v1/upload',
      data: formData,
      onSendProgress: onProgress,
    );
  }
}
