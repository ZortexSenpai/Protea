import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../l10n.dart';
import '../temp_directory.dart';
import 'voice_message.dart' show formatAudioDuration;

/// Inline player for `m.video` events.
///
/// Shows the event's thumbnail with a play button; tapping downloads the
/// full attachment (the matrix SDK transparently decrypts encrypted files),
/// writes it to a temp file and plays it in place via media_kit. At most one
/// video plays at a time — starting one stops the previous.
class EventVideo extends StatefulWidget {
  const EventVideo({super.key, required this.event});

  final Event event;

  @override
  State<EventVideo> createState() => _EventVideoState();
}

class _EventVideoState extends State<EventVideo> {
  /// The instance currently holding a live player, so a newly started video
  /// can stop it.
  static _EventVideoState? _active;

  /// mxc URL → downloaded temp file, so replaying (or re-mounting after a
  /// scroll) skips the download.
  static final _fileCache = <String, String>{};

  static final _thumbnailCache = <String, Uint8List>{};
  static const _maxThumbnailCacheEntries = 50;

  static const _maxPreviewWidth = 400.0;
  static const _maxPreviewHeight = 280.0;
  static const _minPreviewExtent = 48.0;

  Player? _player;
  VideoController? _controller;
  Uint8List? _thumbnail;
  bool _loading = false;

  Duration get _duration =>
      Duration(milliseconds: widget.event.infoMap.tryGet<int>('duration') ?? 0);

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(EventVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.eventId != widget.event.eventId) {
      _stopPlayback();
      _thumbnail = null;
      _loadThumbnail();
    }
  }

  @override
  void dispose() {
    if (_active == this) _active = null;
    _player?.dispose();
    super.dispose();
  }

  Future<void> _loadThumbnail() async {
    final event = widget.event;
    if (!event.hasThumbnail) return;
    final key = event
        .attachmentOrThumbnailMxcUrl(getThumbnail: true)
        ?.toString();
    if (key == null) return;
    final cached = _thumbnailCache[key];
    if (cached != null) {
      _thumbnail = cached;
      return;
    }
    try {
      final file = await event.downloadAndDecryptAttachment(getThumbnail: true);
      if (_thumbnailCache.length >= _maxThumbnailCacheEntries) {
        _thumbnailCache.remove(_thumbnailCache.keys.first);
      }
      _thumbnailCache[key] = file.bytes;
      // The widget may have been recycled to another event meanwhile.
      if (mounted && event.eventId == widget.event.eventId) {
        setState(() => _thumbnail = file.bytes);
      }
    } catch (_) {
      // No thumbnail is fine — the placeholder stays.
    }
  }

  Future<void> _startPlayback() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final mxc = widget.event.attachmentMxcUrl?.toString();
      var path = mxc == null ? null : _fileCache[mxc];
      if (path == null || !File(path).existsSync()) {
        final file = await widget.event.downloadAndDecryptAttachment();
        final dir = await temporaryDirectory();
        final extension = file.name.contains('.')
            ? file.name.split('.').last
            : 'mp4';
        final tempFile = File(
          '${dir.path}/video_${widget.event.eventId.hashCode}.$extension',
        );
        await tempFile.writeAsBytes(file.bytes);
        path = tempFile.path;
        if (mxc != null) _fileCache[mxc] = path;
      }
      if (!mounted) return;
      _active?._stopPlayback();
      _active = this;
      final player = Player();
      _player = player;
      _controller = VideoController(player);
      await player.open(Media(path));
    } catch (e) {
      if (mounted) {
        _stopPlayback();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _stopPlayback() {
    final player = _player;
    _player = null;
    _controller = null;
    player?.dispose();
    if (_active == this) _active = null;
    if (mounted) setState(() {});
  }

  /// Reported video (or thumbnail) size scaled to fit the preview box,
  /// falling back to 16:9 when the event carries no size info.
  Size get _previewSize {
    double? dimension(Map<String, Object?> info, String key) =>
        (info[key] is num) ? (info[key] as num).toDouble() : null;
    var w = dimension(widget.event.infoMap, 'w');
    var h = dimension(widget.event.infoMap, 'h');
    if ((w == null || h == null) && widget.event.hasThumbnail) {
      w = dimension(widget.event.thumbnailInfoMap, 'w');
      h = dimension(widget.event.thumbnailInfoMap, 'h');
    }
    if (w == null || h == null || w <= 0 || h <= 0) {
      return const Size(_maxPreviewWidth, _maxPreviewWidth * 9 / 16);
    }
    final scale = min(1.0, min(_maxPreviewWidth / w, _maxPreviewHeight / h));
    return Size(
      max(w * scale, _minPreviewExtent),
      max(h * scale, _minPreviewExtent),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final thumbnail = _thumbnail;
    final duration = _duration;
    return GestureDetector(
      onTap: _loading ? null : _startPlayback,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          if (thumbnail != null)
            Image.memory(thumbnail, fit: BoxFit.cover)
          else
            Container(
              color: colorScheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: Icon(
                Icons.videocam_outlined,
                size: 48,
                color: colorScheme.outline,
              ),
            ),
          Center(
            child: _loading
                ? const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      tooltip: context.l10n.playVideo,
                      iconSize: 32,
                      color: Colors.white,
                      icon: const Icon(Icons.play_arrow),
                      onPressed: _startPlayback,
                    ),
                  ),
          ),
          if (duration > Duration.zero)
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  formatAudioDuration(duration),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = _previewSize;
    final controller = _controller;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: controller != null
            ? Video(controller: controller)
            : _buildPreview(context),
      ),
    );
  }
}
