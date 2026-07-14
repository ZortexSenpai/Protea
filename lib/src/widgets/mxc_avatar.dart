import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import 'initials_avatar.dart';

/// Small in-memory cache for mxc thumbnails, shared by [MxcAvatar] and
/// [MxcImage].
final _cache = <String, Uint8List>{};
const _maxCacheEntries = 200;

/// Downloads a thumbnail for an `mxc://` URI through the homeserver's
/// (authenticated) media API. Returns null when the URI is not mxc or the
/// request fails.
Future<Uint8List?> fetchMxcThumbnail(
  Client client,
  Uri mxc, {
  num width = 128,
  num height = 128,
}) async {
  if (!mxc.isScheme('mxc')) return null;
  final key = '$mxc;$width;$height';
  final cached = _cache[key];
  if (cached != null) return cached;
  final uri = await mxc.getThumbnailUri(
    client,
    width: width,
    height: height,
    method: ThumbnailMethod.crop,
  );
  final response = await client.httpClient.get(
    uri,
    headers: {'authorization': 'Bearer ${client.accessToken}'},
  );
  if (response.statusCode != 200) return null;
  if (_cache.length >= _maxCacheEntries) {
    _cache.remove(_cache.keys.first);
  }
  return _cache[key] = response.bodyBytes;
}

/// A circle avatar for an `mxc://` URL, falling back to an [InitialsAvatar]
/// while loading or when no picture is set.
class MxcAvatar extends StatefulWidget {
  const MxcAvatar({
    super.key,
    required this.client,
    required this.name,
    this.avatarUrl,
    this.radius = 20,
  });

  final Client client;
  final String name;
  final Uri? avatarUrl;
  final double radius;

  @override
  State<MxcAvatar> createState() => _MxcAvatarState();
}

class _MxcAvatarState extends State<MxcAvatar> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MxcAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarUrl != widget.avatarUrl) {
      _bytes = null;
      _load();
    }
  }

  Future<void> _load() async {
    final mxc = widget.avatarUrl;
    if (mxc == null) return;
    try {
      final bytes = await fetchMxcThumbnail(widget.client, mxc);
      if (bytes != null && mounted) setState(() => _bytes = bytes);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) {
      return InitialsAvatar(name: widget.name, radius: widget.radius);
    }
    return CircleAvatar(
      radius: widget.radius,
      foregroundImage: MemoryImage(bytes),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }
}

/// A rectangular image for an `mxc://` URL (e.g. profile banners). Shows
/// [placeholder] (or a plain surface) while loading or on failure.
class MxcImage extends StatefulWidget {
  const MxcImage({
    super.key,
    required this.client,
    required this.uri,
    this.thumbnailWidth = 800,
    this.thumbnailHeight = 450,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  final Client client;
  final Uri uri;
  final num thumbnailWidth;
  final num thumbnailHeight;
  final BoxFit fit;
  final WidgetBuilder? placeholder;

  @override
  State<MxcImage> createState() => _MxcImageState();
}

class _MxcImageState extends State<MxcImage> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MxcImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri) {
      _bytes = null;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final bytes = await fetchMxcThumbnail(
        widget.client,
        widget.uri,
        width: widget.thumbnailWidth,
        height: widget.thumbnailHeight,
      );
      if (bytes != null && mounted) setState(() => _bytes = bytes);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) {
      return widget.placeholder?.call(context) ??
          ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          );
    }
    return Image.memory(
      bytes,
      fit: widget.fit,
      width: double.infinity,
      height: double.infinity,
    );
  }
}
