import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/chat_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'services/websocket_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NeuronAIApp());
}

class NeuronAIApp extends StatelessWidget {
  const NeuronAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>(
          create: (_) => ApiService(),
        ),
        Provider<WebSocketService>(
          create: (_) => WebSocketService(),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            apiService: context.read<ApiService>(),
          ),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (context) => ChatProvider(
            apiService: context.read<ApiService>(),
            wsService: context.read<WebSocketService>(),
          ),
          update: (context, auth, previous) => ChatProvider(
            apiService: context.read<ApiService>(),
            wsService: context.read<WebSocketService>(),
            authToken: auth.token,
          ),
        ),
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'NeuronAI',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6366F1),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          fontFamily: 'Inter',
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6366F1),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          fontFamily: 'Inter',
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return auth.isAuthenticated
            ? const ChatScreen()
            : const LoginScreen();
      },
    );
  }
}
