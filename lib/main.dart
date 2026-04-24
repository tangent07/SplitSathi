import 'services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- SCREENS ---
import 'screens/login_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';

// --- SERVICES & PROVIDERS ---
import 'services/auth_service.dart';
import 'providers/app_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppProvider(prefs),
      child: const SplitSathiApp(),
    ),
  );
}

class SplitSathiApp extends StatelessWidget {
  const SplitSathiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    return MaterialApp(
      title: 'SplitSathi',
      debugShowCheckedModeBanner: false,
      themeMode: provider.isDark ? ThemeMode.dark : ThemeMode.light,
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
      home: const SplashScreen(),
    );
  }

  ThemeData _lightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFF97316),
        primary: const Color(0xFFF97316),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFFDF6EC),
      textTheme: GoogleFonts.interTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF97316),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }

  ThemeData _darkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFF97316),
        primary: const Color(0xFFF97316),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0A0A0F),
      textTheme:
          GoogleFonts.interTextTheme(ThemeData(brightness: Brightness.dark).textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF97316),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }
}

// ---------------------------------------------------------
// THE SMART GATEKEEPER
// ---------------------------------------------------------
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFF97316)),
            ),
          );
        }

        // 1. Not logged in? -> Login Screen.
        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const LoginScreen();
        }

        // 2. Logged in — check if their profile has a name yet.
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(authSnapshot.data!.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: Color(0xFFF97316)),
                ),
              );
            }

            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final userData =
                  userSnapshot.data!.data() as Map<String, dynamic>?;
              final String name = userData?['name'] ?? '';

              if (name.trim().isNotEmpty) {
                NotificationService().init();
                return const HomeScreen();
              }
            }

            // Name missing or doc doesn't exist yet -> Setup.
            return const ProfileSetupScreen();
          },
        );
      },
    );
  }
}