import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:paradox/Screens/messages/chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  static const Color _theme = Color(0xFF263F4B);

  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';

  String _chatIdFor(String myUid, String peerUid) {
    final ids = [myUid, peerUid]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  String _relativeTime(int millis) {
    if (millis <= 0) return '';
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(millis));
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    final weeks = (diff.inDays / 7).floor();
    return '${weeks}w';
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to use messages')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: _theme,
      ),
      backgroundColor: const Color(0xFF070B10),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (value) => setState(() => _search = value.trim().toLowerCase()),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by username',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: _theme.withValues(alpha: 0.35),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('participants', arrayContains: me.uid)
                  .snapshots(),
              builder: (context, chatSnapshot) {
                if (chatSnapshot.hasError) {
                  return Center(
                    child: Text(
                      'Unable to load inbox: ${chatSnapshot.error}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  );
                }

                final chatDocs = chatSnapshot.data?.docs ?? const [];
                final Map<String, Map<String, dynamic>> inboxByPeer = <String, Map<String, dynamic>>{};
                for (final chatDoc in chatDocs) {
                  final data = chatDoc.data();
                  final participants = (data['participants'] as List<dynamic>? ?? const [])
                      .map((e) => e.toString())
                      .toList();
                  if (!participants.contains(me.uid)) continue;

                  final peerUid = participants.firstWhere(
                    (id) => id != me.uid,
                    orElse: () => '',
                  );
                  if (peerUid.isEmpty) continue;

                  final unreadMap = Map<String, dynamic>.from(data['unreadCounts'] as Map<String, dynamic>? ?? {});
                  final unreadCount = (unreadMap[me.uid] as num?)?.toInt() ?? 0;

                  inboxByPeer[peerUid] = {
                    'lastMessage': data['lastMessage'] as String? ?? '',
                    'lastSenderId': data['lastSenderId'] as String? ?? '',
                    'updatedAtMillis': (data['updatedAtMillis'] as num?)?.toInt() ?? 0,
                    'unreadCount': unreadCount,
                  };
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('users').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Unable to load users: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final users = (snapshot.data?.docs ?? [])
                        .where((d) => d.id != me.uid)
                        .where((d) {
                          if (_search.isEmpty) return true;
                          final username = (d.data()['username'] as String? ?? '').toLowerCase();
                          final usernameKey = (d.data()['usernameKey'] as String? ?? '').toLowerCase();
                          return username.contains(_search) || usernameKey.contains(_search);
                        })
                        .toList()
                      ..sort((a, b) {
                        final aMeta = inboxByPeer[a.id];
                        final bMeta = inboxByPeer[b.id];
                        final am = (aMeta?['updatedAtMillis'] as int?) ?? 0;
                        final bm = (bMeta?['updatedAtMillis'] as int?) ?? 0;
                        if (am != bm) return bm.compareTo(am);
                        final an = (a.data()['username'] as String? ?? '').toLowerCase();
                        final bn = (b.data()['username'] as String? ?? '').toLowerCase();
                        return an.compareTo(bn);
                      });

                    if (users.isEmpty) {
                      return Center(
                        child: Text(
                          _search.isEmpty ? 'No users found yet' : 'No users match "${_searchCtrl.text.trim()}"',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
                      itemCount: users.length,
                      itemBuilder: (context, i) {
                        final doc = users[i];
                        final data = doc.data();
                        final username = data['username'] as String? ?? 'user';
                        final email = data['email'] as String? ?? '';

                        final chatMeta = inboxByPeer[doc.id];
                        final unreadCount = (chatMeta?['unreadCount'] as int?) ?? 0;
                        final fallbackUpdatedAtMillis = (chatMeta?['updatedAtMillis'] as int?) ?? 0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('chats')
                                .doc(_chatIdFor(me.uid, doc.id))
                                .collection('messages')
                                .orderBy('createdAtMillis', descending: true)
                                .limit(20)
                                .snapshots(),
                            builder: (context, msgSnap) {
                              final previewDocs = msgSnap.data?.docs ?? const [];

                              Map<String, dynamic>? latestVisible;
                              for (final m in previewDocs) {
                                final data = m.data();
                                final hiddenFor =
                                    (data['hiddenFor'] as List<dynamic>? ?? const []).map((e) => e.toString());
                                if (!hiddenFor.contains(me.uid)) {
                                  latestVisible = data;
                                  break;
                                }
                              }

                              final previewSenderId = latestVisible?['senderId'] as String? ?? '';
                              final previewText = latestVisible?['text'] as String? ?? '';
                              final previewMillis = (latestVisible?['createdAtMillis'] as num?)?.toInt() ?? fallbackUpdatedAtMillis;
                              final hasUnreadFromPeer = unreadCount > 0 && previewSenderId == doc.id;

                              final subtitleText = hasUnreadFromPeer
                                  ? (previewText.isEmpty ? 'New message' : 'New message: $previewText')
                                  : (previewText.isNotEmpty ? previewText : email);
                              final timeText = _relativeTime(previewMillis);

                              return Material(
                                color: Colors.transparent,
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        _theme.withValues(alpha: hasUnreadFromPeer ? 0.58 : 0.38),
                                        const Color(0xFF111A25),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: hasUnreadFromPeer ? _theme.withValues(alpha: 0.95) : Colors.white10,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.25),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ChatScreen(
                                            peerUid: doc.id,
                                            peerName: username,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundColor: hasUnreadFromPeer ? _theme : const Color(0xFF223042),
                                            child: const Icon(Icons.person, color: Colors.white),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  username,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 15,
                                                    fontWeight: hasUnreadFromPeer ? FontWeight.w700 : FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  subtitleText,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: hasUnreadFromPeer ? Colors.white : Colors.white70,
                                                    fontWeight: hasUnreadFromPeer ? FontWeight.w600 : FontWeight.w400,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              if (timeText.isNotEmpty)
                                                Text(
                                                  timeText,
                                                  style: TextStyle(
                                                    color: hasUnreadFromPeer ? Colors.white : Colors.white54,
                                                    fontSize: 11,
                                                    fontWeight: hasUnreadFromPeer ? FontWeight.w700 : FontWeight.w500,
                                                  ),
                                                ),
                                              const SizedBox(height: 6),
                                              unreadCount > 0
                                                  ? Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: _theme,
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Text(
                                                        unreadCount > 99 ? '99+' : '$unreadCount',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    )
                                                  : const Icon(Icons.chevron_right, color: Colors.white38),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
