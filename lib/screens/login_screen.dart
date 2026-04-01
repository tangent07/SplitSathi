import '../services/auth_service.dart';
import '../widgets/phone_login_sheet.dart'; // <-- NEW IMPORT
import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF97316), Color(0xFFEA580C)], 
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                
                // Logo Area
                const Icon(Icons.account_balance_wallet, size: 80, color: Colors.white),
                const SizedBox(height: 20),
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(text: 'Split', style: TextStyle(fontFamily: 'Nunito', fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white)),
                      TextSpan(text: 'Sathi', style: TextStyle(fontFamily: 'Nunito', fontSize: 42, fontWeight: FontWeight.w900, color: Color(0xFFFCD34D))),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Split bills. Not friendships. 🤝', style: TextStyle(fontSize: 16, color: Colors.white70)),
                
                const Spacer(),

                // Login Buttons Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text('Let\'s get started', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 24),
                      
                      // Google Button
                      ElevatedButton(
                        onPressed: () async {
                          final authService = AuthService();
                          await authService.signInWithGoogle();
                          // Boom! Gatekeeper takes over from here!
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                          minimumSize: const Size(double.infinity, 54),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.g_mobiledata, size: 32, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Continue with Google', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // THE NEW PHONE BUTTON
                      ElevatedButton(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const PhoneLoginSheet(),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFF7ED), 
                          foregroundColor: const Color(0xFFEA580C),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          minimumSize: const Size(double.infinity, 54),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.phone),
                            SizedBox(width: 8),
                            Text('Continue with Phone', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}