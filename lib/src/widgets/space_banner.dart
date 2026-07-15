import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../l10n.dart';
import 'mxc_avatar.dart';

/// Space banner state event — the key Commet, Sable and VirtualChat use.
const spaceBannerEventType = 'page.codeberg.everypizza.room.banner';

/// The banner mxc URL of [room], or null when none is set.
Uri? spaceBannerUrl(Room room) {
  final url = room.getState(spaceBannerEventType)?.content['url'];
  if (url is String && url.startsWith('mxc://')) return Uri.tryParse(url);
  return null;
}

/// Discord-style banner strip shown at the top of a space's channel list.
/// Users with permission for the banner state event get upload/remove
/// controls; for everyone else the strip only appears when a banner is set.
class SpaceBanner extends StatefulWidget {
  const SpaceBanner({super.key, required this.space});

  final Room space;

  @override
  State<SpaceBanner> createState() => _SpaceBannerState();
}

class _SpaceBannerState extends State<SpaceBanner> {
  bool _busy = false;

  /// Server-fetched banner URLs by room id. Rooms synced before the banner
  /// event type was whitelisted in [Client.importantStateEvents] have no
  /// local copy of the state event, so it is fetched once from the server.
  static final _serverBanner = <String, Uri?>{};
  static final _fetchInFlight = <String>{};

  @override
  void initState() {
    super.initState();
    _maybeFetchFromServer();
  }

  @override
  void didUpdateWidget(SpaceBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.space.id != widget.space.id) _maybeFetchFromServer();
  }

  static Uri? _urlFrom(Map<String, Object?> content) {
    final url = content['url'];
    if (url is String && url.startsWith('mxc://')) return Uri.tryParse(url);
    return null;
  }

  Future<void> _maybeFetchFromServer() async {
    final room = widget.space;
    // Local state is authoritative once the event arrived through sync.
    if (room.getState(spaceBannerEventType) != null) return;
    if (_serverBanner.containsKey(room.id) || !_fetchInFlight.add(room.id)) {
      return;
    }
    try {
      final content = await room.client.getRoomStateWithKey(
        room.id,
        spaceBannerEventType,
        '',
      );
      _serverBanner[room.id] = _urlFrom(content);
    } catch (_) {
      // Not set (404) or unreachable — treat as no banner.
      _serverBanner[room.id] = null;
    } finally {
      _fetchInFlight.remove(room.id);
    }
    if (mounted) setState(() {});
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  Future<void> _upload() async {
    final picked = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: context.l10n.images,
          extensions: const ['png', 'jpg', 'jpeg', 'gif', 'webp'],
        ),
      ],
    );
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await picked.readAsBytes();
      final client = widget.space.client;
      final mxc = await client.uploadContent(bytes, filename: picked.name);
      await client.setRoomStateWithKey(
        widget.space.id,
        spaceBannerEventType,
        '',
        {'url': mxc.toString(), 'mimetype': picked.mimeType},
      );
      // Optimistic: show the new banner before the sync echo arrives.
      _serverBanner[widget.space.id] = Uri.tryParse(mxc.toString());
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    try {
      await widget.space.client.setRoomStateWithKey(
        widget.space.id,
        spaceBannerEventType,
        '',
        {},
      );
      _serverBanner[widget.space.id] = null;
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateEvent = widget.space.getState(spaceBannerEventType);
    final bannerUrl = stateEvent != null
        ? _urlFrom(stateEvent.content)
        : _serverBanner[widget.space.id];
    final canEdit = widget.space.canChangeStateEvent(spaceBannerEventType);
    if (bannerUrl == null && !canEdit) return const SizedBox.shrink();
    return SizedBox(
      height: bannerUrl != null ? 96 : 44,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (bannerUrl != null)
            MxcImage(
              client: widget.space.client,
              uri: bannerUrl,
              thumbnailWidth: 600,
              thumbnailHeight: 200,
              thumbnailMethod: ThumbnailMethod.scale,
            )
          else
            ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          if (canEdit)
            Positioned(
              top: 4,
              right: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  IconButton.filledTonal(
                    tooltip: context.l10n.changeBanner,
                    icon: const Icon(Icons.panorama_outlined, size: 18),
                    onPressed: _busy ? null : _upload,
                  ),
                  if (bannerUrl != null)
                    IconButton.filledTonal(
                      tooltip: context.l10n.removeBanner,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: _busy ? null : _remove,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
