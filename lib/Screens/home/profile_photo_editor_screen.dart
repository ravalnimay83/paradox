import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class ProfilePhotoEditorScreen extends StatefulWidget {
  const ProfilePhotoEditorScreen({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<ProfilePhotoEditorScreen> createState() => _ProfilePhotoEditorScreenState();
}

class _ProfilePhotoEditorScreenState extends State<ProfilePhotoEditorScreen> {
  final TransformationController _controller = TransformationController();
  img.Image? _decodedImage;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _decodedImage = img.decodeImage(widget.imageBytes);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveCroppedImage() async {
    final decodedImage = _decodedImage;
    if (decodedImage == null || _saving) return;

    setState(() => _saving = true);
    try {
      final viewportSize = context.size?.width ?? 320;
      final inverseMatrix = Matrix4.inverted(_controller.value);

      final visibleTopLeft = MatrixUtils.transformPoint(inverseMatrix, const Offset(0, 0));
      final visibleBottomRight = MatrixUtils.transformPoint(
        inverseMatrix,
        Offset(viewportSize, viewportSize),
      );

      final cropLeft = (visibleTopLeft.dx).clamp(0.0, decodedImage.width.toDouble());
      final cropTop = (visibleTopLeft.dy).clamp(0.0, decodedImage.height.toDouble());
      final cropRight = (visibleBottomRight.dx).clamp(0.0, decodedImage.width.toDouble());
      final cropBottom = (visibleBottomRight.dy).clamp(0.0, decodedImage.height.toDouble());

      final left = math.min(cropLeft, cropRight).floor();
      final top = math.min(cropTop, cropBottom).floor();
      final right = math.max(cropLeft, cropRight).ceil();
      final bottom = math.max(cropTop, cropBottom).ceil();

      final width = (right - left).clamp(1, decodedImage.width - left);
      final height = (bottom - top).clamp(1, decodedImage.height - top);

      final cropped = img.copyCrop(
        decodedImage,
        x: left,
        y: top,
        width: width,
        height: height,
      );
      final croppedBytes = Uint8List.fromList(img.encodeJpg(cropped, quality: 92));

      if (!mounted) return;
      Navigator.of(context).pop(croppedBytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not crop that photo. Try a different image.')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final decodedImage = _decodedImage;

    return Scaffold(
      backgroundColor: const Color(0xFF070B10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070B10),
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Edit profile photo'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveCroppedImage,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Done', style: TextStyle(color: Color(0xFF74D3FF), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: decodedImage == null
          ? const Center(
              child: Text('That image could not be opened.', style: TextStyle(color: Colors.white70)),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final viewportSize = math.min(constraints.maxWidth, constraints.maxHeight - 120);
                final scale = math.max(viewportSize / decodedImage.width, viewportSize / decodedImage.height);
                final displayWidth = decodedImage.width * scale;
                final displayHeight = decodedImage.height * scale;

                return Column(
                  children: [
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Drag and zoom until the photo fits inside the circle.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 15, height: 1.35),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Container(
                        width: viewportSize,
                        height: viewportSize,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1722),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: const Color(0xFF263F4B)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              InteractiveViewer(
                                transformationController: _controller,
                                minScale: 1,
                                maxScale: 4,
                                boundaryMargin: EdgeInsets.zero,
                                clipBehavior: Clip.hardEdge,
                                child: Center(
                                  child: SizedBox(
                                    width: displayWidth,
                                    height: displayHeight,
                                    child: Image.memory(widget.imageBytes, fit: BoxFit.fill),
                                  ),
                                ),
                              ),
                              IgnorePointer(
                                child: Center(
                                  child: Container(
                                    width: viewportSize * 0.72,
                                    height: viewportSize * 0.72,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFF74D3FF), width: 2.2),
                                      color: Colors.transparent,
                                    ),
                                  ),
                                ),
                              ),
                              IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.25)],
                                      stops: const [0.68, 1],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.zoom_in_rounded, color: Color(0xFF74D3FF), size: 18),
                          SizedBox(width: 8),
                          Text('Pinch to zoom', style: TextStyle(color: Colors.white70)),
                          SizedBox(width: 18),
                          Icon(Icons.open_with_rounded, color: Color(0xFF84F7C7), size: 18),
                          SizedBox(width: 8),
                          Text('Drag to position', style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}