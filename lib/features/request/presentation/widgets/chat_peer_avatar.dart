import 'package:flutter/material.dart';

import 'package:fixleo/app/theme/app_colors.dart';

/// Shared peer avatar for the chats list, chat header and incoming bubbles.
///
/// Backend avatar URLs may redirect to short-lived object-storage links.
/// [Image.network] follows that redirect; a missing/deleted object falls back
/// to the person icon instead of leaving a broken-image frame.
class ChatPeerAvatar extends StatelessWidget {
  const ChatPeerAvatar({
    super.key,
    required this.imageUrl,
    this.size = 50,
    this.name,
  });

  final String? imageUrl;
  final double size;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final fallback = _fallback();
    if (url == null || url.isEmpty) return fallback;

    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) return child;
            return fallback;
          },
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }

  Widget _fallback() => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: Color(0xFFE6F1FF),
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: name?.trim().isNotEmpty == true
        ? Text(
            name!
                .trim()
                .split(RegExp(r'\s+'))
                .take(2)
                .map((word) => word.characters.first)
                .join()
                .toUpperCase(),
            style: TextStyle(
              fontSize: size * .32,
              fontWeight: FontWeight.w700,
              color: AppColors.blue,
            ),
          )
        : Icon(
            Icons.person_outline,
            size: size * 0.54,
            color: const Color(0xFF8D96A4),
          ),
  );
}
