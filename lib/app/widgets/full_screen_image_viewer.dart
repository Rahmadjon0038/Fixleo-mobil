import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:flutter/material.dart';

/// Opens a full-screen, pinch-to-zoom viewer for a network image (avatar,
/// photo, etc.) over a black background with a close button. When [title]
/// is given (e.g. a chat peer's name), it's shown with [subtitle] (e.g.
/// online/last-seen status) in a caption over the bottom of the image.
void showFullScreenImage(
  BuildContext context,
  String imageUrl, {
  String? title,
  String? subtitle,
}) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: true,
      pageBuilder: (_, _, _) => _FullScreenImageViewer(
        imageUrl: imageUrl,
        title: title,
        subtitle: subtitle,
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _FullScreenImageViewer extends StatelessWidget {
  const _FullScreenImageViewer({
    required this.imageUrl,
    this.title,
    this.subtitle,
  });

  final String imageUrl;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        // The close button/caption below aren't Positioned, and a Stack
        // sizes itself to its non-positioned children — without `expand`,
        // the Stack (and therefore the image) collapsed to their height
        // instead of filling the screen.
        fit: StackFit.expand,
        children: [
          Builder(
            builder: (context) {
              // MediaQuery gives the real device viewport directly,
              // sidestepping whatever constraints actually reach this point
              // in the tree — InteractiveViewer gives its child UNBOUNDED
              // constraints, so an Image with no explicit size rendered
              // straight inside it sizes to its own native pixel dimensions
              // instead of filling the screen.
              final size = MediaQuery.sizeOf(context);
              return GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 64,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.topLeft,
                child: LiquidMaterial(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            ),
          ),
          if (title != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: LiquidSurface(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
