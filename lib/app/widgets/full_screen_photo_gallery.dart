import 'package:fixleo/app/widgets/glass/glass.dart';
import 'dart:io';

import 'package:flutter/material.dart';

/// Opens a full-screen, swipeable gallery over [photos], starting at
/// [initialIndex] — pinch-to-zoom per photo, left/right swipe between
/// photos, over a black background with a close button. [photos] are
/// network URLs by default; pass [isLocalFile] true to show local files
/// instead (e.g. photos attached to a request not yet submitted/uploaded).
void showFullScreenPhotoGallery(
  BuildContext context, {
  required List<String> photos,
  int initialIndex = 0,
  bool isLocalFile = false,
}) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: true,
      pageBuilder: (_, _, _) => _FullScreenPhotoGallery(
        photos: photos,
        initialIndex: initialIndex,
        isLocalFile: isLocalFile,
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _FullScreenPhotoGallery extends StatefulWidget {
  const _FullScreenPhotoGallery({
    required this.photos,
    required this.initialIndex,
    required this.isLocalFile,
  });

  final List<String> photos;
  final int initialIndex;
  final bool isLocalFile;

  @override
  State<_FullScreenPhotoGallery> createState() =>
      _FullScreenPhotoGalleryState();
}

class _FullScreenPhotoGalleryState extends State<_FullScreenPhotoGallery> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        // The close button/counter chip below aren't Positioned, and a
        // Stack sizes itself to its non-positioned children — without
        // `expand`, the Stack (and therefore the Positioned.fill photo
        // viewer) collapsed to the header row's height instead of filling
        // the screen.
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) {
              final size = MediaQuery.sizeOf(context);
              final photo = widget.isLocalFile
                  ? Image.file(
                      File(widget.photos[i]),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 64,
                      ),
                    )
                  : Image.network(
                      widget.photos[i],
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 64,
                      ),
                    );
              return GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: photo,
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  LiquidMaterial(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  if (widget.photos.length > 1)
                    LiquidSurface(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_index + 1} / ${widget.photos.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
