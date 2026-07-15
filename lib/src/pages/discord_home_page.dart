import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../client_manager.dart';
import '../l10n.dart';
import '../room_actions.dart';
import '../settings.dart';
import '../widgets/account_switcher.dart';
import '../widgets/mxc_avatar.dart';
import '../widgets/new_chat_dialog.dart';
import '../widgets/pinned_rooms_section.dart';
import '../widgets/presence_indicator.dart';
import '../widgets/room_directory_dialog.dart';
import '../widgets/room_settings_dialog.dart';
import '../widgets/space_lobby_dialog.dart';
import '../widgets/user_banner.dart';
import '../widgets/user_profile_card.dart';
import 'room_page.dart';
import 'settings_page.dart';

/// Discord-style home: a vertical spaces rail, a channel list for the
/// selected space and — on wide screens — the chat pane next to it.
class DiscordHomePage extends StatefulWidget {
  const DiscordHomePage({
    super.key,
    required this.client,
    required this.manager,
    required this.settings,
  });

  final Client client;
  final ClientManager manager;
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

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  Future<void> _openRoom(Room room) async {
    if (!await confirmRoomTap(context, room)) return;
    if (!mounted) return;
    setState(() => _selectedRoomId = room.id);
    // Close the drawer when navigating on a narrow window.
    final scaffold = _scaffoldKey.currentState;
    if (scaffold?.isDrawerOpen ?? false) scaffold!.closeDrawer();
    if (scaffold?.isEndDrawerOpen ?? false) scaffold!.closeEndDrawer();
  }

  void _openMenu() {
    final scaffold = _scaffoldKey.currentState;
    if (widget.settings.railPosition == RailPosition.left) {
      scaffold?.openDrawer();
    } else {
      scaffold?.openEndDrawer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncUpdate>(
      stream: _client.onSync.stream,
      builder: (context, _) {
        final wide = MediaQuery.sizeOf(context).width >= 900;
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
        final selectedSpace = _selectedSpaceId == null
            ? null
            : _client.getRoomById(_selectedSpaceId!);
        final channels = _ChannelColumn(
          client: _client,
          manager: widget.manager,
          settings: widget.settings,
          title: _selectedSpaceId == null
              ? context.l10n.home
              : selectedSpace?.getLocalizedDisplayname() ?? context.l10n.space,
          space: selectedSpace,
          rooms: _roomsForSelection(),
          selectedRoomId: _selectedRoomId,
          onRoomTap: _openRoom,
          fillWidth: !wide,
        );

        if (wide) {
          // Wide window: the navigation stays open next to the chat.
          final chat = Expanded(
            child: selectedRoom == null
                ? const _NoRoomSelected()
                : RoomPage(key: ValueKey(selectedRoom.id), room: selectedRoom),
          );
          final children = [rail, channels, chat];
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: widget.settings.railPosition == RailPosition.left
                    ? children
                    : children.reversed.toList(),
              ),
            ),
          );
        }

        // Narrow window: the navigation moves into a drawer behind a
        // hamburger menu.
        final drawer = Drawer(
          width: 352,
          child: SafeArea(child: Row(children: [rail, channels])),
        );
        final leftRail = widget.settings.railPosition == RailPosition.left;
        return Scaffold(
          key: _scaffoldKey,
          drawer: leftRail ? drawer : null,
          endDrawer: leftRail ? null : drawer,
          appBar: selectedRoom == null
              ? AppBar(title: const Text('Protea'))
              : null,
          body: SafeArea(
            child: selectedRoom == null
                ? const _NoRoomSelected()
                : RoomPage(
                    key: ValueKey(selectedRoom.id),
                    room: selectedRoom,
                    onOpenMenu: _openMenu,
                  ),
          ),
        );
      },
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

