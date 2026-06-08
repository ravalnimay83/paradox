import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'home_screen.dart';

class HomeWrapper extends StatelessWidget {
  const HomeWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    final docStream = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final data = snapshot.data?.data();
        final homeType = data?['homeType'] as String? ?? 'default';

        switch (homeType) {
          case 'creator':
            return CreatorHome(data: data);
          case 'business':
            return BusinessHome(data: data);
          case 'moderator':
            return ModeratorHome(data: data);
          default:
            return const HomeScreen();
        }
      },
    );
  }
}

class CreatorHome extends StatelessWidget {
  const CreatorHome({super.key, this.data});
  final Map<String, dynamic>? data;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Creator Home')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black87,
            child: const Text('Creator dashboard', style: TextStyle(color: Colors.white)),
          ),
          const Expanded(child: HomeScreen()),
        ],
      ),
    );
  }
}

class BusinessHome extends StatelessWidget {
  const BusinessHome({super.key, this.data});
  final Map<String, dynamic>? data;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Business Home')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black87,
            child: const Text('Business tools', style: TextStyle(color: Colors.white)),
          ),
          const Expanded(child: HomeScreen()),
        ],
      ),
    );
  }
}

class ModeratorHome extends StatelessWidget {
  const ModeratorHome({super.key, this.data});
  final Map<String, dynamic>? data;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moderator Home')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black87,
            child: const Text('Moderator tools', style: TextStyle(color: Colors.white)),
          ),
          const Expanded(child: HomeScreen()),
        ],
      ),
    );
  }
}
