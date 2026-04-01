import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/login_screen.dart';
import 'screens/profile_setup_screen.dart'; 
import 'services/auth_service.dart';
import 'providers/app_provider.dart';
import 'screens/home_screen.dart';

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
      
      // ---------------------------------------------------------
      // THE NEW SMART GATEKEEPER
      // ---------------------------------------------------------
      home: StreamBuilder<User?>(
        // 1. Check if they are logged in at all
        stream: AuthService().authStateChanges,
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          
          // 2. If they are NOT logged in, show the Login Screen
          if (!authSnapshot.hasData || authSnapshot.data == null) {
            return const LoginScreen();
          }

          // 3. If they ARE logged in, check their Firestore profile!
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(authSnapshot.data!.uid).snapshots(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }

              // 4. Check if the profile exists AND is marked as complete
              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                if (userData != null && userData['profileComplete'] == true) {
                  // They are fully set up! Let them into the app.
                  return const HomeScreen();
                }
              }

              // 5. If their profile is missing or incomplete, trap them on the Setup Screen!
              return const ProfileSetupScreen();
            },
          );
        },
      ),
      // ---------------------------------------------------------
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
      textTheme: GoogleFonts.nunitoTextTheme(),
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
      textTheme: GoogleFonts.nunitoTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF97316),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }
}