import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import 'initials_avatar.dart';

/// A circle avatar for an `mxc://` URL, falling back to an [InitialsAvatar]
/// while loading or when no picture is set.
///
/// Thumbnails are fetched through the homeserver's media API (with
/// authentication) and kept in a small in-memory cache.
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
  static final _cache = <String, Uint8List>{};
  static const _maxCacheEntries = 200;

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
    if (mxc == null || !mxc.isScheme('mxc')) return;
    final key = mxc.toString();
    final cached = _cache[key];
    if (cached != null) {
      _bytes = cached;
      return;
    }
    try {
      final uri = await mxc.getThumbnailUri(
        widget.client,
        width: 128,
        height: 128,
        method: ThumbnailMethod.crop,
      );
      final response = await widget.client.httpClient.get(
        uri,
        headers: {'authorization': 'Bearer ${widget.client.accessToken}'},
      );
      if (response.statusCode != 200) return;
      if (_cache.length >= _maxCacheEntries) {
        _cache.remove(_cache.keys.first);
      }
      _cache[key] = response.bodyBytes;
      if (mounted) setState(() => _bytes = response.bodyBytes);
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
