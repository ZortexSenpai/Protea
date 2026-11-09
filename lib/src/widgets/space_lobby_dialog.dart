import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../l10n.dart';
import '../nicknames.dart';
import '../pages/room_page.dart';
import 'mxc_avatar.dart';

/// Browses the full hierarchy of [space] — including rooms that are not
/// joined yet — with join and knock actions.
Future<void> showSpaceLobby(BuildContext context, Room space) => showDialog(
  context: context,
  builder: (_) => SpaceLobbyDialog(space: space),
);

class SpaceLobbyDialog extends StatefulWidget {
  const SpaceLobbyDialog({super.key, required this.space});

  final Room space;

  @override
  State<SpaceLobbyDialog> createState() => _SpaceLobbyDialogState();
}

class _SpaceLobbyDialogState extends State<SpaceLobbyDialog> {
  final _scrollController = ScrollController();
  final _rooms = <SpaceRoomsChunk$2>[];
  String? _nextBatch;
  bool _loading = false;
  String? _error;

  /// Room id with a join/knock request in flight.
  String? _busyRoomId;

  /// Rooms knocked on in this dialog session (the knock membership may not
  /// have synced yet).
  final _knocked = <String>{};

  Client get _client => widget.space.client;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetch();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loading || _nextBatch == null) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _fetch(append: true);
    }
  }

  Future<void> _fetch({bool append = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _client.getSpaceHierarchy(
        widget.space.id,
        limit: 50,
        from: append ? _nextBatch : null,
      );
      if (!mounted) return;
      setState(() {
        if (!append) _rooms.clear();
        _rooms.addAll(
          response.rooms.where((chunk) => chunk.roomId != widget.space.id),
        );
        _nextBatch = response.nextBatch;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Servers to join/knock through, taken from the space's child event.
  List<String>? _viaFor(String roomId) {
    for (final child in widget.space.spaceChildren) {
      if (child.roomId == roomId) {
        final via = child.via;
        return via.isEmpty ? null : via;
      }
    }
    return null;
  }

  Future<void> _join(SpaceRoomsChunk$2 chunk) async {
    setState(() => _busyRoomId = chunk.roomId);
    try {
      final roomId = await _client.joinRoom(
        chunk.roomId,
        via: _viaFor(chunk.roomId),
      );
      if (!mounted) return;
      setState(() => _busyRoomId = null);
      final room = _client.getRoomById(roomId);
      if (room != null && !room.isSpace) {
        final navigator = Navigator.of(context);
        navigator.pop();
        navigator.push(MaterialPageRoute(builder: (_) => RoomPage(room: room)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busyRoomId = null);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _knock(SpaceRoomsChunk$2 chunk) async {
    setState(() => _busyRoomId = chunk.roomId);
    try {
      await _client.knockRoom(chunk.roomId, via: _viaFor(chunk.roomId));
      if (!mounted) return;
      setState(() {
        _busyRoomId = null;
        _knocked.add(chunk.roomId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.knockedWaitingForApproval)),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busyRoomId = null);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _open(Room room) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute(builder: (_) => RoomPage(room: room)));
  }

  Widget _trailingFor(SpaceRoomsChunk$2 chunk) {
    if (_busyRoomId == chunk.roomId) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final joinedRoom = _client.getRoomById(chunk.roomId);
    if (joinedRoom != null && joinedRoom.membership == Membership.join) {
      return Text(context.l10n.joined);
    }
    final knocked =
        _knocked.contains(chunk.roomId) ||
        joinedRoom?.membership == Membership.knock;
    if (knocked) return Text(context.l10n.knocked);
    if (chunk.joinRule == 'knock') {
      return OutlinedButton(
        onPressed: _busyRoomId != null ? null : () => _knock(chunk),
        child: Text(context.l10n.knock),
      );
    }
    return FilledButton(
      onPressed: _busyRoomId != null ? null : () => _join(chunk),
      child: Text(context.l10n.join),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.space.nickOrDisplayname,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.refresh,
                    icon: const Icon(Icons.refresh),
                    onPressed: _loading ? null : _fetch,
                  ),
                  IconButton(
                    tooltip: context.l10n.close,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: _rooms.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: _loading
                          ? const CircularProgressIndicator()
                          : Text(_error ?? context.l10n.spaceHasNoRooms),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _rooms.length,
                      itemBuilder: (context, index) {
                        final chunk = _rooms[index];
                        final name =
                            chunk.name ?? chunk.canonicalAlias ?? chunk.roomId;
                        final isSpace = chunk.roomType == 'm.space';
                        final joinedRoom = _client.getRoomById(chunk.roomId);
                        final joined =
                            joinedRoom?.membership == Membership.join;
                        return ListTile(
                          leading: isSpace
                              ? const Icon(Icons.workspaces_outline)
                              : MxcAvatar(
                                  client: _client,
                                  name: name,
                                  avatarUrl: chunk.avatarUrl,
                                ),
                          title: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            [
                              context.l10n.membersCount(chunk.numJoinedMembers),
                              if (chunk.topic?.isNotEmpty ?? false)
                                chunk.topic!,
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: _trailingFor(chunk),
                          onTap: joined && !isSpace && joinedRoom != null
                              ? () => _open(joinedRoom)
                              : null,
                        );
                      },
                    ),
            ),
            if (_loading && _rooms.isNotEmpty)
              const LinearProgressIndicator(minHeight: 2),
          ],
        ),
      ),
    );
  }
}
