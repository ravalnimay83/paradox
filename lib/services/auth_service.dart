import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paradox/services/recent_accounts_service.dart';

class AuthService {
  AuthService._();

  static const int minPasswordLength = 6;

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String normalizeUsername(String username) {
    return username.trim().toLowerCase();
  }

  static String normalizeEmail(String email) {
    return email.trim().toLowerCase();
  }

  static bool looksLikeEmail(String value) {
    return value.contains('@');
  }

  static bool isValidPassword(String password) {
    return password.trim().length >= minPasswordLength;
  }

  static Future<T> _retryOnUnavailable<T>(
    Future<T> Function() action, {
    int attempts = 3,
  }) async {
    var delay = const Duration(milliseconds: 300);

    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        return await action();
      } on FirebaseException catch (error) {
        if (error.code != 'unavailable' || attempt == attempts) {
          rethrow;
        }

        await Future<void>.delayed(delay);
        delay *= 2;
      }
    }

    throw StateError('Retry loop finished without returning a result.');
  }

  static Future<String> _getEmailFromUsername(String username) async {
    final usernameKey = normalizeUsername(username);
    final usernameDoc = await _retryOnUnavailable(() {
      return _firestore.collection('usernames').doc(usernameKey).get();
    });
    if (!usernameDoc.exists) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No account found for that username.',
      );
    }

    final data = usernameDoc.data();
    final email = data?['email'] as String?;
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No account found for that username.',
      );
    }

    return email;
  }

  static Future<void> _reserveUsername({
    required String uid,
    required String username,
    required String email,
    required String provider,
  }) async {
    final usernameKey = normalizeUsername(username);
    final emailKey = normalizeEmail(email);
    final usernameRef = _firestore.collection('usernames').doc(usernameKey);
    final userRef = _firestore.collection('users').doc(uid);

    await _retryOnUnavailable(() async {
      final userSnapshot = await userRef.get();
      final existingUserData = userSnapshot.data();
      final existingUsernameKey = existingUserData?['usernameKey'] as String?;

      if (existingUsernameKey != null && existingUsernameKey.isNotEmpty) {
        if (existingUsernameKey == usernameKey) {
          return;
        }

        throw FirebaseAuthException(
          code: 'username-already-set',
          message: 'This account already has a username.',
        );
      }

      // Ensure the username is not already taken by another user
      final usernameSnapshot = await usernameRef.get();
      if (usernameSnapshot.exists) {
        final takenUid = usernameSnapshot.data()?['uid'] as String?;
        if (takenUid != uid) {
          throw FirebaseAuthException(
            code: 'username-already-in-use',
            message: 'That username is already taken.',
          );
        }
        // If the existing mapping is for the same uid, allow idempotent write
      }

      await usernameRef.set(<String, dynamic>{
        'uid': uid,
        'username': username,
        'usernameKey': usernameKey,
        'email': emailKey,
        'provider': provider,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await userRef.set(<String, dynamic>{
        'uid': uid,
        'username': username,
        'usernameKey': usernameKey,
        'email': emailKey,
        'provider': provider,
        'homeType': existingUserData?['homeType'] ?? 'default',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  static Future<UserCredential> signUpWithEmailAndUsername({
    required String username,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = normalizeEmail(email);
    final normalizedUsername = username.trim();

    final credential = await _auth.createUserWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Unable to create the account.',
      );
    }

    try {
      await user.updateDisplayName(normalizedUsername);
      await _reserveUsername(
        uid: user.uid,
        username: normalizedUsername,
        email: normalizedEmail,
        provider: 'password',
      );
      await RecentAccountsService.saveCurrentUser(
        user,
        username: normalizedUsername,
        providerId: EmailAuthProvider.PROVIDER_ID,
      );
      await user.reload();
      return credential;
    } catch (error) {
      await _safeDeleteCurrentUser();
      rethrow;
    }
  }

  static Future<UserCredential> signInWithUsernameOrEmail({
    required String identifier,
    required String password,
  }) async {
    final email = looksLikeEmail(identifier)
        ? normalizeEmail(identifier)
        : await _getEmailFromUsername(identifier);

    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    ).then((credential) async {
      final user = credential.user;
      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        final data = userDoc.data() ?? <String, dynamic>{};
        await RecentAccountsService.saveCurrentUser(
          user,
          username: data['username'] as String? ?? user.displayName ?? identifier,
          providerId: EmailAuthProvider.PROVIDER_ID,
        );
      }
      return credential;
    });
  }

  static Future<void> completeGoogleSignup({
    required String username,
    required String password,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in Google account was found.',
      );
    }

    final email = currentUser.email;
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'Google account does not have an email address.',
      );
    }

    final providerIds = currentUser.providerData.map((provider) => provider.providerId).toList();
    final isAlreadyEmailLinked = providerIds.contains(EmailAuthProvider.PROVIDER_ID);

    try {
      if (!isAlreadyEmailLinked) {
        final emailCredential = EmailAuthProvider.credential(
          email: email,
          password: password,
        );
        await currentUser.linkWithCredential(emailCredential);
      }

      await currentUser.updateDisplayName(username.trim());
      await _reserveUsername(
        uid: currentUser.uid,
        username: username.trim(),
        email: email,
        provider: 'google',
      );
      await RecentAccountsService.saveCurrentUser(
        currentUser,
        username: username.trim(),
        providerId: GoogleAuthProvider.PROVIDER_ID,
      );
      await currentUser.reload();
    } catch (_) {
      rethrow;
    }
  }

  static Future<void> _safeDeleteCurrentUser() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return;
    }

    try {
      await currentUser.delete();
    } catch (_) {
      // Ignore cleanup failures so the original error can surface.
    }
  }
}
