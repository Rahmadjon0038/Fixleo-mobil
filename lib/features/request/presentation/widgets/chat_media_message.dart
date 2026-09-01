import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:latlong2/latlong.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';

String formatChatDuration(int totalSeconds) {
  final safe = totalSeconds.clamp(0, 24 * 60 * 60);
  final minutes = safe ~/ 60;
  final seconds = safe % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

class ChatImageMessage extends StatelessWidget {
  const ChatImageMessage({super.key, required this.url, required this.isMine});

  final String url;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.92),
        builder: (dialogContext) => Dialog.fullscreen(
          backgroundColor: Colors.transparent,
          child: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5,
                    child: Center(
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image_outlined,
                          size: 48,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black45,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 180,
            minHeight: 120,
            maxWidth: 260,
            maxHeight: 320,
          ),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 220,
                height: 180,
                color: isMine
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFFF0F3F7),
                alignment: Alignment.center,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isMine ? Colors.white : AppColors.blue,
                ),
              );
            },
            errorBuilder: (_, _, _) => Container(
              width: 220,
              height: 150,
              color: isMine
                  ? Colors.white.withValues(alpha: 0.12)
                  : const Color(0xFFF0F3F7),
              alignment: Alignment.center,
              child: Icon(
                Icons.broken_image_outlined,
                color: isMine ? Colors.white70 : const Color(0xFF8D96A4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ChatLocationMessage extends StatelessWidget {
  const ChatLocationMessage({
    super.key,
    required this.point,
    required this.isMine,
    this.label,
  });

  final LatLng point;
  final bool isMine;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    final center = gmap.LatLng(point.latitude, point.longitude);
    final locationLabel = label?.trim().isNotEmpty == true
        ? label!.trim()
        : tr(
            lang,
            'Yuborilgan joylashuv',
            'Отправленное местоположение',
            'Shared location',
          );
    return Semantics(
      button: true,
      label:
          '$locationLabel. ${tr(lang, 'Xaritada ko‘rish', 'Открыть на карте', 'View on map')}',
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                _ChatLocationViewer(center: center, label: locationLabel),
          ),
        ),
        child: SizedBox(
          width: 235,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: SizedBox(
                  height: 145,
                  width: double.infinity,
                  child: IgnorePointer(
                    child: gmap.GoogleMap(
                      key: ValueKey(
                        'chat-map-${point.latitude}-${point.longitude}',
                      ),
                      initialCameraPosition: gmap.CameraPosition(
                        target: center,
                        zoom: 15,
                      ),
                      markers: {
                        gmap.Marker(
                          markerId: const gmap.MarkerId('shared-location'),
                          position: center,
                        ),
                      },
                      liteModeEnabled: true,
                      compassEnabled: false,
                      mapToolbarEnabled: false,
                      myLocationButtonEnabled: false,
                      myLocationEnabled: false,
                      rotateGesturesEnabled: false,
                      scrollGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                      zoomControlsEnabled: false,
                      zoomGesturesEnabled: false,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 9, 8, 4),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isMine
                            ? Colors.white.withValues(alpha: 0.18)
                            : AppColors.blue.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 20,
                        color: isMine ? Colors.white : AppColors.blue,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            locationLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isMine ? Colors.white : AppColors.navy,
                              fontSize: 13,
                              height: 17 / 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tr(
                              lang,
                              'Xaritada ko‘rish',
                              'Открыть на карте',
                              'View on map',
                            ),
                            style: TextStyle(
                              color: isMine
                                  ? Colors.white.withValues(alpha: 0.76)
                                  : AppColors.blue,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isMine ? Colors.white70 : AppColors.blue,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatLocationViewer extends StatelessWidget {
  const _ChatLocationViewer({required this.center, required this.label});

  final gmap.LatLng center;
  final String label;

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
        title: Text(
          tr(lang, 'Joylashuv', 'Местоположение', 'Location'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: gmap.GoogleMap(
              initialCameraPosition: gmap.CameraPosition(
                target: center,
                zoom: 16,
              ),
              markers: {
                gmap.Marker(
                  markerId: const gmap.MarkerId('shared-location-full'),
                  position: center,
                  infoWindow: gmap.InfoWindow(title: label),
                ),
              },
              compassEnabled: true,
              mapToolbarEnabled: true,
              myLocationButtonEnabled: false,
              myLocationEnabled: false,
              zoomControlsEnabled: false,
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: SafeArea(
              top: false,
              child: Material(
                elevation: 8,
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFE8F3FF),
                        child: Icon(
                          Icons.location_on_rounded,
                          color: AppColors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${center.latitude.toStringAsFixed(6)}, ${center.longitude.toStringAsFixed(6)}',
                              style: const TextStyle(
                                color: Color(0xFF8D96A4),
                                fontSize: 12,
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
          ),
        ],
      ),
    );
  }
}

class ChatVoiceMessage extends StatefulWidget {
  const ChatVoiceMessage({
    super.key,
    required this.url,
    required this.isMine,
    required this.durationSec,
    required this.playLabel,
    required this.pauseLabel,
  });

  final String url;
  final bool isMine;
  final int durationSec;
  final String playLabel;
  final String pauseLabel;

  @override
  State<ChatVoiceMessage> createState() => _ChatVoiceMessageState();
}

class _ChatVoiceMessageState extends State<ChatVoiceMessage> {
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<Object?>> _subscriptions = [];

  Duration _position = Duration.zero;
  late Duration _duration = Duration(seconds: widget.durationSec);
  bool _playing = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _subscriptions
      ..add(
        _player.onPlayerStateChanged.listen((state) {
          if (!mounted) return;
          setState(() {
            _playing = state == PlayerState.playing;
            _loading = false;
          });
        }),
      )
      ..add(
        _player.onPositionChanged.listen((position) {
          if (mounted) setState(() => _position = position);
        }),
      )
      ..add(
        _player.onDurationChanged.listen((duration) {
          if (mounted && duration > Duration.zero) {
            setState(() => _duration = duration);
          }
        }),
      )
      ..add(
        _player.onPlayerComplete.listen((_) {
          if (!mounted) return;
          setState(() {
            _playing = false;
            _position = Duration.zero;
          });
        }),
      );
  }

  @override
  void didUpdateWidget(covariant ChatVoiceMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      unawaited(_player.stop());
      _position = Duration.zero;
    }
    if (oldWidget.durationSec != widget.durationSec) {
      _duration = Duration(seconds: widget.durationSec);
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_loading) return;
    if (_playing) {
      await _player.pause();
      return;
    }
    setState(() => _loading = true);
    try {
      if (_position > Duration.zero) {
        await _player.resume();
      } else {
        await _player.play(UrlSource(widget.url));
      }
    } on Object {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _seek(double milliseconds) async {
    final position = Duration(milliseconds: milliseconds.round());
    await _player.seek(position);
    if (mounted) setState(() => _position = position);
  }

  @override
  Widget build(BuildContext context) {
    final foreground = widget.isMine ? Colors.white : AppColors.navy;
    final muted = widget.isMine
        ? Colors.white.withValues(alpha: 0.72)
        : const Color(0xFF7C8797);
    final totalMs = _duration.inMilliseconds > 0
        ? _duration.inMilliseconds.toDouble()
        : 1.0;
    final currentMs = _position.inMilliseconds
        .clamp(0, totalMs.round())
        .toDouble();

    return SizedBox(
      width: 235,
      child: Row(
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: IconButton(
              tooltip: _playing ? widget.pauseLabel : widget.playLabel,
              style: IconButton.styleFrom(
                backgroundColor: widget.isMine
                    ? Colors.white.withValues(alpha: 0.18)
                    : AppColors.blue.withValues(alpha: 0.10),
                foregroundColor: foreground,
                padding: EdgeInsets.zero,
              ),
              onPressed: _loading ? null : _toggle,
              icon: _loading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  : Icon(
                      _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 27,
                    ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                    activeTrackColor: foreground,
                    inactiveTrackColor: muted.withValues(alpha: 0.35),
                    thumbColor: foreground,
                    overlayColor: foreground.withValues(alpha: 0.12),
                  ),
                  child: Slider(
                    value: currentMs,
                    min: 0,
                    max: totalMs,
                    onChanged: _seek,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  child: Row(
                    children: [
                      Icon(Icons.mic_rounded, size: 13, color: muted),
                      const SizedBox(width: 3),
                      Text(
                        formatChatDuration(
                          _position > Duration.zero
                              ? _position.inSeconds
                              : _duration.inSeconds,
                        ),
                        style: TextStyle(
                          color: muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
