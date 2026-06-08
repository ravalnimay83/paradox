import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:paradox/services/media_upload_service.dart';
import 'package:paradox/services/recent_accounts_service.dart';

class AccountDeletionService {
  AccountDeletionService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> deleteCurrentAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'You must be signed in to delete your account.',
      );
    }

    final uid = user.uid;
    final userRef = _firestore.collection('users').doc(uid);
    final userDoc = await userRef.get();
    final userData = userDoc.data() ?? <String, dynamic>{};
    final usernameKey = userData['usernameKey'] as String?;

    final postDocs = await _firestore.collection('posts').where('ownerId', isEqualTo: uid).get();
    final userPostRefs = await userRef.collection('posts').get();
    final chatDocs = await _firestore.collection('chats').where('participants', arrayContains: uid).get();

    for (final post in postDocs.docs) {
      final deleteToken = post.data()['mediaDeleteToken'] as String?;
      if (deleteToken != null && deleteToken.isNotEmpty) {
        try {
          await MediaUploadService.deleteUploadedAsset(deleteToken);
        } catch (_) {
          // Best effort only: continue deleting the account even if a cloud asset token expired.
        }
      }
    }

    await _deleteReferencesIndividually(userPostRefs.docs.map((doc) => doc.reference));
    await _deleteReferencesIndividually(postDocs.docs.map((doc) => doc.reference));

    for (final chatDoc in chatDocs.docs) {
      final messageDocs = await chatDoc.reference.collection('messages').get();
      await _deleteReferencesIndividually(messageDocs.docs.map((doc) => doc.reference));
      await _deleteReferenceSafely(chatDoc.reference);
    }

    if (usernameKey != null && usernameKey.isNotEmpty) {
      await _deleteReferenceSafely(_firestore.collection('usernames').doc(usernameKey));
    }

    await _deleteReferenceSafely(userRef);
    await RecentAccountsService.removeAccount(uid);

    try {
      await user.delete();
    } on FirebaseAuthException {
      rethrow;
    }
  }

  static Future<void> _deleteReferencesIndividually(
    Iterable<DocumentReference<Map<String, dynamic>>> references,
  ) async {
    for (final reference in references) {
      await _deleteReferenceSafely(reference);
    }
  }

  static Future<void> _deleteReferenceSafely(DocumentReference<Map<String, dynamic>> reference) async {
    try {
      await reference.delete();
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        // Continue deleting the rest of the account data even if one document is stale or protected.
        return;
      }
      rethrow;
    }
  }
}