import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:paradox/services/media_upload_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  static const Color _theme = Color(0xFF263F4B);

  XFile? _picked;
  String _mediaType = 'image';
  final _captionCtrl = TextEditingController();
  bool _uploading = false;
  double _progress = 0.0;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() {
      _picked = picked;
      _mediaType = 'image';
    });
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() {
      _picked = picked;
      _mediaType = 'video';
    });
  }

  Future<void> _testUpload() async {
    if (!MediaUploadService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cloudinary not configured.'),
        ),
      );
      return;
    }

    if (_picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick an image/video first for test upload')),
      );
      return;
    }

    try {
      final file = File(_picked!.path);
      final mediaType = _mediaType == 'video' ? 'video' : 'image';
      final url = await MediaUploadService.uploadFile(file: file, mediaType: mediaType);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test upload success: $url')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test upload failed: $e')),
      );
    }
  }

  Future<void> _upload() async {
    if (_picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image/video first')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in before uploading')),
      );
      return;
    }

    if (!MediaUploadService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cloudinary is not configured.'),
        ),
      );
      return;
    }

    setState(() {
      _uploading = true;
      _progress = 0.2;
    });

    try {
      final file = File(_picked!.path);
      final mediaType = _mediaType == 'video' ? 'video' : 'image';
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? <String, dynamic>{};
      final ownerUsername = (userData['username'] as String? ?? user.displayName ?? 'user').trim();
      final ownerEmail = (userData['email'] as String? ?? user.email ?? '').trim();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading media to free storage...')),
        );
      }

      final uploadedMedia = await MediaUploadService.uploadFile(file: file, mediaType: mediaType);
      final mediaUrl = uploadedMedia.secureUrl;
      setState(() => _progress = 0.8);

      final postDoc = FirebaseFirestore.instance.collection('posts').doc();
        await postDoc.set({
          'ownerId': user.uid,
            'ownerUsername': ownerUsername,
            'ownerEmail': ownerEmail,
          'mediaUrl': mediaUrl,
          'mediaPublicId': uploadedMedia.publicId,
          'mediaDeleteToken': uploadedMedia.deleteToken,
          'mediaType': mediaType,
          'caption': _captionCtrl.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'createdAtMillis': DateTime.now().millisecondsSinceEpoch,
            'likesCount': 0,
            'commentsCount': 0,
        });

        // Also write a lightweight reference under users/{uid}/posts for fast profile queries.
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('posts')
              .doc(postDoc.id)
              .set({
            'postId': postDoc.id,
            'createdAt': FieldValue.serverTimestamp(),
            'createdAtMillis': DateTime.now().millisecondsSinceEpoch,
                'ownerUsername': ownerUsername,
          });
        } catch (_) {
          // ignore permission issues if rules are not published yet
        }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post uploaded successfully')),
      );
      Navigator.of(context).pop();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      if (e.code == 'permission-denied') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload blocked by Firestore rules. Publish firestore rules to allow signed-in writes to posts.'),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _progress = 0.0;
        });
      }
    }
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share a moment'),
        backgroundColor: _theme,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: const [
                Icon(Icons.auto_awesome_rounded, color: Colors.white70, size: 16),
                SizedBox(width: 8),
                Text(
                  'Build a post for the feed',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: const Color(0xFF070B10),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - MediaQuery.of(context).padding.vertical - 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111A25),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _theme,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _uploading ? null : _pickImage,
                            icon: const Icon(Icons.photo),
                            label: const Text('Photos'),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _theme,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _uploading ? null : _pickVideo,
                            icon: const Icon(Icons.videocam),
                            label: const Text('Clips'),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: _theme),
                            ),
                            onPressed: _uploading ? null : _testUpload,
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: const Text('Preview Upload'),
                          ),
                        ],
                      ),
                    ),
                    if (_uploading) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progress == 0 ? null : _progress,
                          backgroundColor: Colors.white10,
                          color: _theme,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${(_progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (_picked != null)
                      Container(
                        height: 320,
                        decoration: BoxDecoration(
                          color: const Color(0xFF111A25),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _mediaType == 'image'
                                ? Image.file(File(_picked!.path), fit: BoxFit.contain)
                                : const Center(
                                    child: Icon(Icons.play_circle_fill, size: 80, color: Colors.white70),
                                  ),
                            Positioned(
                              left: 12,
                              top: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _theme.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _mediaType == 'image' ? 'Photo ready' : 'Clip ready',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _captionCtrl,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Write a caption...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF111A25),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _theme),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _theme.withValues(alpha: 0.7)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _theme, width: 1.3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _theme,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _uploading ? null : _upload,
                      child: _uploading ? const CircularProgressIndicator() : const Text('Upload'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
