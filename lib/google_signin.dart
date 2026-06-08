import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:paradox/services/recent_accounts_service.dart';

class GoogleSignInProvider {
  static Future<void>? _initialized;

  Future<UserCredential?> googleLogin() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      return FirebaseAuth.instance.signInWithPopup(provider);
    }

    final googleSignIn = GoogleSignIn.instance;
    _initialized ??= googleSignIn.initialize(
      serverClientId:
          '1026083375145-bk3fq9ogrhmm3frnovvrcj8nuq04v7v8.apps.googleusercontent.com',
    );
    await _initialized;

    final account = await googleSignIn.authenticate();
    final auth = account.authentication;

    final credential = GoogleAuthProvider.credential(
      idToken: auth.idToken,
    );

    final result = await FirebaseAuth.instance.signInWithCredential(credential);
    final user = result.user;
    if (user != null) {
      await RecentAccountsService.saveCurrentUser(
        user,
        username: user.displayName ?? user.email ?? 'Google user',
        providerId: GoogleAuthProvider.PROVIDER_ID,
      );
    }

    return result;
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      await GoogleSignIn.instance.signOut();
    }
    await FirebaseAuth.instance.signOut();
  }
}