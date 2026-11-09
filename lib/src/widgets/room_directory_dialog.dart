import 'dart:async';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../l10n.dart';
import '../pages/room_page.dart';
import 'mxc_avatar.dart';

/// Browses the homeserver's public room directory with search and join.
Future<void> showRoomDirectory(BuildContext context, Client client) =>
    showDialog(
      context: context,
      builder: (_) => RoomDirectoryDialog(client: client),
    );

class RoomDirectoryDialog extends StatefulWidget {
  const RoomDirectoryDialog({super.key, required this.client});

  final Client client;

  @override
  State<RoomDirectoryDialog> createState() => _RoomDirectoryDialogState();
}

class _RoomDirectoryDialogState extends State<RoomDirectoryDialog> {
  final _searchController = TextEditingController();
  final _serverController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  final List<PublishedRoomsChunk> _rooms = [];
  String? _nextBatch;
  bool _loading = false;
  String? _joiningRoomId;
  var _fetchVersion = 0;

  /// Rooms knocked on in this dialog session.
  final _knocked = <String>{};

  @override
  void initState() {
    super.initState();
    _serverController.text = widget.client.homeserver?.host ?? '';
    _scrollController.addListener(_onScroll);
    _fetch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _serverController.dispose();
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

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _fetch);
  }

  Future<void> _fetch({bool append = false}) async {
    final version = ++_fetchVersion;
    setState(() => _loading = true);
    try {
      final term = _searchController.text.trim();
      final server = _serverController.text.trim();
      final response = await widget.client.queryPublicRooms(
        server: server.isEmpty ? null : server,
        filter: term.isEmpty
            ? null
            : PublicRoomQueryFilter(genericSearchTerm: term),
        limit: 30,
        since: append ? _nextBatch : null,
      );
      if (!mounted || version != _fetchVersion) return;
      setState(() {
        if (!append) _rooms.clear();
        _rooms.addAll(response.chunk);
        _nextBatch = response.nextBatch;
      });
    } catch (e) {
      if (mounted && version == _fetchVersion) {
        if (!append) setState(() => _rooms.clear());
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted && version == _fetchVersion) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _join(PublishedRoomsChunk chunk) async {
    setState(() => _joiningRoomId = chunk.roomId);
    try {
      final roomId = await widget.client.joinRoom(
        chunk.canonicalAlias ?? chunk.roomId,
      );
      if (!mounted) return;
      final room = widget.client.getRoomById(roomId);
      final navigator = Navigator.of(context);
      navigator.pop();
      if (room != null) {
        navigator.push(MaterialPageRoute(builder: (_) => RoomPage(room: room)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _joiningRoomId = null);
      }
    }
  }

  Future<void> _knock(PublishedRoomsChunk chunk) async {
    setState(() => _joiningRoomId = chunk.roomId);
    try {
      await widget.client.knockRoom(chunk.canonicalAlias ?? chunk.roomId);
      if (!mounted) return;
      setState(() {
        _joiningRoomId = null;
        _knocked.add(chunk.roomId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.knockedWaitingForApproval)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _joiningRoomId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final joinedRoomIds = widget.client.rooms.map((room) => room.id).toSet();
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
                  Text(
                    context.l10n.exploreRooms,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: context.l10n.close,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: context.l10n.searchRoomsHint,
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: _onChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _serverController,
                      decoration: InputDecoration(
                        labelText: context.l10n.server,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _fetch(),
                    ),
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
                          : Text(context.l10n.noPublicRoomsFound),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _rooms.length,
                      itemBuilder: (context, index) {
                        final chunk = _rooms[index];
                        final name =
                            chunk.name ?? chunk.canonicalAlias ?? chunk.roomId;
                        final joined = joinedRoomIds.contains(chunk.roomId);
                        return ListTile(
                          leading: MxcAvatar(
                            client: widget.client,
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
                          trailing: joined
                              ? Text(context.l10n.joined)
                              : _joiningRoomId == chunk.roomId
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : _knocked.contains(chunk.roomId)
                              ? Text(context.l10n.knocked)
                              : chunk.joinRule == 'knock'
                              ? OutlinedButton(
                                  onPressed: _joiningRoomId != null
                                      ? null
                                      : () => _knock(chunk),
                                  child: Text(context.l10n.knock),
                                )
                              : FilledButton(
                                  onPressed: _joiningRoomId != null
                                      ? null
                                      : () => _join(chunk),
                                  child: Text(context.l10n.join),
                                ),
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
