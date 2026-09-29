import 'package:flutter/material.dart';
import 'api_client.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

// ── CONFIGURE YOUR BACKEND URL HERE ─────────────────────
// Backend en producción en Render
const String apiBaseUrl = 'https://asistente-ventas-marketplace.onrender.com';
// Para desarrollo local: 'http://10.0.2.2:3001' (emulador) o 'http://localhost:3001'
// ─────────────────────────────────────────────────────────

final apiClient = ApiClient(baseUrl: apiBaseUrl);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await apiClient.init();
  runApp(const SalesApp());
}

class SalesApp extends StatelessWidget {
  const SalesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi mesa de ventas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF172A3A),
          primary: const Color(0xFF172A3A),
          secondary: const Color(0xFFDF7447),
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F4EF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF172A3A),
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(19),
            side: const BorderSide(color: Color(0xFFE0E5DF)),
          ),
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFCED8D2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFDF7447), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDF7447),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: const BorderSide(color: Color(0xFFDCE2DD)),
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
          ),
        ),
      ),
      home: apiClient.isLoggedIn
          ? const HomeScreen()
          : const LoginScreen(),
    );
  }
}
