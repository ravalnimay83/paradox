import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:paradox/Screens/messages/chat_list_screen.dart';
import 'package:paradox/Screens/login/loginscreen.dart';
import 'package:paradox/Screens/home/create_post.dart';
import 'package:paradox/Screens/home/profile_photo_editor_screen.dart';
import 'package:paradox/Screens/home/post_view_screen.dart';
import 'package:paradox/Screens/home/search_screen.dart';
import 'package:paradox/Screens/home/post_login_splash.dart';
import 'package:paradox/google_signin.dart';
import 'package:paradox/services/app_release_service.dart';
import 'package:paradox/services/account_deletion_service.dart';
import 'package:paradox/services/auth_service.dart';
import 'package:paradox/services/profile_photo_upload_service.dart';
import 'package:paradox/services/recent_accounts_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const Color _background = Color(0xFF070B10);
  static const Color _accent = Color(0xFF74D3FF);
  static const Color _accent2 = Color(0xFF84F7C7);
  static const Color _theme = Color(0xFF263F4B);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _deletingAccount = false;
  bool _updatingProfilePhoto = false;
  Future<PackageInfo>? _packageInfoFuture;

  Future<String> _resolvePostUsername(String ownerId, String fallbackUsername) async {
    final fallback = fallbackUsername.trim();
    if (fallback.isNotEmpty && fallback.toLowerCase() != 'user') {
      return fallback;
    }

    if (ownerId.isEmpty) {
      return fallback.isEmpty ? 'user' : fallback;
    }

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(ownerId).get();
      final data = userDoc.data();
      final resolved = (data?['username'] as String? ?? '').trim();
      return resolved.isEmpty ? (fallback.isEmpty ? 'user' : fallback) : resolved;
    } catch (_) {
      return fallback.isEmpty ? 'user' : fallback;
    }
  }

  Future<bool> _showExitPopup() async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF111111),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: const Text(
              'Leave Paradox?',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'Are you sure wanna leave the app?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('STAY', style: TextStyle(color: Colors.white70)),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF263F4B), Color(0xFF3D6272)],
                  ),
                ),
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text(
                    'EXIT',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _signOut() async {
    final navigator = Navigator.of(context);
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
  }

  Future<void> _confirmDeleteAccount() async {
    if (_deletingAccount) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Delete account?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to delete your account? This will remove your profile, posts, chats, and saved account data.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deletingAccount = true);
    try {
      await AccountDeletionService.deleteCurrentAccount();
      if (!mounted) return;
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Unable to delete account')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Account deletion failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingAccount = false);
      }
    }
  }

  Future<void> _changeProfilePhoto() async {
    if (_updatingProfilePhoto) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _updatingProfilePhoto = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
      if (picked == null) return;
      if (!mounted) return;

      final pickedBytes = await picked.readAsBytes();
      if (!mounted) return;

      final croppedBytes = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(
          builder: (_) => ProfilePhotoEditorScreen(imageBytes: pickedBytes),
        ),
      );

      if (croppedBytes == null) return;

      final storageRef = FirebaseStorage.instance.ref().child('profile_photos/${user.uid}.jpg');
      final uploadSnapshot = await uploadCroppedProfilePhoto(storageRef, croppedBytes);
      final photoUrl = await uploadSnapshot.ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'profilePicUrl': photoUrl,
        'profilePicPath': storageRef.fullPath,
        'profilePicUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await user.updatePhotoURL(photoUrl);
      await user.reload();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update profile photo: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingProfilePhoto = false);
      }
    }
  }

  Future<PackageInfo> _loadPackageInfo() {
    return _packageInfoFuture ??= PackageInfo.fromPlatform();
  }

  Future<void> _openLatestRelease(AppReleaseInfo release) async {
    final uri = Uri.tryParse(release.downloadUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _copyDownloadLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Download link copied')),
    );
  }

  Future<void> _openAccountSwitcher() async {
    final accounts = await RecentAccountsService.loadAccounts();
    if (!mounted) return;

    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved profiles yet. Use Add account first.')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111A25),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 48,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        HomeScreen._theme.withValues(alpha: 0.28),
                        const Color(0xFF111A25),
                      ],
                    ),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [HomeScreen._theme, HomeScreen._accent]),
                        ),
                        child: const CircleAvatar(
                          radius: 22,
                          backgroundColor: Color(0xFF0E1722),
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Switch Profile',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Tap an account to switch or add another one.',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: accounts.length + 1,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index == accounts.length) {
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              _signOut();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F1720),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                children: [
                                  const CircleAvatar(
                                    backgroundColor: Color(0xFF263F4B),
                                    child: Icon(Icons.add_rounded, color: Colors.white),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Add account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                        SizedBox(height: 2),
                                        Text('Sign in with another profile', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      final account = accounts[index];
                      final isCurrent = FirebaseAuth.instance.currentUser?.uid == account.uid;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: isCurrent
                              ? null
                              : () async {
                                  Navigator.of(sheetContext).pop();
                                  await _switchToAccount(account);
                                },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isCurrent ? HomeScreen._theme.withValues(alpha: 0.22) : const Color(0xFF0F1720),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isCurrent ? HomeScreen._accent.withValues(alpha: 0.65) : Colors.white12,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        isCurrent ? HomeScreen._accent : HomeScreen._theme,
                                        HomeScreen._accent2,
                                      ],
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 22,
                                    backgroundColor: const Color(0xFF0E1722),
                                    child: Text(
                                      account.username.isNotEmpty ? account.username.substring(0, 1).toUpperCase() : 'P',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              account.username.isEmpty ? account.email : account.username,
                                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                          if (isCurrent)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.greenAccent.withValues(alpha: 0.18),
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              child: const Text(
                                                'Current',
                                                style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        account.email,
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  isCurrent ? Icons.check_circle_rounded : Icons.swap_horiz_rounded,
                                  color: isCurrent ? Colors.greenAccent : Colors.white54,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _promptPassword(String email) async {
    final passwordController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111111),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text('Confirm password', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: email,
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF1A2431),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(passwordController.text.trim()),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    passwordController.dispose();
    return result;
  }

  Future<void> _switchToAccount(RecentAccount account) async {
    try {
      if (account.isPassword) {
        final password = await _promptPassword(account.email);
        if (password == null || password.isEmpty) {
          return;
        }

        await AuthService.signInWithUsernameOrEmail(identifier: account.email, password: password);
      } else {
        await GoogleSignInProvider().googleLogin();
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PostLoginSplashScreen()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to switch profile: $error')),
      );
    }
  }

  String _formatRelativeTime(int millis) {
    if (millis <= 0) return '';
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(millis));
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await _showExitPopup();
        if (shouldExit && mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: HomeScreen._background,
        body: SafeArea(
          child: IndexedStack(
            index: _currentIndex,
            children: [
              _buildFeed(),
              const SearchScreen(),
              _buildPlaceholder('Add'),
              _buildPlaceholder('Reels'),
              _buildProfileTab(),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF091018),
            border: Border(top: BorderSide(color: Color(0x1FFFFFFF))),
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: HomeScreen._accent,
            unselectedItemColor: Colors.white54,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            currentIndex: _currentIndex,
            onTap: (i) {
              if (i == 2) {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreatePostScreen()));
                return;
              }
              setState(() => _currentIndex = i);
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'Search'),
              BottomNavigationBarItem(icon: Icon(Icons.add_box_outlined), label: 'Add'),
              BottomNavigationBarItem(icon: Icon(Icons.movie_creation_outlined), label: 'Reels'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String title) => Center(
        child: Text(title, style: const TextStyle(color: Colors.white)),
      );

  Widget _buildFeed() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Not signed in', style: TextStyle(color: Colors.white)));
    }

    return Stack(
      children: [
        Positioned(
          top: -150,
          right: -100,
          child: _GlowCircle(color: HomeScreen._accent.withValues(alpha: 0.14), size: 280),
        ),
        Positioned(
          bottom: -180,
          left: -120,
          child: _GlowCircle(color: HomeScreen._accent2.withValues(alpha: 0.10), size: 320),
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF070B10),
                Color(0xFF0A1118),
                Color(0xFF070B10),
              ],
              stops: [0.0, 0.42, 1.0],
            ),
          ),
        ),
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      HomeScreen._theme.withValues(alpha: 0.88),
                      const Color(0xFF101822),
                    ],
                  ),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.30),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [HomeScreen._accent, HomeScreen._accent2],
                        ),
                      ),
                      child: const CircleAvatar(
                        radius: 20,
                        backgroundColor: Color(0xFF223042),
                        backgroundImage: AssetImage('assets/images/appLogo.png'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Paradox',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'A calm feed for the people you follow and discover.',
                            style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.2),
                          ),
                        ],
                      ),
                    ),
                    _IconButton(icon: Icons.favorite_border_rounded, onTap: () {}),
                    const SizedBox(width: 8),
                    _MessageInboxButton(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ChatListScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 118,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final isAdd = index == 0;
                  final isFirst = index == 0;
                  return _StoryBubble(
                    isAdd: isAdd,
                    label: isAdd ? 'Your story' : 'Cosmo $index',
                    color: isFirst ? HomeScreen._theme : (index.isEven ? HomeScreen._accent : HomeScreen._accent2),
                  );
                },
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemCount: 8,
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('posts').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Unable to load feed: ${snapshot.error}', style: const TextStyle(color: Colors.white70)),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final posts = [...(snapshot.data?.docs ?? [])]
                      .where((doc) => doc.data()['ownerId'] != user.uid)
                      .toList()
                    ..sort((a, b) {
                      final am = (a.data()['createdAtMillis'] as num?)?.toInt() ?? 0;
                      final bm = (b.data()['createdAtMillis'] as num?)?.toInt() ?? 0;
                      return bm.compareTo(am);
                    });

                  final randomPosts = [...posts]..shuffle();

                  if (randomPosts.isEmpty) {
                    return Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 22),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: const Color(0xFF111A25),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome_rounded, color: Colors.white70, size: 30),
                            SizedBox(height: 10),
                            Text(
                              'No posts from other users yet',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'As friends post, their stories will appear here in a smooth, calm feed.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(0, 6, 0, 22),
                    itemCount: randomPosts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final data = randomPosts[index].data();
                      final mediaUrl = data['mediaUrl'] as String? ?? '';
                      final mediaType = data['mediaType'] as String? ?? 'image';
                      final caption = data['caption'] as String? ?? '';
                      final ownerUsername = data['ownerUsername'] as String? ?? 'user';
                      final ownerId = data['ownerId'] as String? ?? '';
                      final likes = (data['likesCount'] as num?)?.toInt() ?? 0;
                      final comments = (data['commentsCount'] as num?)?.toInt() ?? 0;
                      final createdAtMillis = (data['createdAtMillis'] as num?)?.toInt() ?? 0;
                      final timeAgo = _formatRelativeTime(createdAtMillis);
                      final cardColor = index.isEven ? HomeScreen._accent : HomeScreen._accent2;

                      return FutureBuilder<String>(
                        future: _resolvePostUsername(ownerId, ownerUsername),
                        builder: (context, usernameSnapshot) {
                          final resolvedUsername = usernameSnapshot.data?.trim().isNotEmpty == true
                              ? usernameSnapshot.data!.trim()
                              : ownerUsername;

                          return _PostCard(
                            username: resolvedUsername,
                            location: 'Paradox Feed',
                            caption: caption.isEmpty ? 'No caption yet.' : caption,
                            likes: likes,
                            comments: comments,
                            timeAgo: timeAgo,
                            imageColor: cardColor,
                            mediaUrl: mediaUrl,
                            mediaType: mediaType,
                            onOpen: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PostViewScreen(
                                    mediaUrl: mediaUrl,
                                    mediaType: mediaType,
                                    caption: caption,
                                    username: resolvedUsername,
                                  ),
                                ),
                              );
                            },
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
      ],
    );
  }

  Widget _buildProfileTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Not signed in'));

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data?.data();
        final username = data?['username'] as String? ?? user.displayName ?? '';
        final email = data?['email'] as String? ?? user.email ?? '';
        final homeType = data?['homeType'] as String? ?? 'default';
        final profilePicUrl = (data?['profilePicUrl'] as String? ?? '').trim();
        final followersCount = (data?['followersCount'] as num?)?.toInt() ?? 0;
        final followingCount = (data?['followingCount'] as num?)?.toInt() ?? 0;

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('posts').where('ownerId', isEqualTo: user.uid).snapshots(),
              builder: (context, postsSnap) {
                if (postsSnap.hasError) {
                  return Text(
                    'Unable to load posts: ${postsSnap.error}',
                    style: const TextStyle(color: Colors.white70),
                  );
                }

                if (postsSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = [...(postsSnap.data?.docs ?? [])]
                  ..sort((a, b) {
                    final am = (a.data()['createdAtMillis'] as num?)?.toInt() ?? 0;
                    final bm = (b.data()['createdAtMillis'] as num?)?.toInt() ?? 0;
                    return bm.compareTo(am);
                  });

                final postsCount = docs.length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: HomeScreen._theme.withValues(alpha: 0.55)),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            HomeScreen._theme.withValues(alpha: 0.34),
                            const Color(0xFF111A25),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [HomeScreen._theme, HomeScreen._accent],
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 36,
                                      backgroundColor: const Color(0xFF0E1722),
                                      backgroundImage: profilePicUrl.isNotEmpty ? NetworkImage(profilePicUrl) : null,
                                      child: profilePicUrl.isEmpty
                                          ? const Icon(Icons.person, color: Colors.white, size: 34)
                                          : null,
                                    ),
                                  ),
                                  Positioned(
                                    right: -2,
                                    bottom: -2,
                                    child: GestureDetector(
                                      onTap: _updatingProfilePhoto ? null : _changeProfilePhoto,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: HomeScreen._theme,
                                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                                        ),
                                        child: _updatingProfilePhoto
                                            ? const SizedBox(
                                                width: 12,
                                                height: 12,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                              )
                                            : const Icon(Icons.edit_rounded, color: Colors.white, size: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            username,
                                            style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        if (_deletingAccount)
                                          const SizedBox(
                                            width: 36,
                                            height: 36,
                                            child: Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          )
                                        else
                                          PopupMenuButton<String>(
                                            icon: const Icon(Icons.menu_rounded, color: Colors.white),
                                            color: const Color(0xFF111A25),
                                            onSelected: (value) {
                                              if (value == 'switch_profile') {
                                                _openAccountSwitcher();
                                              } else if (value == 'add_account') {
                                                _signOut();
                                              } else if (value == 'delete_account') {
                                                _confirmDeleteAccount();
                                              }
                                            },
                                            itemBuilder: (context) => const [
                                              PopupMenuItem<String>(
                                                value: 'switch_profile',
                                                child: Text('Switch profile'),
                                              ),
                                              PopupMenuItem<String>(
                                                value: 'add_account',
                                                child: Text('Add account'),
                                              ),
                                              PopupMenuDivider(),
                                              PopupMenuItem<String>(
                                                value: 'delete_account',
                                                child: Text('Delete account', style: TextStyle(color: Colors.redAccent)),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(email, style: const TextStyle(color: Colors.white70)),
                                    const SizedBox(height: 14),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      children: [
                                        _statColumn('Posts', postsCount.toString()),
                                        const SizedBox(width: 18),
                                        _statColumn('Followers', followersCount.toString()),
                                        const SizedBox(width: 18),
                                        _statColumn('Following', followingCount.toString()),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF101822),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.dashboard_customize_rounded, color: Colors.white70),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('Home Type: $homeType', style: const TextStyle(color: Colors.white70)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    FutureBuilder<PackageInfo>(
                      future: _loadPackageInfo(),
                      builder: (context, packageSnapshot) {
                        final packageInfo = packageSnapshot.data;
                        return StreamBuilder<AppReleaseInfo?>(
                          stream: AppReleaseService.watchAndroidLatest(),
                          builder: (context, releaseSnapshot) {
                            final release = releaseSnapshot.data;
                            final currentVersionCode = int.tryParse(packageInfo?.buildNumber ?? '') ?? 0;
                            final isUpdateAvailable = release != null && release.isNewerThan(currentVersionCode);

                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF101822),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isUpdateAvailable ? HomeScreen._accent.withValues(alpha: 0.55) : Colors.white12,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.ios_share_rounded, color: Colors.white70),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'App link',
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      if (isUpdateAvailable)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: HomeScreen._accent.withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: const Text(
                                            'Update ready',
                                            style: TextStyle(color: HomeScreen._accent, fontSize: 10, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    release == null
                                        ? 'Set a downloadUrl in Firestore to share the latest build with friends.'
                                        : 'Latest: ${release.versionName.isEmpty ? 'unknown' : release.versionName}${release.notes.isEmpty ? '' : ' - ${release.notes}'}',
                                    style: const TextStyle(color: Colors.white70, height: 1.4),
                                  ),
                                  if (packageInfo != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Installed version: ${packageInfo.version} (${packageInfo.buildNumber})',
                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      FilledButton.icon(
                                        onPressed: release == null ? null : () => _openLatestRelease(release),
                                        icon: const Icon(Icons.download_rounded),
                                        label: const Text('Open download link'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: release == null ? null : () => _copyDownloadLink(release.downloadUrl),
                                        icon: const Icon(Icons.copy_rounded),
                                        label: const Text('Copy link'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    const Text('Posts', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (docs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text('No posts yet', style: TextStyle(color: Colors.white70)),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: docs.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                        ),
                        itemBuilder: (context, i) {
                          final d = docs[i].data();
                          final mediaUrl = d['mediaUrl'] as String?;
                          final mediaType = d['mediaType'] as String? ?? 'image';
                          final caption = d['caption'] as String? ?? '';
                          return GestureDetector(
                            onTap: () {
                              if (mediaUrl == null || mediaUrl.isEmpty) return;
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PostViewScreen(
                                    mediaUrl: mediaUrl,
                                    mediaType: mediaType,
                                    caption: caption,
                                    username: username,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF141E2B),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white10),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: mediaUrl == null
                                  ? const Center(child: Icon(Icons.broken_image, color: Colors.white30))
                                  : (mediaType == 'image'
                                      ? Image.network(mediaUrl, fit: BoxFit.cover)
                                      : Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Image.network(mediaUrl, fit: BoxFit.cover),
                                            const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 40)),
                                          ],
                                        )),
                            ),
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _statColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF111A25),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 42,
          width: 42,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _MessageInboxButton extends StatelessWidget {
  const _MessageInboxButton({required this.onTap});

  static const Color _theme = Color(0xFF263F4B);

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      return _IconButton(icon: Icons.send_rounded, onTap: onTap);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: me.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        var unreadTotal = 0;

        for (final doc in docs) {
          final unreadMap = doc.data()['unreadCounts'] as Map<String, dynamic>?;
          unreadTotal += (unreadMap?[me.uid] as num?)?.toInt() ?? 0;
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            _IconButton(icon: Icons.send_rounded, onTap: onTap),
            if (unreadTotal > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: _theme,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF091018), width: 1),
                  ),
                  child: Text(
                    unreadTotal > 99 ? '99+' : '$unreadTotal',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StoryBubble extends StatelessWidget {
  const _StoryBubble({required this.isAdd, required this.label, required this.color});

  final bool isAdd;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [color, Colors.white24]),
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFF111A25),
              child: isAdd
                  ? const Icon(Icons.add, color: Colors.white, size: 28)
                  : Text(
                      label.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.username,
    required this.location,
    required this.caption,
    required this.likes,
    required this.comments,
    required this.timeAgo,
    required this.imageColor,
    required this.mediaUrl,
    required this.mediaType,
    required this.onOpen,
  });

  final String username;
  final String location;
  final String caption;
  final int likes;
  final int comments;
  final String timeAgo;
  final Color imageColor;
  final String mediaUrl;
  final String mediaType;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1720),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.38),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [imageColor, HomeScreen._theme]),
                        ),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: imageColor.withValues(alpha: 0.28),
                          child: const Icon(Icons.person, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(location, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Icon(Icons.more_horiz_rounded, color: Colors.white70, size: 18),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      height: 280,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [imageColor.withValues(alpha: 0.88), const Color(0xFF203245)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (mediaUrl.isNotEmpty)
                            mediaType == 'image'
                                ? Image.network(
                                    mediaUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                  )
                                : Image.network(
                                    mediaUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                  ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                    Colors.black.withValues(alpha: 0.02),
                                    Colors.black.withValues(alpha: 0.32),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                              left: 16,
                              top: 16,
                            child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.24),
                                borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                              ),
                                child: const Text('Feed', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          Positioned(
                              right: 16,
                              bottom: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.24),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                              ),
                                child: Text(timeAgo, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          if (mediaType == 'video')
                            const Center(
                              child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 84),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.favorite_border_rounded, color: Colors.white),
                          const SizedBox(width: 16),
                          const Icon(Icons.mode_comment_outlined, color: Colors.white),
                          const SizedBox(width: 16),
                          const Icon(Icons.send_outlined, color: Colors.white),
                          const Spacer(),
                          const Icon(Icons.bookmark_border_rounded, color: Colors.white),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _MiniStatChip(label: '$likes likes', color: HomeScreen._accent),
                          const SizedBox(width: 8),
                          _MiniStatChip(label: '$comments comments', color: HomeScreen._accent2),
                        ],
                      ),
                      const SizedBox(height: 8),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.white70, height: 1.42),
                          children: [
                            TextSpan(
                              text: '$username ',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                            ),
                            TextSpan(text: caption),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStatChip extends StatelessWidget {
  const _MiniStatChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color.withValues(alpha: 0.95), fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}