  Future<void> _showSpaceMenu(
    BuildContext context,
    Room space,
    Offset position,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      items: [
        PopupMenuItem(value: 'lobby', child: Text(context.l10n.spaceLobby)),
        PopupMenuItem(
          value: 'settings',
          child: Text(context.l10n.spaceSettings),
        ),
        if (space.canInvite)
          PopupMenuItem(
            value: 'invite',
            child: Text(context.l10n.inviteToSpace),
          ),
      ],
    );
    if (selected == null || !context.mounted) return;
    switch (selected) {
      case 'lobby':
        await showSpaceLobby(context, space);
      case 'settings':
        await showRoomSettingsDialog(context, space);
      case 'invite':
        await showInviteDialog(context, space);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Material (not a plain colored box) so descendant ink splashes render.
    return Material(
      color: colorScheme.surfaceContainerLowest,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _RailButton(
                    selected: selectedSpaceId == null,
                    tooltip: context.l10n.home,
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
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      child: Divider(height: 1),
                    ),
                  for (final space in spaces)
                    GestureDetector(
                      onSecondaryTapUp: (details) => _showSpaceMenu(
                        context,
                        space,
                        details.globalPosition,
                      ),
                      onLongPressStart: (details) => _showSpaceMenu(
                        context,
                        space,
                        details.globalPosition,
                      ),
                      child: _RailButton(
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
                    ),
                ],
              ),
            ),
          ],
        ),
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
    required this.manager,
    required this.settings,
    required this.title,
    required this.space,
    required this.rooms,
    required this.selectedRoomId,
    required this.onRoomTap,
    required this.fillWidth,
  });

  final Client client;
  final ClientManager manager;
  final AppSettings settings;
  final String title;

  /// The selected space, or null in the "Home" section.
  final Room? space;
  final List<Room> rooms;
  final String? selectedRoomId;
  final void Function(Room room) onRoomTap;

  /// On narrow screens the channel column takes all remaining width.
  final bool fillWidth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Material (not a plain colored box) so the ListTiles' ink and selection
    // backgrounds render on top of this color instead of underneath it.
    final column = Material(
      color: colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.only(left: 16, right: 4),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (space != null)
                  IconButton(
                    tooltip: context.l10n.spaceLobby,
                    icon: const Icon(Icons.travel_explore_outlined, size: 20),
                    onPressed: () => showSpaceLobby(context, space!),
                  ),
                IconButton(
                  tooltip: context.l10n.explorePublicRooms,
                  icon: const Icon(Icons.explore_outlined, size: 20),
                  onPressed: () => showRoomDirectory(context, client),
                ),
                IconButton(
                  tooltip: context.l10n.newChat,
                  icon: const Icon(Icons.add_comment_outlined, size: 20),
                  onPressed: () => showNewChatDialog(context, client),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: rooms.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(context.l10n.noRoomsHereYet),
                    ),
                  )
                : Builder(
                    builder: (context) {
                      final pinned = pinnedRooms(rooms);
                      final pinnedIds = pinned.map((room) => room.id).toSet();
                      final directs = rooms
                          .where(
                            (room) =>
                                room.isDirectChat &&
                                !pinnedIds.contains(room.id),
                          )
                          .toList();
                      final channels = rooms
                          .where(
                            (room) =>
                                !room.isDirectChat &&
                                !pinnedIds.contains(room.id),
                          )
                          .toList();
                      Widget tile(Room room) => _ChannelTile(
                        room: room,
                        selected: room.id == selectedRoomId,
                        onTap: () => onRoomTap(room),
                      );
                      return ListView(
                        children: [
                          if (pinned.isNotEmpty) ...[
                            PinnedRoomsSection(
                              pinned: pinned,
                              tileBuilder: tile,
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (directs.isNotEmpty) ...[
                            _SectionLabel(context.l10n.directMessages),
                            for (final room in directs) tile(room),
                          ],
                          if (directs.isNotEmpty && channels.isNotEmpty)
                            const SizedBox(height: 16),
                          if (channels.isNotEmpty) ...[
                            _SectionLabel(context.l10n.channels),
                            for (final room in channels) tile(room),
                          ],
                        ],
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          _UserFooter(client: client, manager: manager, settings: settings),
        ],
      ),
    );
    return fillWidth
        ? Expanded(child: column)
        : SizedBox(width: 280, child: column);
  }
}

