import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/recovery_phrase_screen.dart';
import 'screens/auth/recover_account_screen.dart';
import 'services/auth_service.dart';

// Simple Theme Notifier for global state
class ThemeNotifier extends ValueNotifier<ThemeMode> {
  ThemeNotifier(super.value);

  void toggleTheme() {
    value = value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }
}

// Global accessor (could be Provider, but this is simple enough)
final themeNotifier = ThemeNotifier(ThemeMode.dark);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AuthService _authService = AuthService();
  bool? _isLoggedIn;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final loggedIn = await _authService.isLoggedIn();
    setState(() {
      _isLoggedIn = loggedIn;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen to theme changes
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'Bit Chat',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,

          // LIGHT THEME: High Contrast (Black text on White)
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF5F5F5),
            colorScheme: ColorScheme.light(
              primary: Colors.black,
              secondary: Colors.grey[800]!,
              surface: const Color(0xFFFFFFFF),
              onSurface: Colors.black,
            ),
            textTheme: const TextTheme(
              bodyMedium: TextStyle(color: Colors.black),
              bodyLarge: TextStyle(color: Colors.black),
              titleLarge: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
              headlineLarge: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
            ),
          ),

          // DARK THEME: High Contrast (White text on Deep Black)
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF121212), // Deep Black
            colorScheme: ColorScheme.dark(
              primary: Colors.white,
              secondary: Colors.grey[300]!,
              surface: const Color(0xFF1E1E2C), // Slightly lighter for cards
              onSurface: Colors.white,
            ),
            textTheme: const TextTheme(
              bodyMedium: TextStyle(color: Colors.white),
              bodyLarge: TextStyle(color: Colors.white),
              titleLarge: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              headlineLarge: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF121212),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),

          // Routing Logic
          initialRoute: _isLoggedIn == null
              ? '/loading'
              : (_isLoggedIn! ? '/home' : '/welcome'),
          routes: {
            '/welcome': (context) => const WelcomeScreen(),
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignupScreen(),
            '/home': (context) => const HomeScreen(),
            '/recover': (context) => const RecoverAccountScreen(),
          },
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/recovery-phrase':
                final args = settings.arguments as Map<String, dynamic>?;
                return MaterialPageRoute(
                  builder: (_) => RecoveryPhraseScreen(
                    username: args?['username'] ?? 'User',
                  ),
                );
              default:
                return MaterialPageRoute(
                  builder: (_) => const WelcomeScreen(),
                );
            }
          },
          home: _isLoggedIn == null
              ? const Scaffold(
                  backgroundColor: Color(0xFF121212),
                  body: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                )
              : null, // Use initialRoute instead
        );
      },
    );
  }
}
