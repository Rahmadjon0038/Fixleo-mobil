import 'package:flutter/material.dart';

import 'package:fixleo/app/theme/app_colors.dart';

/// iOS-style "attach photos" sheet — the gallery picker that slides up from the
/// chat input when the camera button is tapped. Grabber, a "Recents" title with
/// a close button, and a 3-column photo grid with a tall camera tile in the
/// top-left. Photos are selectable (design-only mock).
Future<void> showAttachPhotosSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x33000000),
    builder: (_) => const _AttachPhotosSheet(),
  );
}

class _AttachPhotosSheet extends StatefulWidget {
  const _AttachPhotosSheet();

  @override
  State<_AttachPhotosSheet> createState() => _AttachPhotosSheetState();
}

class _AttachPhotosSheetState extends State<_AttachPhotosSheet> {
  // Total mock photos in the grid (excluding the camera tile).
  static const _photoCount = 22;

  final _selected = <int>{};

  void _toggle(int i) {
    setState(() {
      if (!_selected.remove(i)) _selected.add(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(38)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const SizedBox(height: 5),
          // Grabber.
          Container(
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFCCCCCC),
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          _header(context),
          Expanded(child: _grid()),
        ],
      ),
    );
  }

  /// Close button (left) + centered "Recents ⌄" title.
  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Recents',
                  style: TextStyle(
                    fontSize: 17,
                    height: 22 / 17,
                    letterSpacing: -0.43,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                SizedBox(width: 2),
                Icon(Icons.keyboard_arrow_down, size: 22, color: Color(0xFF333333)),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x29787880),
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 20,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 1.0;
        final cell = (constraints.maxWidth - 2 * gap) / 3;

        var idx = 0;
        Widget photo() {
          final i = idx++;
          return _PhotoTile(
            index: i,
            size: cell,
            selected: _selected.contains(i),
            onTap: () => _toggle(i),
          );
        }

        // Top block: tall camera tile (col 1, 2 rows) + 2×2 photos on the right.
        final top = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CameraTile(
              width: cell,
              height: cell * 2 + gap,
              onTap: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: gap),
            Column(
              children: [
                Row(children: [photo(), const SizedBox(width: gap), photo()]),
                const SizedBox(height: gap),
                Row(children: [photo(), const SizedBox(width: gap), photo()]),
              ],
            ),
          ],
        );

        // Remaining photos as full rows of three.
        final rows = <Widget>[];
        while (idx < _photoCount) {
          rows.add(const SizedBox(height: gap));
          rows.add(
            Row(
              children: [
                photo(),
                const SizedBox(width: gap),
                photo(),
                const SizedBox(width: gap),
                photo(),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          child: Column(children: [top, ...rows]),
        );
      },
    );
  }
}

/// One selectable photo cell — image with a selection ring in the top-right.
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.index,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://picsum.photos/seed/fixleo$index/240',
              fit: BoxFit.cover,
              // Soft placeholder while loading / when offline.
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : _placeholder(),
              errorBuilder: (context, error, stack) => _placeholder(),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Align(
                alignment: Alignment.topRight,
                child: _SelectionRing(selected: selected),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    // Vary the tint a little so the grid doesn't look flat when offline.
    final tint = Color.lerp(
      const Color(0xFFE2E8F0),
      const Color(0xFFCBD5E1),
      (index % 5) / 4,
    )!;
    return ColoredBox(color: tint);
  }
}

/// The white selection circle; fills blue with a check when selected.
class _SelectionRing extends StatelessWidget {
  const _SelectionRing({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.blue : Colors.transparent,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: selected
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : null,
    );
  }
}

/// The tall "open camera" tile in the top-left of the grid.
class _CameraTile extends StatelessWidget {
  const _CameraTile({
    required this.width,
    required this.height,
    required this.onTap,
  });

  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        color: const Color(0xFF1F2733),
        child: const Center(
          child: Icon(Icons.photo_camera, size: 30, color: Colors.white),
        ),
      ),
    );
  }
}
