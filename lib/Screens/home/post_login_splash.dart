import 'dart:async';

import 'package:flutter/material.dart';
import 'package:paradox/Screens/home/home_wrapper.dart';

class PostLoginSplashScreen extends StatefulWidget {
  const PostLoginSplashScreen({super.key});

  @override
  State<PostLoginSplashScreen> createState() => _PostLoginSplashScreenState();
}

class _PostLoginSplashScreenState extends State<PostLoginSplashScreen>
  {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const HomeWrapper(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic), child: child),
          transitionDuration: const Duration(seconds: 5),
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: Image.asset(
          'assets/images/signupBG.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}