/// Small uppercase category label above a group of rooms.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
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

  Future<void> _showContextMenu(BuildContext context, Offset position) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'pin',
          child: Text(room.isFavourite ? context.l10n.unpin : context.l10n.pin),
        ),
        PopupMenuItem(value: 'settings', child: Text(context.l10n.settings)),
        if (room.canInvite)
          PopupMenuItem(value: 'invite', child: Text(context.l10n.invite)),
        PopupMenuItem(value: 'leave', child: Text(context.l10n.leave)),
      ],
    );
    if (selected == null || !context.mounted) return;
    switch (selected) {
      case 'pin':
        try {
          await togglePinned(room);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(e.toString())));
          }
        }
      case 'settings':
        await showRoomSettingsDialog(context, room);
      case 'invite':
        await showInviteDialog(context, room);
      case 'leave':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.leaveRoom),
            content: Text(
              context.l10n.youWillNoLongerSee(room.getLocalizedDisplayname()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.l10n.leave),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        try {
          await room.leave();
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(e.toString())));
          }
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInvite = room.membership == Membership.invite;
    final isKnock = room.membership == Membership.knock;
    final directUserId = room.directChatMatrixID;
    Widget tile = ListTile(
      dense: true,
      selected: selected,
      leading: directUserId != null
          ? PresenceAvatar(
              client: room.client,
              userId: directUserId,
              name: room.getLocalizedDisplayname(),
              avatarUrl: room.avatar,
              radius: 12,
            )
          : Icon(
              isInvite
                  ? Icons.mail_outline
                  : isKnock
                  ? Icons.hourglass_top
                  : Icons.tag,
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
    if (directUserId != null) {
      tile = UserBannerBackground(
        client: room.client,
        userId: directUserId,
        child: tile,
      );
    }
    return GestureDetector(
      onSecondaryTapUp: (details) =>
          _showContextMenu(context, details.globalPosition),
      onLongPressStart: (details) =>
          _showContextMenu(context, details.globalPosition),
      child: tile,
    );
  }
}

class _UserFooter extends StatelessWidget {
  const _UserFooter({
    required this.client,
    required this.manager,
    required this.settings,
  });

  final Client client;
  final ClientManager manager;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final userId = client.userID ?? '?';
    final footer = Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          FutureBuilder<Profile>(
            future: client.fetchOwnProfile(),
            builder: (context, snapshot) => GestureDetector(
              onTap: () => showUserProfileCard(
                context,
                client: client,
                userId: userId,
                displayName: snapshot.data?.displayName,
                avatarUrl: snapshot.data?.avatarUrl,
              ),
              child: PresenceAvatar(
                client: client,
                userId: userId,
                name: snapshot.data?.displayName ?? userId,
                avatarUrl: snapshot.data?.avatarUrl,
                radius: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userId.replaceFirst('@', '').split(':').first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                UserStatusText(
                  client: client,
                  userId: userId,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.l10n.switchAccount,
            icon: const Icon(Icons.swap_horiz, size: 20),
            onPressed: () => showAccountSwitcher(context, manager),
          ),
          IconButton(
            tooltip: context.l10n.settings,
            icon: const Icon(Icons.settings_outlined, size: 20),
            onPressed: () =>
                showSettingsDialog(context, client: client, settings: settings),
          ),
        ],
      ),
    );
    if (client.userID == null) return footer;
    return UserBannerBackground(
      client: client,
      userId: client.userID!,
      child: footer,
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
            Text(context.l10n.selectChannelToStartChatting),
          ],
        ),
      ),
    );
  }
}
