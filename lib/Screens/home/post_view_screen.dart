import 'package:flutter/material.dart';

class PostViewScreen extends StatelessWidget {
  const PostViewScreen({
    super.key,
    required this.mediaUrl,
    required this.mediaType,
    required this.caption,
    required this.username,
  });

  final String mediaUrl;
  final String mediaType;
  final String caption;
  final String username;

  @override
  Widget build(BuildContext context) {
    const theme = Color(0xFF263F4B);

    return Scaffold(
      backgroundColor: const Color(0xFF070B10),
      appBar: AppBar(
        title: Text(username),
        backgroundColor: theme,
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: theme.withValues(alpha: 0.7)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.withValues(alpha: 0.35),
                      const Color(0xFF121C27),
                    ],
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: mediaType == 'image'
                    ? Image.network(
                        mediaUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(Icons.broken_image_outlined, color: Colors.white38, size: 46),
                        ),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            mediaUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Icon(Icons.broken_image_outlined, color: Colors.white38, size: 46),
                            ),
                          ),
                          Container(color: Colors.black38),
                          const Center(
                            child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 82),
                          ),
                        ],
                      ),
              ),
            ),
            if (caption.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF111A25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  caption,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
