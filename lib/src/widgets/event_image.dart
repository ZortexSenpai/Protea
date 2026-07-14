import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

/// Displays the image attachment of an [Event] (m.image or sticker).
///
/// Downloads the thumbnail (or the full file for [thumbnail] = false) via the
/// matrix SDK, which also transparently decrypts encrypted attachments.
/// Downloaded bytes are kept in a small in-memory cache so scrolling back and
/// forth does not re-fetch.
class EventImage extends StatefulWidget {
  const EventImage({
    super.key,
    required this.event,
    this.thumbnail = true,
    this.fit,
  });

  final Event event;
  final bool thumbnail;
  final BoxFit? fit;

  @override
  State<EventImage> createState() => _EventImageState();
}

class _EventImageState extends State<EventImage> {
  static final _cache = <String, Uint8List>{};
  static const _maxCacheEntries = 100;

  static const _maxPreviewExtent = 320.0;
  static const _minPreviewExtent = 48.0;

  Uint8List? _bytes;
  bool _error = false;

  String? get _cacheKey => widget.event
      .attachmentOrThumbnailMxcUrl(getThumbnail: widget.thumbnail)
      ?.toString();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(EventImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.eventId != widget.event.eventId ||
        oldWidget.thumbnail != widget.thumbnail) {
      _bytes = null;
      _error = false;
      _load();
    }
  }

  Future<void> _load() async {
    final key = _cacheKey;
    if (key == null) {
      _error = true;
      return;
    }
    final cached = _cache[key];
    if (cached != null) {
      _bytes = cached;
      return;
    }
    try {
      final file = await widget.event
          .downloadAndDecryptAttachment(getThumbnail: widget.thumbnail);
      if (_cache.length >= _maxCacheEntries) {
        _cache.remove(_cache.keys.first);
      }
      _cache[key] = file.bytes;
      if (mounted) setState(() => _bytes = file.bytes);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  /// Reported size of the image (or its thumbnail), scaled to fit the
  /// preview box. Falls back to a square when the event carries no size info.
  Size get _previewSize {
    final info = widget.thumbnail && widget.event.hasThumbnail
        ? widget.event.thumbnailInfoMap
        : widget.event.infoMap;
    final w = (info['w'] is num) ? (info['w'] as num).toDouble() : null;
    final h = (info['h'] is num) ? (info['h'] as num).toDouble() : null;
    if (w == null || h == null || w <= 0 || h <= 0) {
      return const Size(_maxPreviewExtent / 2, _maxPreviewExtent / 2);
    }
    final scale = min(1.0, min(_maxPreviewExtent / w, _maxPreviewExtent / h));
    return Size(
      max(w * scale, _minPreviewExtent),
      max(h * scale, _minPreviewExtent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bytes = _bytes;
    if (bytes != null) {
      if (widget.fit != null) {
        return Image.memory(bytes, fit: widget.fit);
      }
      final size = _previewSize;
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: size.width,
          maxHeight: size.height,
        ),
        child: AspectRatio(
          aspectRatio: size.width / size.height,
          child: Image.memory(bytes, fit: BoxFit.cover),
        ),
      );
    }
    if (_error) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: colorScheme.error),
          const SizedBox(width: 8),
          Flexible(child: Text(widget.event.body)),
        ],
      );
    }
    final size = _previewSize;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: size.width,
        maxHeight: size.height,
      ),
      child: AspectRatio(
        aspectRatio: size.width / size.height,
        child: Container(
          color: colorScheme.surfaceContainerHigh,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}

/// Full-screen viewer for an image event, opened by tapping a preview.
class ImageViewerPage extends StatelessWidget {
  const ImageViewerPage({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final filename =
        event.content.tryGet<String>('filename') ?? event.body;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(filename, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 8,
          child: Hero(
            tag: event.eventId,
            child: EventImage(
              event: event,
              thumbnail: false,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
