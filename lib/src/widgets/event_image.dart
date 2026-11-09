import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../attachment_actions.dart';
import '../event_body.dart';
import '../l10n.dart';
import '../notifications.dart';
import '../settings.dart';

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

  /// First frame of an animated GIF, decoded on demand while playback is
  /// paused in the background.
  ui.Image? _staticFrame;
  bool _decodingStaticFrame = false;

  bool get _isGif =>
      widget.event.infoMap['mimetype'] == 'image/gif' ||
      widget.event.attachmentName.toLowerCase().endsWith('.gif');

  Future<void> _decodeStaticFrame(Uint8List bytes) async {
    if (_staticFrame != null || _decodingStaticFrame) return;
    _decodingStaticFrame = true;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (mounted) {
        setState(() => _staticFrame = frame.image);
      } else {
        frame.image.dispose();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _staticFrame?.dispose();
    super.dispose();
  }

  /// The image itself; GIFs render their first frame while the window is in
  /// the background and the pause setting is on.
  ///
  /// [cacheWidth] bounds the decoded bitmap: timeline previews render in a
  /// box of at most [_maxPreviewExtent] logical pixels, while the bytes can
  /// be a multi-megapixel original (when the event has no thumbnail), whose
  /// full decode stutters scrolling.
  Widget _image(Uint8List bytes, BoxFit fit, {int? cacheWidth}) {
    if (!_isGif || !SettingsScope.of(context).pauseGifsUnfocused) {
      return Image.memory(bytes, fit: fit, cacheWidth: cacheWidth);
    }
    return ValueListenableBuilder<bool>(
      valueListenable: NotificationService.appFocused,
      builder: (context, focused, _) {
        if (focused) {
          return Image.memory(bytes, fit: fit, cacheWidth: cacheWidth);
        }
        _decodeStaticFrame(bytes);
        final still = _staticFrame;
        if (still == null) {
          return Image.memory(bytes, fit: fit, cacheWidth: cacheWidth);
        }
        return RawImage(image: still, fit: fit);
      },
    );
  }

  /// GIF previews skip the server thumbnail (a static first frame) and
  /// fetch the original file, so the animation plays in the timeline.
  bool get _fetchThumbnail => widget.thumbnail && !_isGif;

  String? get _cacheKey => widget.event
      .attachmentOrThumbnailMxcUrl(getThumbnail: _fetchThumbnail)
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
      final file = await widget.event.downloadAndDecryptAttachment(
        getThumbnail: _fetchThumbnail,
      );
      if (_cache.length >= _maxCacheEntries) {
        _cache.remove(_cache.keys.first);
      }
      _cache[key] = file.bytes;
      // Discard stale results: the widget may have been recycled to
      // another event while this download was in flight.
      if (mounted && _cacheKey == key) {
        setState(() => _bytes = file.bytes);
      }
    } catch (_) {
      if (mounted && _cacheKey == key) setState(() => _error = true);
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
    // Full-size mode (the image viewer). The layout box is the original's
    // final display size — fit into the viewport, never scaled up —
    // computed up front from the event's size info. Laying the stand-in
    // out in the same box gives the Hero flight a stable destination on
    // first open and avoids any size jump when the original arrives, and
    // keeps the box hugging the visible image so taps beside it fall
    // through to the viewer's close handler. While the original
    // downloads, the timeline's cached thumbnail stands in.
    if (widget.fit != null) {
      final thumbKey = widget.event
          .attachmentOrThumbnailMxcUrl(getThumbnail: true)
          ?.toString();
      final shown = bytes ?? _cache[thumbKey];
      if (_error && shown == null) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, color: colorScheme.error),
            const SizedBox(width: 8),
            Flexible(child: Text(widget.event.attachmentLabel)),
          ],
        );
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          final child = shown == null
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _image(shown, widget.fit!);
          final info = widget.event.infoMap;
          final w = (info['w'] is num) ? (info['w'] as num).toDouble() : null;
          final h = (info['h'] is num) ? (info['h'] as num).toDouble() : null;
          if (w == null ||
              h == null ||
              w <= 0 ||
              h <= 0 ||
              !constraints.hasBoundedWidth ||
              !constraints.hasBoundedHeight) {
            // No size info: let the image size itself like before.
            return child;
          }
          final scale = min(
            1.0,
            min(constraints.maxWidth / w, constraints.maxHeight / h),
          );
          return SizedBox(width: w * scale, height: h * scale, child: child);
        },
      );
    }
    if (bytes != null) {
      final size = _previewSize;
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: size.width,
          maxHeight: size.height,
        ),
        child: AspectRatio(
          aspectRatio: size.width / size.height,
          child: _image(
            bytes,
            BoxFit.cover,
            cacheWidth: (size.width * MediaQuery.devicePixelRatioOf(context))
                .round(),
          ),
        ),
      );
    }
    if (_error) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: colorScheme.error),
          const SizedBox(width: 8),
          Flexible(child: Text(widget.event.attachmentLabel)),
        ],
      );
    }
    final size = _previewSize;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: size.width, maxHeight: size.height),
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
/// Zoom: pinch/scroll, double-click, or the toolbar buttons.
class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({super.key, required this.event});

  final Event event;

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage>
    with SingleTickerProviderStateMixin {
  static const _minScale = 1.0;
  static const _maxScale = 8.0;

  final _transformationController = TransformationController();
  final _viewerKey = GlobalKey();
  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  Animation<Matrix4>? _animation;

  @override
  void initState() {
    super.initState();
    _animationController.addListener(() {
      final animation = _animation;
      if (animation != null) {
        _transformationController.value = animation.value;
      }
    });
    // Keeps the zoom percentage in the toolbar current while pinching.
    _transformationController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  double get _scale => _transformationController.value.getMaxScaleOnAxis();

  void _animateTo(Matrix4 target) {
    _animation =
        Matrix4Tween(
          begin: _transformationController.value,
          end: target,
        ).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );
    _animationController.forward(from: 0);
  }

  /// Zooms by [factor] around [focal] (viewer coordinates), defaulting to
  /// the viewport center.
  void _zoomBy(double factor, [Offset? focal]) {
    final current = _transformationController.value.clone();
    final targetScale = (_scale * factor).clamp(_minScale, _maxScale);
    final effective = targetScale / _scale;
    if (effective == 1) return;
    final size = _viewerKey.currentContext?.size ?? MediaQuery.sizeOf(context);
    final f = focal ?? Offset(size.width / 2, size.height / 2);
    final zoom =
        Matrix4.translationValues(f.dx, f.dy, 0) *
                Matrix4.diagonal3Values(effective, effective, 1) *
                Matrix4.translationValues(-f.dx, -f.dy, 0) *
                current
            as Matrix4;
    _animateTo(zoom);
  }

  void _reset() => _animateTo(Matrix4.identity());

  void _onDoubleTapDown(TapDownDetails details) {
    if (_scale > 1.5) {
      _reset();
    } else {
      _zoomBy(2.5 / _scale, details.localPosition);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filename = widget.event.attachmentName;
    final zoomed = (_scale - 1).abs() > 0.01;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(filename, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (zoomed)
            Center(
              child: Text(
                '${(_scale * 100).round()} %',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: Colors.white70),
              ),
            ),
          IconButton(
            tooltip: context.l10n.zoomOut,
            icon: const Icon(Icons.zoom_out),
            onPressed: _scale <= _minScale ? null : () => _zoomBy(1 / 1.5),
          ),
          IconButton(
            tooltip: context.l10n.zoomIn,
            icon: const Icon(Icons.zoom_in),
            onPressed: _scale >= _maxScale ? null : () => _zoomBy(1.5),
          ),
          IconButton(
            tooltip: context.l10n.resetZoom,
            icon: const Icon(Icons.fit_screen_outlined),
            onPressed: zoomed ? _reset : null,
          ),
          IconButton(
            tooltip: context.l10n.copyImage,
            icon: const Icon(Icons.copy_outlined),
            onPressed: () => copyImageAttachment(context, widget.event),
          ),
          IconButton(
            tooltip: context.l10n.downloadImage,
            icon: const Icon(Icons.download_outlined),
            onPressed: () => saveAttachment(context, widget.event),
          ),
        ],
      ),
      body: GestureDetector(
        // Tapping the backdrop closes the viewer; taps on the image itself
        // are absorbed by the inner detector. Fires only after the
        // double-tap window, since the zoom gesture shares the arena.
        onTap: () => Navigator.of(context).pop(),
        onDoubleTapDown: _onDoubleTapDown,
        child: InteractiveViewer(
          key: _viewerKey,
          transformationController: _transformationController,
          minScale: _minScale,
          maxScale: _maxScale,
          child: Center(
            child: Hero(
              tag: widget.event.eventId,
              child: GestureDetector(
                onTap: () {},
                child: EventImage(
                  event: widget.event,
                  thumbnail: false,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
