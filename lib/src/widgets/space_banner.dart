import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import 'mxc_avatar.dart';

/// Space banner state event — the key Commet, Sable and VirtualChat use.
const spaceBannerEventType = 'page.codeberg.everypizza.room.banner';

/// Server-fetched banner URLs by room id. Rooms synced before the banner
/// event type was whitelisted in [Client.importantStateEvents] have no local
/// copy of the state event, so it is fetched once from the server. Shared by
/// the banner strip and the space settings actions.
final _serverBanner = <String, Uri?>{};
final _fetchInFlight = <String>{};

Uri? _urlFrom(Map<String, Object?> content) {
  final url = content['url'];
  if (url is String && url.startsWith('mxc://')) return Uri.tryParse(url);
  return null;
}

/// The banner of [room] as currently known: the local state event when it
/// arrived through sync, otherwise the server-fetched cache.
Uri? currentSpaceBanner(Room room) {
  final stateEvent = room.getState(spaceBannerEventType);
  if (stateEvent != null) return _urlFrom(stateEvent.content);
  return _serverBanner[room.id];
}

/// Writes [mxc] as the banner state event of [space].
Future<void> setSpaceBanner(Room space, Uri mxc, {String? mimeType}) async {
  await space.client.setRoomStateWithKey(space.id, spaceBannerEventType, '', {
    'url': mxc.toString(),
    'mimetype': ?mimeType,
  });
  // Optimistic: reflect the change before the sync echo arrives.
  _serverBanner[space.id] = mxc;
}

/// Removes the banner of [space] (empty state event content, the convention
/// the other clients use).
Future<void> removeSpaceBanner(Room space) async {
  await space.client.setRoomStateWithKey(
    space.id,
    spaceBannerEventType,
    '',
    {},
  );
  _serverBanner[space.id] = null;
}

/// Discord-style banner strip shown at the top of a space's channel list.
/// Display only — changing or removing the banner lives in the space
/// settings dialog.
class SpaceBanner extends StatefulWidget {
  const SpaceBanner({super.key, required this.space});

  final Room space;

  @override
  State<SpaceBanner> createState() => _SpaceBannerState();
}

class _SpaceBannerState extends State<SpaceBanner> {
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

  @override
  Widget build(BuildContext context) {
    final bannerUrl = currentSpaceBanner(widget.space);
    if (bannerUrl == null) return const SizedBox.shrink();
    return SizedBox(
      height: 96,
      width: double.infinity,
      child: MxcImage(
        client: widget.space.client,
        uri: bannerUrl,
        thumbnailWidth: 600,
        thumbnailHeight: 200,
        thumbnailMethod: ThumbnailMethod.scale,
      ),
    );
  }
}
