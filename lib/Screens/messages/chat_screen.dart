import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.peerUid,
    required this.peerName,
  });

  final String peerUid;
  final String peerName;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _sending = false;
  bool _chatReady = false;
  String? _chatInitError;
  bool _markingRead = false;
  bool _deletingChat = false;

  String get _myUid => FirebaseAuth.instance.currentUser!.uid;
  String get _peerUid => widget.peerUid;

  String get _chatId {
    final ids = [_myUid, widget.peerUid]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  @override
  void initState() {
    super.initState();
    _ensureChatExists();
  }

  Future<void> _ensureChatExists() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await FirebaseFirestore.instance.collection('chats').doc(_chatId).set({
        'participants': [_myUid, widget.peerUid],
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedAtMillis': now,
        'unreadCounts': {
          _myUid: 0,
          _peerUid: 0,
        },
      }, SetOptions(merge: true));
      await _markAsRead();
      if (!mounted) return;
      setState(() {
        _chatReady = true;
        _chatInitError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chatReady = false;
        _chatInitError = e.toString();
      });
    }
  }

  Future<void> _send() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _sending || _deletingChat) return;

    final preserveOffset = _scrollCtrl.hasClients ? _scrollCtrl.offset : null;
    setState(() => _sending = true);

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(_chatId);
      final msgRef = chatRef.collection('messages').doc();

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final chatSnap = await transaction.get(chatRef);
        final current = chatSnap.data() ?? <String, dynamic>{};
        final unread = Map<String, dynamic>.from(current['unreadCounts'] as Map<String, dynamic>? ?? {});
        final peerCurrent = (unread[_peerUid] as num?)?.toInt() ?? 0;

        unread[_peerUid] = peerCurrent + 1;
        unread[_myUid] = 0;

        transaction.set(chatRef, {
          'participants': [_myUid, _peerUid],
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedAtMillis': now,
          'lastMessage': text,
          'lastSenderId': _myUid,
          'unreadCounts': unread,
        }, SetOptions(merge: true));

        transaction.set(msgRef, {
          'senderId': _myUid,
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
          'createdAtMillis': now,
          'hiddenFor': <String>[],
        });
      });

      _messageCtrl.clear();
      await _markAsRead();
      if (mounted && preserveOffset != null && _scrollCtrl.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollCtrl.hasClients) return;
          final maxScroll = _scrollCtrl.position.maxScrollExtent;
          final target = preserveOffset.clamp(0.0, maxScroll);
          _scrollCtrl.jumpTo(target);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    if (_markingRead) return;
    _markingRead = true;
    try {
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(_chatId);
      await chatRef.set({
        'participants': [_myUid, _peerUid],
        'unreadCounts': {_myUid: 0},
      }, SetOptions(merge: true));
    } catch (_) {
      // Ignore read-reset failures; chat still works.
    } finally {
      _markingRead = false;
    }
  }

  Future<void> _deleteForMe(DocumentSnapshot<Map<String, dynamic>> messageDoc) async {
    try {
      await messageDoc.reference.set({
        'hiddenFor': FieldValue.arrayUnion([_myUid]),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message deleted for you')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete for you: $e')),
      );
    }
  }

  Future<void> _deleteForEveryone(DocumentSnapshot<Map<String, dynamic>> messageDoc) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete for everyone?'),
          content: const Text('This will permanently remove this message for both users.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
          ],
        );
      },
    );

    if (result != true) return;

    try {
      await messageDoc.reference.delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message deleted for everyone')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete for everyone: $e')),
      );
    }
  }

  Future<void> _showDeleteOptions(
    DocumentSnapshot<Map<String, dynamic>> messageDoc,
    bool mine,
  ) async {
    if (_deletingChat) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111A25),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_off_rounded, color: Colors.white70),
                title: const Text('Delete for me', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(context).pop();
                  _deleteForMe(messageDoc);
                },
              ),
              if (mine)
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                  title: const Text('Delete for everyone', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.of(context).pop();
                    _deleteForEveryone(messageDoc);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.close_rounded, color: Colors.white54),
                title: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteChat() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete entire chat?'),
          content: const Text('All messages in this conversation will be deleted for both users.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete chat')),
          ],
        );
      },
    );

    if (result != true) return;
    await _deleteEntireChat();
  }

  Future<void> _deleteEntireChat() async {
    if (_deletingChat) return;
    setState(() => _deletingChat = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final chatRef = firestore.collection('chats').doc(_chatId);

      const batchSize = 400;
      while (true) {
        final page = await chatRef.collection('messages').limit(batchSize).get();
        if (page.docs.isEmpty) break;

        final batch = firestore.batch();
        for (final doc in page.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        if (page.docs.length < batchSize) break;
      }

      await chatRef.delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat deleted')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _deletingChat = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete chat: $e')),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF070B10),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF070B10),
              Color(0xFF0A1017),
              Color(0xFF070B10),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.05),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF263F4B),
                      ),
                      child: CircleAvatar(
                        radius: 19,
                        backgroundColor: const Color(0xFF111A25),
                        child: Text(
                          widget.peerName.isNotEmpty ? widget.peerName.substring(0, 1).toUpperCase() : 'P',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.peerName,
                            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (_deletingChat)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    else
                      PopupMenuButton<String>(
                        color: const Color(0xFF111A25),
                        icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
                        onSelected: (value) {
                          if (value == 'delete_chat') {
                            _confirmDeleteChat();
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem<String>(
                            value: 'delete_chat',
                            child: Text('Delete chat', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Expanded(
                child: !_chatReady
                    ? Center(
                        child: _chatInitError == null
                            ? const CircularProgressIndicator()
                            : Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  'Unable to open chat: $_chatInitError',
                                  style: const TextStyle(color: Colors.white70),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                      )
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance.collection('chats').doc(_chatId).collection('messages').snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Unable to load messages: ${snapshot.error}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            );
                          }
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          _markAsRead();

                          final messages = [...(snapshot.data?.docs ?? [])]
                              .where((doc) {
                                final hiddenFor = (doc.data()['hiddenFor'] as List<dynamic>? ?? const []).map((e) => e.toString());
                                return !hiddenFor.contains(_myUid);
                              })
                              .toList()
                            ..sort((a, b) {
                              final am = (a.data()['createdAtMillis'] as num?)?.toInt() ?? 0;
                              final bm = (b.data()['createdAtMillis'] as num?)?.toInt() ?? 0;
                              return am.compareTo(bm);
                            });

                          if (messages.isEmpty) {
                            return const Center(child: _EmptyChatState());
                          }

                          return ListView.builder(
                            controller: _scrollCtrl,
                            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                            itemCount: messages.length,
                            itemBuilder: (context, i) {
                              final messageDoc = messages[i];
                              final msg = messageDoc.data();
                              final mine = msg['senderId'] == _myUid;
                              final text = msg['text'] as String? ?? '';

                              return Align(
                                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                                child: GestureDetector(
                                  onLongPress: () => _showDeleteOptions(messageDoc, mine),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                                      child: _ChatBubble(
                                        text: text,
                                        mine: mine,
                                        themeColor: const Color(0xFF263F4B),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111A25),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageCtrl,
                            style: const TextStyle(color: Colors.white),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(
                              hintText: 'Message',
                              hintStyle: const TextStyle(color: Colors.white54),
                              filled: true,
                              fillColor: const Color(0xFF0E151F),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          height: 46,
                          width: 46,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF263F4B),
                          ),
                          child: IconButton(
                            onPressed: _sending ? null : _send,
                              icon: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: _sending
                                    ? const SizedBox(
                                        key: ValueKey('sending'),
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(
                                        Icons.send_rounded,
                                        key: ValueKey('send'),
                                        color: Colors.white,
                                      ),
                              ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.text, required this.mine, required this.themeColor});

  final String text;
  final bool mine;
  final Color themeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: mine ? themeColor : const Color(0xFF121A24),
        border: Border.all(
          color: mine ? Colors.white.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          height: 1.35,
        ),
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF111A25),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white70, size: 26),
        ),
        const SizedBox(height: 12),
        const Text(
          'Start your conversation',
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Messages will appear here in a clean, simple layout.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 12, height: 1.4),
        ),
      ],
    );
  }
}
