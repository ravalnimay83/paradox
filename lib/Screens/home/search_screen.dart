import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:paradox/Screens/messages/chat_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const Color _theme = Color(0xFF263F4B);

  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';
  bool _hasSearched = false;

  void _submitSearch() {
    setState(() {
      _search = _searchCtrl.text.trim().toLowerCase();
      _hasSearched = true;
    });
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
      return const Center(child: Text('Please sign in to search', style: TextStyle(color: Colors.white70)));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF070B10),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1A2431),
                      _theme.withValues(alpha: 0.22),
                    ],
                  ),
                  border: Border.all(color: Colors.white12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onSubmitted: (_) => _submitSearch(),
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Press Enter to search all available users',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
                    suffixIcon: IconButton(
                      onPressed: () {
                        if (_searchCtrl.text.isEmpty) {
                          _submitSearch();
                        } else {
                          setState(() {
                            _searchCtrl.clear();
                            _search = '';
                            _hasSearched = false;
                          });
                        }
                      },
                      icon: Icon(_searchCtrl.text.isEmpty ? Icons.keyboard_return_rounded : Icons.close_rounded, color: Colors.white70),
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: _theme.withValues(alpha: 0.45)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: Colors.transparent),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: _theme, width: 1.2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.26),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset('assets/images/searchFeed.png', fit: BoxFit.cover),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.18),
                              Colors.black.withValues(alpha: 0.48),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.travel_explore_rounded, color: Colors.white70, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _hasSearched
                                        ? (_search.isEmpty
                                            ? 'Showing all available users'
                                            : 'Search results for "${_searchCtrl.text.trim()}"')
                                        : 'Discover people in Paradox',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            if (!_hasSearched)
                              const _SearchPromptCard()
                            else
                              Expanded(
                                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                  stream: FirebaseFirestore.instance.collection('users').snapshots(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasError) {
                                      return Center(
                                        child: Text(
                                          'Unable to load users: ${snapshot.error}',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(color: Colors.white70),
                                        ),
                                      );
                                    }

                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(child: CircularProgressIndicator());
                                    }

                                    final users = (snapshot.data?.docs ?? [])
                                        .where((doc) => doc.id != me.uid)
                                        .where((doc) {
                                          if (_search.isEmpty) return true;
                                          final data = doc.data();
                                          final username = (data['username'] as String? ?? '').toLowerCase();
                                          final usernameKey = (data['usernameKey'] as String? ?? '').toLowerCase();
                                          final email = (data['email'] as String? ?? '').toLowerCase();
                                          return username.contains(_search) || usernameKey.contains(_search) || email.contains(_search);
                                        })
                                        .toList();

                                    if (users.isEmpty) {
                                      return Center(
                                        child: Text(
                                          'No users match "${_searchCtrl.text.trim()}"',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(color: Colors.white70),
                                        ),
                                      );
                                    }

                                    return ListView.separated(
                                      padding: const EdgeInsets.only(top: 4, bottom: 2),
                                      itemCount: users.length,
                                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                                      itemBuilder: (context, index) {
                                        final doc = users[index];
                                        final data = doc.data();
                                        final username = data['username'] as String? ?? 'user';
                                        final email = data['email'] as String? ?? '';

                                        return Material(
                                          color: Colors.transparent,
                                          child: Ink(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF111A25).withValues(alpha: 0.84),
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: Colors.white12),
                                            ),
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(16),
                                              onTap: () {
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) => ChatScreen(peerUid: doc.id, peerName: username),
                                                  ),
                                                );
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.all(12),
                                                child: Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 24,
                                                      backgroundColor: _theme.withValues(alpha: 0.8),
                                                      child: const Icon(Icons.person, color: Colors.white),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            username,
                                                            style: const TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 15,
                                                              fontWeight: FontWeight.w700,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 3),
                                                          Text(
                                                            email.isEmpty ? 'Tap to open chat' : email,
                                                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                                                  ],
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
                          ],
                        ),
                      ),
                    ],
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

class _SearchPromptCard extends StatelessWidget {
  const _SearchPromptCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Search people by username',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(
            'Press Enter to search all available users, or type a name to filter.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}