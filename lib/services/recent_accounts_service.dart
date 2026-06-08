import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecentAccount {
  const RecentAccount({
    required this.uid,
    required this.email,
    required this.username,
    required this.providerId,
  });

  final String uid;
  final String email;
  final String username;
  final String providerId;

  bool get isGoogle => providerId == GoogleAuthProvider.PROVIDER_ID;
  bool get isPassword => providerId == EmailAuthProvider.PROVIDER_ID;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'uid': uid,
        'email': email,
        'username': username,
        'providerId': providerId,
      };

  factory RecentAccount.fromJson(Map<String, dynamic> json) {
    return RecentAccount(
      uid: json['uid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      username: json['username'] as String? ?? '',
      providerId: json['providerId'] as String? ?? EmailAuthProvider.PROVIDER_ID,
    );
  }
}

class RecentAccountsService {
  RecentAccountsService._();

  static const String _storageKey = 'recent_accounts_v1';

  static Future<List<RecentAccount>> loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return <RecentAccount>[];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <RecentAccount>[];
    }

    return decoded
        .whereType<Map>()
        .map((item) => RecentAccount.fromJson(item.map((key, value) => MapEntry(key.toString(), value))) )
        .where((account) => account.uid.isNotEmpty)
        .toList();
  }

  static Future<void> saveCurrentUser(User user, {String? username, String? providerId}) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await loadAccounts();
    final provider = providerId ??
      (user.providerData.isNotEmpty
        ? user.providerData.first.providerId
        : EmailAuthProvider.PROVIDER_ID);
    final email = user.email ?? '';
    final resolvedUsername = (username ?? user.displayName ?? '').trim();

    accounts.removeWhere((account) => account.uid == user.uid);
    accounts.insert(
      0,
      RecentAccount(
        uid: user.uid,
        email: email,
        username: resolvedUsername,
        providerId: provider,
      ),
    );

    final encoded = jsonEncode(accounts.map((account) => account.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  static Future<void> removeAccount(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await loadAccounts();
    accounts.removeWhere((account) => account.uid == uid);
    final encoded = jsonEncode(accounts.map((account) => account.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}