import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:paradox/Screens/home/home_wrapper.dart';
import 'package:paradox/Screens/login/loginscreen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Color _theme = Color(0xFF263F4B);

  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 9), () {
      if (!mounted) return;
      final nextScreen = FirebaseAuth.instance.currentUser == null ? const LoginScreen() : const HomeWrapper();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => nextScreen));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 150,
                  width: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _theme.withValues(alpha: 0.18),
                        blurRadius: 35,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/appLogo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 40),
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      _theme.withValues(alpha: 0.55),
                      _theme.withValues(alpha: 0.95),
                    ],
                  ).createShader(bounds),
                  child: const Text(
                    'PARADOX',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 10,
                      fontFamily: 'Orbitron',
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'SCIENCE • SPACE • FUTURE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 5,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 50),
                SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(_theme),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '© Paradox',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Developed by NMY',
                      style: TextStyle(
                        color: _theme.withValues(alpha: 0.92),
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        ),
    );
  }
}