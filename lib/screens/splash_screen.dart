import '../main.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  // How far (in logical pixels) the icon-only phase is offset down from
  // its final resting position. When the controller is at 0 the icon is
  // centered on screen (matching native splash); as it progresses, the
  // icon lifts up into its final position and the text fades in below.
  static const double _iconStartDrop = 80.0;

  late final Animation<double> _iconLift;
  late final Animation<double> _titleFade;
  late final Animation<double> _taglineFade;

  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _iconLift = Tween<double>(begin: _iconStartDrop, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
      ),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.7, curve: Curves.easeIn),
    ));

    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
    ));

    _controller.forward();

    _navTimer = Timer(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    });
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF97316),
      body: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              // Shift the whole column downward at the start so that the
              // icon (the first child) sits where the native splash icon
              // was (screen center). As the controller runs, iconLift
              // decreases to 0 and the column settles into its final
              // centered position — with the text now occupying the
              // bottom half of the column.
              return Transform.translate(
                offset: Offset(0, _iconLift.value),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/icons/wallet_icon.png',
                      width: 110,
                      height: 110,
                    ),
                    const SizedBox(height: 8),
                    Opacity(
                      opacity: _titleFade.value,
                      child: const Text(
                        'SplitSathi',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Opacity(
                      opacity: _taglineFade.value,
                      child: Text(
                        'Split bills. Not friendships. 🤝',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}