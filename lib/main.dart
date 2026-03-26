import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'providers/app_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(prefs),
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
      home: const HomeScreen(),
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