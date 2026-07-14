import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../room_actions.dart';
import '../settings.dart';
import '../widgets/mxc_avatar.dart';
import '../widgets/presence_indicator.dart';
import 'room_page.dart';
import 'settings_page.dart';

/// Discord-style home: a vertical spaces rail, a channel list for the
/// selected space and — on wide screens — the chat pane next to it.
class DiscordHomePage extends StatefulWidget {
  const DiscordHomePage({
    super.key,
    required this.client,
    required this.settings,
  });

  final Client client;
  final AppSettings settings;

  @override
  State<DiscordHomePage> createState() => _DiscordHomePageState();
}

class _DiscordHomePageState extends State<DiscordHomePage> {
  /// Selected space id, or null for the "Home" section (DMs and rooms that
  /// are not part of any joined space).
  String? _selectedSpaceId;
  String? _selectedRoomId;

  Client get _client => widget.client;

  List<Room> get _spaces =>
      _client.rooms.where((room) => room.isSpace).toList();

  /// All room ids referenced as a child by any joined space.
  Set<String> get _roomIdsInSpaces => {
        for (final space in _spaces)
          for (final child in space.spaceChildren)
            if (child.roomId != null) child.roomId!,
      };

  List<Room> _roomsForSelection() {
    final spaceId = _selectedSpaceId;
    if (spaceId == null) {
      final inSpaces = _roomIdsInSpaces;
      return _client.rooms
          .where((room) => !room.isSpace && !inSpaces.contains(room.id))
          .toList();
    }
    final space = _client.getRoomById(spaceId);
    if (space == null) return [];
    return space.spaceChildren
        .map((child) => child.roomId)
        .nonNulls
        .map(_client.getRoomById)
        .nonNulls
        .where((room) => !room.isSpace)
        .toList();
  }

  Future<void> _openRoom(Room room, bool wideScreen) async {
    if (!await confirmRoomTap(context, room)) return;
    if (!mounted) return;
    if (wideScreen) {
      setState(() => _selectedRoomId = room.id);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RoomPage(room: room)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<SyncUpdate>(
          stream: _client.onSync.stream,
          builder: (context, _) => LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final selectedRoom = _selectedRoomId == null
                  ? null
                  : _client.getRoomById(_selectedRoomId!);

              final rail = _SpaceRail(
                spaces: _spaces,
                selectedSpaceId: _selectedSpaceId,
                onSelect: (spaceId) => setState(() {
                  _selectedSpaceId = spaceId;
                  _selectedRoomId = null;
                }),
              );
              final channels = _ChannelColumn(
                client: _client,
                settings: widget.settings,
                title: _selectedSpaceId == null
                    ? 'Home'
                    : _client
                            .getRoomById(_selectedSpaceId!)
                            ?.getLocalizedDisplayname() ??
                        'Space',
                rooms: _roomsForSelection(),
                selectedRoomId: wide ? _selectedRoomId : null,
                onRoomTap: (room) => _openRoom(room, wide),
                fillWidth: !wide,
              );
              final chat = wide
                  ? Expanded(
                      child: selectedRoom == null
                          ? const _NoRoomSelected()
                          : RoomPage(
                              key: ValueKey(selectedRoom.id),
                              room: selectedRoom,
                            ),
                    )
                  : null;

              final children = [rail, channels, ?chat];
              return Row(
                children: widget.settings.railPosition == RailPosition.left
                    ? children
                    : children.reversed.toList(),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SpaceRail extends StatelessWidget {
  const _SpaceRail({
    required this.spaces,
    required this.selectedSpaceId,
    required this.onSelect,
  });

  final List<Room> spaces;
  final String? selectedSpaceId;
  final void Function(String? spaceId) onSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 72,
      color: colorScheme.surfaceContainerLowest,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _RailButton(
                  selected: selectedSpaceId == null,
                  tooltip: 'Home',
                  onTap: () => onSelect(null),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: selectedSpaceId == null
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.home,
                      color: selectedSpaceId == null
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
                if (spaces.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Divider(height: 1),
                  ),
                for (final space in spaces)
                  _RailButton(
                    selected: selectedSpaceId == space.id,
                    tooltip: space.getLocalizedDisplayname(),
                    unread: space.spaceChildren.any((child) {
                      final room = child.roomId == null
                          ? null
                          : space.client.getRoomById(child.roomId!);
                      return room?.isUnreadOrInvited ?? false;
                    }),
                    onTap: () => onSelect(space.id),
                    child: MxcAvatar(
                      client: space.client,
                      name: space.getLocalizedDisplayname(),
                      avatarUrl: space.avatar,
                      radius: 24,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.selected,
    required this.tooltip,
    required this.onTap,
    required this.child,
    this.unread = false,
  });

  final bool selected;
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Discord-style selection pill on the side of the rail.
              Positioned(
                left: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 4,
                  height: selected ? 36 : (unread ? 8 : 0),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelColumn extends StatelessWidget {
  const _ChannelColumn({
    required this.client,
    required this.settings,
    required this.title,
    required this.rooms,
    required this.selectedRoomId,
    required this.onRoomTap,
    required this.fillWidth,
  });

  final Client client;
  final AppSettings settings;
  final String title;
  final List<Room> rooms;
  final String? selectedRoomId;
  final void Function(Room room) onRoomTap;

  /// On narrow screens the channel column takes all remaining width.
  final bool fillWidth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final column = Container(
      color: colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: rooms.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No rooms here yet.'),
                    ),
                  )
                : ListView.builder(
                    itemCount: rooms.length,
                    itemBuilder: (context, index) {
                      final room = rooms[index];
                      return _ChannelTile(
                        room: room,
                        selected: room.id == selectedRoomId,
                        onTap: () => onRoomTap(room),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          _UserFooter(client: client, settings: settings),
        ],
      ),
    );
    return fillWidth
        ? Expanded(child: column)
        : SizedBox(width: 280, child: column);
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.room,
    required this.selected,
    required this.onTap,
  });

  final Room room;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isInvite = room.membership == Membership.invite;
    final directUserId = room.directChatMatrixID;
    return ListTile(
      dense: true,
      selected: selected,
      leading: directUserId != null
          ? SizedBox(
              width: 20,
              height: 20,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.person_outline, size: 20),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: PresenceDot(
                      client: room.client,
                      userId: directUserId,
                      size: 9,
                    ),
                  ),
                ],
              ),
            )
          : Icon(
              isInvite ? Icons.mail_outline : Icons.tag,
              size: 20,
            ),
      title: Text(
        room.getLocalizedDisplayname(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: room.isUnreadOrInvited
            ? const TextStyle(fontWeight: FontWeight.bold)
            : null,
      ),
      trailing: room.notificationCount > 0
          ? Badge(label: Text(room.notificationCount.toString()))
          : isInvite
              ? const Badge(label: Text('!'))
              : null,
      onTap: onTap,
    );
  }
}

class _UserFooter extends StatelessWidget {
  const _UserFooter({required this.client, required this.settings});

  final Client client;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final userId = client.userID ?? '?';
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          FutureBuilder<Profile>(
            future: client.fetchOwnProfile(),
            builder: (context, snapshot) => PresenceAvatar(
              client: client,
              userId: userId,
              name: snapshot.data?.displayName ?? userId,
              avatarUrl: snapshot.data?.avatarUrl,
              radius: 16,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              userId.replaceFirst('@', '').split(':').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined, size: 20),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    SettingsPage(client: client, settings: settings),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoRoomSelected extends StatelessWidget {
  const _NoRoomSelected();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            const Text('Select a channel to start chatting.'),
          ],
        ),
      ),
    );
  }
}
