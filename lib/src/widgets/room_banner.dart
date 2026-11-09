import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import 'mxc_avatar.dart';

/// Room banner state event — the key Commet, Sable and VirtualChat use.
const roomBannerEventType = 'page.codeberg.everypizza.room.banner';

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
Uri? currentRoomBanner(Room room) {
  final stateEvent = room.getState(roomBannerEventType);
  if (stateEvent != null) return _urlFrom(stateEvent.content);
  return _serverBanner[room.id];
}

/// Writes [mxc] as the banner state event of [room].
Future<void> setRoomBanner(Room room, Uri mxc, {String? mimeType}) async {
  await room.client.setRoomStateWithKey(room.id, roomBannerEventType, '', {
    'url': mxc.toString(),
    'mimetype': ?mimeType,
  });
  // Optimistic: reflect the change before the sync echo arrives.
  _serverBanner[room.id] = mxc;
}

/// Removes the banner of [room] (empty state event content, the convention
/// the other clients use).
Future<void> removeRoomBanner(Room room) async {
  await room.client.setRoomStateWithKey(room.id, roomBannerEventType, '', {});
  _serverBanner[room.id] = null;
}

/// Discord-style banner strip: shown at the top of a space's channel list
/// and of a room's member list. Display only — changing or removing the
/// banner lives in the settings dialog.
class RoomBanner extends StatefulWidget {
  const RoomBanner({super.key, required this.room});

  final Room room;

  @override
  State<RoomBanner> createState() => _RoomBannerState();
}

class _RoomBannerState extends State<RoomBanner> {
  @override
  void initState() {
    super.initState();
    _maybeFetchFromServer();
  }

  @override
  void didUpdateWidget(RoomBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.id != widget.room.id) _maybeFetchFromServer();
  }

  Future<void> _maybeFetchFromServer() async {
    final room = widget.room;
    // Local state is authoritative once the event arrived through sync.
    if (room.getState(roomBannerEventType) != null) return;
    if (_serverBanner.containsKey(room.id) || !_fetchInFlight.add(room.id)) {
      return;
    }
    try {
      final content = await room.client.getRoomStateWithKey(
        room.id,
        roomBannerEventType,
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
    final bannerUrl = currentRoomBanner(widget.room);
    if (bannerUrl == null) return const SizedBox.shrink();
    return SizedBox(
      height: 96,
      width: double.infinity,
      child: MxcImage(
        client: widget.room.client,
        uri: bannerUrl,
        thumbnailWidth: 600,
        thumbnailHeight: 200,
        thumbnailMethod: ThumbnailMethod.scale,
      ),
    );
  }
}
