import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../channel_groups.dart';
import '../client_manager.dart';
import '../l10n.dart';
import '../motion.dart';
import '../nicknames.dart';
import '../room_actions.dart';
import '../room_navigator.dart';
import '../settings.dart';
import '../themes.dart';
import '../widgets/account_switcher.dart';
import '../widgets/global_search_dialog.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/mxc_avatar.dart';
import '../widgets/new_chat_dialog.dart';
import '../widgets/new_space_dialog.dart';
import '../widgets/nickname_dialog.dart';
import '../widgets/pinned_rooms_section.dart';
import '../widgets/presence_indicator.dart';
import '../widgets/quick_switcher.dart';
import '../widgets/requests_section.dart';
import '../widgets/room_directory_dialog.dart';
import '../widgets/room_settings_dialog.dart';
import '../widgets/room_banner.dart';
import '../widgets/space_lobby_dialog.dart';
import '../widgets/text_prompt_dialog.dart';
import '../widgets/user_banner.dart';
import '../widgets/user_profile_card.dart';
import 'room_page.dart';
import 'settings_page.dart';

/// A space child's fields relevant for ordering (the SDK's SpaceChild type
/// is not exported).
typedef _ChildEntry = ({
  String roomId,
  String order,
  List<String> via,
  bool? suggested,
});

/// Children of [space] sorted per spec: explicit `order` strings first
/// (lexicographic), children without an order after them, original state
/// order as the stable tie-breaker.
List<_ChildEntry> _sortedSpaceChildren(Room space) {
  final children = [
    for (final child in space.spaceChildren)
      if (child.roomId != null)
        (
          roomId: child.roomId!,
          order: child.order,
          via: child.via,
          suggested: child.suggested,
        ),
  ];
  final indexed = children.asMap().entries.toList();
  indexed.sort((a, b) {
    final orderA = a.value.order;
    final orderB = b.value.order;
    if (orderA.isEmpty && orderB.isEmpty) return a.key.compareTo(b.key);
    if (orderA.isEmpty) return 1;
    if (orderB.isEmpty) return -1;
    final compared = orderA.compareTo(orderB);
    return compared != 0 ? compared : a.key.compareTo(b.key);
  });
  return indexed.map((entry) => entry.value).toList();
}

/// Payload of a channel drag.
class _ChannelDrag {
  const _ChannelDrag({required this.room});

  final Room room;
}

/// Discord-style home: a vertical spaces rail, a channel list for the
/// selected space and — on wide screens — the chat pane next to it.
class DiscordHomePage extends StatefulWidget {
  const DiscordHomePage({
    super.key,
    required this.client,
    required this.manager,
    required this.settings,
    this.layout = AppLayout.workspace,
  });

  final Client client;
  final ClientManager manager;
  final AppSettings settings;

  /// How the panes are arranged and dressed (see [AppLayout]).
  final AppLayout layout;

  @override
  State<DiscordHomePage> createState() => _DiscordHomePageState();
}

class _DiscordHomePageState extends State<DiscordHomePage> {
  /// Selected space id, or null for the "Home" section (DMs and rooms that
  /// are not part of any joined space).
  String? _selectedSpaceId;
  String? _selectedRoomId;

  Client get _client => widget.client;

  /// Joined spaces; invitations to spaces wait in the Home requests.
  List<Room> get _spaces => applyOrder(
    _client.rooms
        .where((room) => room.isSpace && room.membership == Membership.join)
        .toList(),
    spaceOrderOf(_client),
    (room) => room.id,
  );

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
          .where(
            (room) =>
                !room.isSpace &&
                !inSpaces.contains(room.id) &&
                !isOpenRequest(room),
          )
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

  @override
  void initState() {
    super.initState();
    RoomNavigator.instance.addListener(_onRoomRequested);
  }

  @override
  void dispose() {
    RoomNavigator.instance.removeListener(_onRoomRequested);
    super.dispose();
  }

  /// Selects a room requested from elsewhere (profile card "Message"), in
  /// its space or the Home section.
  void _onRoomRequested() {
    final roomId = RoomNavigator.instance.roomId;
    if (roomId == null) return;
    // The room may not have arrived through sync yet (freshly created DM);
    // select it anyway — the chat pane fills in as soon as it lands.
    String? spaceId;
    for (final space in _spaces) {
      if (space.spaceChildren.any((child) => child.roomId == roomId)) {
        spaceId = space.id;
        break;
      }
    }
    setState(() {
      _selectedSpaceId = spaceId;
      _selectedRoomId = roomId;
    });
    _rememberRoom(roomId);
  }

  /// Switches to [spaceId] (null for Home), reopening the channel last
  /// opened there.
  void _selectSpace(String? spaceId) {
    final lastRoomId = widget.settings.lastRoomFor(_client.clientName, spaceId);
    setState(() {
      _selectedSpaceId = spaceId;
      _selectedRoomId = lastRoomId != null && _isChannelIn(spaceId, lastRoomId)
          ? lastRoomId
          : null;
    });
  }

  /// Records [roomId] as the selected space's last opened channel — unless
  /// it isn't one of that space's channels (a pinned room from elsewhere),
  /// which would otherwise replace the space's own.
  void _rememberRoom(String roomId) {
    if (!_isChannelIn(_selectedSpaceId, roomId)) return;
    widget.settings.setLastRoomFor(
      _client.clientName,
      _selectedSpaceId,
      roomId,
    );
  }

  /// Whether [roomId] is a joined channel listed under [spaceId]: a room of
  /// the space itself or of one of its sub-space categories, or for Home
  /// (null) a room outside every space.
  bool _isChannelIn(String? spaceId, String roomId) {
    final room = _client.getRoomById(roomId);
    if (room == null || room.isSpace || room.membership != Membership.join) {
      return false;
    }
    if (spaceId == null) return !_roomIdsInSpaces.contains(roomId);
    final space = _client.getRoomById(spaceId);
    if (space == null) return false;
    for (final child in space.spaceChildren) {
      if (child.roomId == roomId) return true;
      final category = child.roomId == null
          ? null
          : _client.getRoomById(child.roomId!);
      if (category != null &&
          category.isSpace &&
          category.spaceChildren.any((child) => child.roomId == roomId)) {
        return true;
      }
    }
    return false;
  }

  /// Category (sub-space) ids collapsed in the channel list this session.
  final _collapsedCategories = <String>{};

  void _toggleCategory(String spaceId) {
    setState(() {
      _collapsedCategories.contains(spaceId)
          ? _collapsedCategories.remove(spaceId)
          : _collapsedCategories.add(spaceId);
    });
  }

  /// Persists the per-user channel groups and ungrouped order for the
  /// current scope (selected space or Home), VirtualChat-compatible.
  Future<void> _saveLayout(
    List<ChannelGroup> groups,
    List<String> ungroupedOrder,
  ) async {
    setState(() {});
    try {
      await saveChannelGroups(_client, _selectedSpaceId, groups);
      await saveChannelOrder(_client, _selectedSpaceId, ungroupedOrder);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _createGroup() async {
    final name = await showTextPromptDialog(
      context,
      title: context.l10n.newGroup,
      label: context.l10n.groupName,
      confirmLabel: context.l10n.create,
    );
    if (name == null || name.isEmpty || !mounted) return;
    final groups = channelGroupsFor(_client, _selectedSpaceId)
      ..add(ChannelGroup(id: newGroupId(), name: name, roomIds: []));
    await _saveLayout(groups, channelOrderFor(_client, _selectedSpaceId));
  }

  Future<void> _renameGroup(ChannelGroup group) async {
    final name = await showTextPromptDialog(
      context,
      title: context.l10n.rename,
      label: context.l10n.groupName,
      initial: group.name,
    );
    if (name == null || name.isEmpty || !mounted) return;
    final groups = channelGroupsFor(_client, _selectedSpaceId);
    for (final candidate in groups) {
      if (candidate.id == group.id) candidate.name = name;
    }
    await _saveLayout(groups, channelOrderFor(_client, _selectedSpaceId));
  }

  /// Deletes [group]; its channels return to the ungrouped section.
  Future<void> _deleteGroup(ChannelGroup group) async {
    final groups = channelGroupsFor(_client, _selectedSpaceId)
      ..removeWhere((candidate) => candidate.id == group.id);
    await _saveLayout(groups, channelOrderFor(_client, _selectedSpaceId));
  }

  /// Reorders the spaces rail: [dragged] is inserted before [beforeSpaceId]
  /// (or appended), persisted per user like VirtualChat.
  Future<void> _moveSpace(Room dragged, String? beforeSpaceId) async {
    final ids = [
      for (final space in _spaces)
        if (space.id != dragged.id) space.id,
    ];
    var insertAt = beforeSpaceId == null
        ? ids.length
        : ids.indexOf(beforeSpaceId);
    if (insertAt < 0) insertAt = ids.length;
    ids.insert(insertAt, dragged.id);
    setState(() {});
    try {
      await saveSpaceOrder(_client, ids);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  /// Hierarchy chunks per space, fetched once through the hierarchy API —
  /// the same data the space lobby shows, reused for the "Not joined"
  /// section.
  final _hierarchy = <String, List<SpaceRoomsChunk$2>>{};
  final _hierarchyInFlight = <String>{};

  void _ensureHierarchy(Room space) {
    if (_hierarchy.containsKey(space.id) || !_hierarchyInFlight.add(space.id)) {
      return;
    }
    () async {
      final chunks = <SpaceRoomsChunk$2>[];
      try {
        String? from;
        // Paginate a few pages; enough for even large spaces.
        for (var page = 0; page < 5; page++) {
          final response = await _client.getSpaceHierarchy(
            space.id,
            limit: 100,
            from: from,
          );
          chunks.addAll(response.rooms);
          from = response.nextBatch;
          if (from == null) break;
        }
      } catch (_) {
        // Keep whatever was collected.
      } finally {
        _hierarchy[space.id] = chunks;
        _hierarchyInFlight.remove(space.id);
      }
      if (mounted) setState(() {});
    }();
  }

  Future<void> _openRoom(Room room) async {
    if (!await confirmRoomTap(context, room)) return;
    _showRoom(room);
  }

  /// Shows an opened or just-joined room: its chat, or for a space accepted
  /// from the requests, the space itself.
  void _showRoom(Room room) {
    if (!mounted) return;
    if (room.isSpace) {
      _selectSpace(room.id);
      return;
    }
    setState(() => _selectedRoomId = room.id);
    _rememberRoom(room.id);
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
        // Focus keeps the chat alone on screen with the navigation in the
        // drawer, even on wide windows.
        final splitView = wide && widget.layout != AppLayout.focus;
        final liquid = widget.layout == AppLayout.liquid;
        final selectedRoom = _selectedRoomId == null
            ? null
            : _client.getRoomById(_selectedRoomId!);

        final rail = _SpaceRail(
          client: _client,
          liquid: liquid,
          spaces: _spaces,
          selectedSpaceId: _selectedSpaceId,
          onSelect: _selectSpace,
          onReorder: _moveSpace,
        );
        final selectedSpace = _selectedSpaceId == null
            ? null
            : _client.getRoomById(_selectedSpaceId!);
        final channels = _ChannelColumn(
          client: _client,
          liquid: liquid,
          manager: widget.manager,
          settings: widget.settings,
          title: _selectedSpaceId == null
              ? context.l10n.home
              : selectedSpace?.nickOrDisplayname ?? context.l10n.space,
          space: selectedSpace,
          rooms: _roomsForSelection(),
          selectedRoomId: _selectedRoomId,
          onRoomTap: _openRoom,
          onRequestJoined: _showRoom,
          fillWidth: !splitView,
          collapsedCategories: _collapsedCategories,
          onToggleCategory: _toggleCategory,
          onSaveLayout: _saveLayout,
          onCreateGroup: _createGroup,
          onRenameGroup: _renameGroup,
          onDeleteGroup: _deleteGroup,
          hierarchyRooms: selectedSpace == null
              ? const []
              : _hierarchy[selectedSpace.id] ?? const [],
        );
        if (selectedSpace != null) _ensureHierarchy(selectedSpace);

        if (splitView) {
          // Wide window: the navigation stays open next to the chat.
          if (liquid) {
            final colorScheme = Theme.of(context).colorScheme;
            final chatChild = PaneSwitcher(
              child: selectedRoom == null
                  ? const _NoRoomSelected(liquid: true)
                  : Theme(
                      key: ValueKey(selectedRoom.id),
                      // A translucent scaffold lets the gradient glow through
                      // the chat pane.
                      data: Theme.of(context).copyWith(
                        scaffoldBackgroundColor: colorScheme.surface.withValues(
                          alpha: 0.55,
                        ),
                      ),
                      child: RoomPage(room: selectedRoom),
                    ),
            );
            final panels = [
              _GlassPanel(child: rail),
              const SizedBox(width: 10),
              _GlassPanel(child: channels),
              const SizedBox(width: 10),
              Expanded(child: _GlassPanel(child: chatChild)),
            ];
            // OLED keeps its pure black behind the panels whatever the
            // settings say: a glow in the corners is the one thing that
            // theme exists to avoid.
            final oled = widget.settings.appTheme == AppTheme.oled;
            return Scaffold(
              body: Container(
                decoration: liquidBackdrop(
                  colorScheme,
                  oled ? null : widget.settings.appBackgroundColor,
                  widget.settings.appBackgroundFade,
                  glow: widget.settings.backgroundGlow && !oled,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children:
                          widget.settings.railPosition == RailPosition.left
                          ? panels
                          : panels.reversed.toList(),
                    ),
                  ),
                ),
              ),
            );
          }
          if (widget.layout == AppLayout.floating) {
            // Discord's refreshed look: rail and channel list stay docked
            // like the workspace; only the chat floats as a rounded card
            // on the sidebar background.
            final chat = Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _FloatingPanel(
                  child: PaneSwitcher(
                    child: selectedRoom == null
                        ? const _NoRoomSelected()
                        : RoomPage(
                            key: ValueKey(selectedRoom.id),
                            room: selectedRoom,
                          ),
                  ),
                ),
              ),
            );
            final children = [rail, channels, chat];
            return Scaffold(
              body: Container(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: SafeArea(
                  child: Row(
                    children: widget.settings.railPosition == RailPosition.left
                        ? children
                        : children.reversed.toList(),
                  ),
                ),
              ),
            );
          }
          final chat = Expanded(
            child: PaneSwitcher(
              child: selectedRoom == null
                  ? const _NoRoomSelected()
                  : RoomPage(
                      key: ValueKey(selectedRoom.id),
                      room: selectedRoom,
                    ),
            ),
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

        // Narrow window (or the Focus layout): the navigation moves into a
        // drawer behind a hamburger menu.
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
            child: PaneSwitcher(
              child: selectedRoom == null
                  ? const _NoRoomSelected()
                  : RoomPage(
                      key: ValueKey(selectedRoom.id),
                      room: selectedRoom,
                      onOpenMenu: _openMenu,
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _SpaceRail extends StatelessWidget {
  const _SpaceRail({
    required this.client,
    required this.spaces,
    required this.selectedSpaceId,
    required this.onSelect,
    required this.onReorder,
    this.liquid = false,
  });

  final Client client;
  final bool liquid;
  final List<Room> spaces;
  final String? selectedSpaceId;
  final void Function(String? spaceId) onSelect;
  final void Function(Room dragged, String? beforeSpaceId) onReorder;

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

  /// Unread notification total of all joined rooms inside [space],
  /// including one level of sub-spaces.
  int _spaceNotificationCount(Room space) {
    var count = 0;
    for (final child in _sortedSpaceChildren(space)) {
      final room = client.getRoomById(child.roomId);
      if (room == null) continue;
      if (room.isSpace) {
        for (final grandChild in _sortedSpaceChildren(room)) {
          final grandRoom = client.getRoomById(grandChild.roomId);
          if (grandRoom != null && !grandRoom.isSpace) {
            count += grandRoom.unreadBadgeCount;
          }
        }
      } else {
        count += room.unreadBadgeCount;
      }
    }
    return count;
  }

  int _homeNotificationCount() {
    final inSpaces = <String>{
      for (final space in spaces)
        for (final child in space.spaceChildren)
          if (child.roomId != null) child.roomId!,
    };
    // Every invitation waits in the Home requests, wherever the room lives.
    var count = client.rooms
        .where((room) => room.membership == Membership.invite)
        .length;
    for (final room in client.rooms) {
      if (!room.isSpace && !inSpaces.contains(room.id)) {
        count += room.unreadBadgeCount;
      }
    }
    return count;
  }

  /// Wraps a space button so it can be dragged to reorder the rail and
  /// accepts other space buttons dropped onto it (inserted before).
  Widget _draggableSpace(BuildContext context, Room space, Widget button) {
    final colorScheme = Theme.of(context).colorScheme;
    return DragTarget<Room>(
      onWillAcceptWithDetails: (details) => details.data.id != space.id,
      onAcceptWithDetails: (details) => onReorder(details.data, space.id),
      builder: (context, candidates, _) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: candidates.isNotEmpty
                  ? colorScheme.primary
                  : Colors.transparent,
            ),
            Draggable<Room>(
              data: space,
              feedback: Material(
                color: Colors.transparent,
                child: Opacity(
                  opacity: 0.8,
                  child: MxcAvatar(
                    client: space.client,
                    name: space.nickOrDisplayname,
                    avatarUrl: space.avatar,
                    radius: 24,
                  ),
                ),
              ),
              childWhenDragging: Opacity(opacity: 0.35, child: button),
              child: button,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Material (not a plain colored box) so descendant ink splashes render.
    return Material(
      color: colorScheme.surfaceContainerLowest.withValues(
        alpha: liquid ? 0.4 : 1,
      ),
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
                    backgroundColor: selectedSpaceId == null
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    badgeCount: _homeNotificationCount(),
                    child: Icon(
                      Icons.home,
                      color: selectedSpaceId == null
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
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
                    _draggableSpace(
                      context,
                      space,
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
                          tooltip: space.nickOrDisplayname,
                          unread: space.spaceChildren.any((child) {
                            final room = child.roomId == null
                                ? null
                                : space.client.getRoomById(child.roomId!);
                            return room?.isUnreadOrInvited ?? false;
                          }),
                          onTap: () => onSelect(space.id),
                          badgeCount: _spaceNotificationCount(space),
                          child: _SquareAvatar(
                            client: space.client,
                            name: space.nickOrDisplayname,
                            avatarUrl: space.avatar,
                          ),
                        ),
                      ),
                    ),
                  // Dropping below the last space appends it to the end.
                  DragTarget<Room>(
                    onAcceptWithDetails: (details) =>
                        onReorder(details.data, null),
                    builder: (context, candidates, _) => Container(
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: candidates.isNotEmpty
                          ? colorScheme.primary.withValues(alpha: 0.4)
                          : Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Divider(height: 1),
            ),
            // Discord-style global actions at the bottom of the rail.
            _RailButton(
              selected: false,
              tooltip: context.l10n.searchAllRooms,
              onTap: () => showGlobalSearch(context, client),
              child: Icon(Icons.search, color: colorScheme.onSurface),
            ),
            _RailButton(
              selected: false,
              tooltip: context.l10n.newSpace,
              onTap: () => showNewSpaceDialog(context, client),
              child: Icon(Icons.add, color: colorScheme.onSurface),
            ),
            _RailButton(
              selected: false,
              tooltip: context.l10n.explorePublicRooms,
              onTap: () => showRoomDirectory(context, client),
              child: Icon(Icons.explore_outlined, color: colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// A 48x48 rail entry that morphs from a circle to a rounded square on
/// hover and while selected, Discord-style.
class _RailButton extends StatefulWidget {
  const _RailButton({
    required this.selected,
    required this.tooltip,
    required this.onTap,
    required this.child,
    this.backgroundColor,
    this.badgeCount = 0,
    this.unread = false,
  });

  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  /// Square content (icon or [_SquareAvatar]); the button clips it to the
  /// animated shape.
  final Widget child;
  final Color? backgroundColor;
  final int badgeCount;
  final bool unread;

  @override
  State<_RailButton> createState() => _RailButtonState();
}

class _RailButtonState extends State<_RailButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rounded = _hovered || widget.selected;
    final radius = BorderRadius.circular(rounded ? 14 : 24);
    // Material animates shape changes itself and hosts the ink, so hover
    // highlight and ripple stay clipped to the icon's morphing outline.
    final icon = SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: widget.backgroundColor ?? colorScheme.surfaceContainerHighest,
        animationDuration: const Duration(milliseconds: 150),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: radius),
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          onTap: widget.onTap,
          child: widget.child,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Tooltip(
        message: widget.tooltip,
        child: Stack(
          alignment: Alignment.center,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: Badge(
                isLabelVisible: widget.badgeCount > 0,
                label: Text(
                  widget.badgeCount > 99 ? '99+' : widget.badgeCount.toString(),
                ),
                offset: const Offset(-2, 2),
                child: icon,
              ),
            ),
            // Discord-style selection pill on the side of the rail,
            // painted above the icon so it stays visible.
            Positioned(
              left: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 4,
                height: widget.selected
                    ? 36
                    : _hovered
                    ? 20
                    : (widget.unread ? 8 : 0),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Square avatar image for the rail: fills its parent so the rail button's
/// animated clip defines the shape. Falls back to a colored initial.
class _SquareAvatar extends StatefulWidget {
  const _SquareAvatar({
    required this.client,
    required this.name,
    this.avatarUrl,
  });

  final Client client;
  final String name;
  final Uri? avatarUrl;

  @override
  State<_SquareAvatar> createState() => _SquareAvatarState();
}

class _SquareAvatarState extends State<_SquareAvatar> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_SquareAvatar oldWidget) {
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
      return Container(
        color: InitialsAvatar.colorFor(widget.name),
        alignment: Alignment.center,
        child: Text(
          widget.name.isEmpty
              ? '?'
              : widget.name.characters.first.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      );
    }
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }
}

class _ChannelColumn extends StatelessWidget {
  const _ChannelColumn({
    required this.client,
    required this.manager,
    required this.settings,
    this.liquid = false,
    required this.title,
    required this.space,
    required this.rooms,
    required this.selectedRoomId,
    required this.onRoomTap,
    required this.onRequestJoined,
    required this.fillWidth,
    required this.collapsedCategories,
    required this.onToggleCategory,
    required this.onSaveLayout,
    required this.onCreateGroup,
    required this.onRenameGroup,
    required this.onDeleteGroup,
    required this.hierarchyRooms,
  });

  final Client client;
  final ClientManager manager;
  final AppSettings settings;
  final bool liquid;
  final String title;

  /// The selected space, or null in the "Home" section.
  final Room? space;

  /// Collapsed group and category (sub-space) ids.
  final Set<String> collapsedCategories;
  final void Function(String id) onToggleCategory;

  /// Persists the scope's groups and ungrouped channel order.
  final void Function(List<ChannelGroup> groups, List<String> ungroupedOrder)
  onSaveLayout;
  final VoidCallback onCreateGroup;
  final void Function(ChannelGroup group) onRenameGroup;
  final void Function(ChannelGroup group) onDeleteGroup;

  /// The space's hierarchy (lobby data), for the "Not joined" section.
  final List<SpaceRoomsChunk$2> hierarchyRooms;
  final List<Room> rooms;
  final String? selectedRoomId;
  final void Function(Room room) onRoomTap;

  /// Shows a room or space whose invitation was accepted inline.
  final void Function(Room room) onRequestJoined;

  /// On narrow screens the channel column takes all remaining width.
  final bool fillWidth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Material (not a plain colored box) so the ListTiles' ink and selection
    // backgrounds render on top of this color instead of underneath it.
    final column = Material(
      color: colorScheme.surfaceContainerLow.withValues(
        alpha: liquid ? 0.5 : 1,
      ),
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
                if (space == null)
                  IconButton(
                    tooltip: context.l10n.startChat,
                    icon: const Icon(Icons.add_comment_outlined, size: 20),
                    onPressed: () => showNewChatDialog(context, client),
                  ),
                if (space != null)
                  IconButton(
                    tooltip: context.l10n.members,
                    icon: const Icon(Icons.people_outline, size: 20),
                    onPressed: () => showMemberListDialog(context, space!),
                  ),
                if (space != null)
                  IconButton(
                    tooltip: context.l10n.spaceLobby,
                    icon: const Icon(Icons.travel_explore_outlined, size: 20),
                    onPressed: () => showSpaceLobby(context, space!),
                  ),
                IconButton(
                  tooltip: context.l10n.newGroup,
                  icon: const Icon(Icons.create_new_folder_outlined, size: 20),
                  onPressed: onCreateGroup,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (space == null) _ConversationSearchBar(client: client),
          if (space != null) RoomBanner(room: space!),
          Expanded(
            // Cross-fade the channel list when another space is selected
            // (the key only changes on scope switches, not on sync updates).
            child: PaneSwitcher(
              child: KeyedSubtree(
                key: ValueKey(space?.id),
                child: _buildList(context),
              ),
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

  Future<void> _showGroupMenu(
    BuildContext context,
    ChannelGroup group,
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
        PopupMenuItem(value: 'rename', child: Text(context.l10n.rename)),
        PopupMenuItem(value: 'delete', child: Text(context.l10n.delete)),
      ],
    );
    if (selected == null || !context.mounted) return;
    switch (selected) {
      case 'rename':
        onRenameGroup(group);
      case 'delete':
        onDeleteGroup(group);
    }
  }

  Widget _sectionHeader(
    BuildContext context,
    String name, {
    required bool collapsed,
    required VoidCallback onToggle,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 16, 4),
        child: Row(
          children: [
            AnimatedRotation(
              turns: collapsed ? -0.25 : 0,
              duration: Motion.short,
              curve: Motion.easeOut,
              child: Icon(
                Icons.expand_more,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The scope's channel list: requests/pinned/DM sections (Home only),
  /// ungrouped channels in the user's saved order, per-user groups, read-only
  /// sub-space categories and not-yet-joined children (space only).
  /// Drag & drop rearranges everything through account data.
  Widget _buildList(BuildContext context) {
    final scopeId = space?.id;
    final groups = channelGroupsFor(client, scopeId);
    final groupedIds = {for (final group in groups) ...group.roomIds};

    final pool = <Room>[];
    final categories = <Room>[];
    final viaByRoomId = <String, List<String>>{};
    if (space != null) {
      for (final child in _sortedSpaceChildren(space!)) {
        viaByRoomId[child.roomId] = child.via;
        final room = client.getRoomById(child.roomId);
        if (room == null ||
            room.membership == Membership.leave ||
            room.membership == Membership.ban) {
          continue;
        }
        room.isSpace ? categories.add(room) : pool.add(room);
      }
    } else {
      pool.addAll(rooms);
    }
    // Not joined: every room the hierarchy describes (any depth, like the
    // space lobby) that is not already in the local room list.
    final notJoined = <SpaceRoomsChunk$2>[];
    for (final chunk in hierarchyRooms) {
      if (chunk.roomId == space?.id || chunk.roomType == 'm.space') continue;
      final room = client.getRoomById(chunk.roomId);
      if (room != null && room.membership != Membership.leave) continue;
      notJoined.add(chunk);
    }
    final requests = space == null ? openRequests(client.rooms) : <Room>[];

    if (requests.isEmpty &&
        pool.isEmpty &&
        groups.isEmpty &&
        categories.isEmpty &&
        notJoined.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(context.l10n.noRoomsHereYet),
        ),
      );
    }

    final ungroupedPool = [
      for (final room in pool)
        if (!groupedIds.contains(room.id)) room,
    ];
    final pinned = space == null ? pinnedRooms(ungroupedPool) : <Room>[];
    final pinnedIds = {for (final room in pinned) room.id};
    final directs = space == null
        ? [
            for (final room in ungroupedPool)
              if (room.isDirectChat && !pinnedIds.contains(room.id)) room,
          ]
        : <Room>[];
    final ungrouped = applyOrder(
      [
        for (final room in ungroupedPool)
          if (!pinnedIds.contains(room.id) &&
              (space != null || !room.isDirectChat))
            room,
      ],
      channelOrderFor(client, scopeId),
      (room) => room.id,
    );

    Widget tile(Room room, {bool card = false}) => _ChannelTile(
      room: room,
      selected: room.id == selectedRoomId,
      onTap: () => onRoomTap(room),
      card: card,
    );

    void drop(_ChannelDrag drag, {String? toGroupId, String? beforeRoomId}) {
      final newGroups = channelGroupsFor(client, scopeId);
      for (final group in newGroups) {
        group.roomIds.remove(drag.room.id);
      }
      final ungroupedIds = [
        for (final room in ungrouped)
          if (room.id != drag.room.id) room.id,
      ];
      if (toGroupId == null) {
        var at = beforeRoomId == null
            ? ungroupedIds.length
            : ungroupedIds.indexOf(beforeRoomId);
        if (at < 0) at = ungroupedIds.length;
        ungroupedIds.insert(at, drag.room.id);
      } else {
        ChannelGroup? target;
        for (final group in newGroups) {
          if (group.id == toGroupId) target = group;
        }
        if (target == null) return;
        var at = beforeRoomId == null
            ? target.roomIds.length
            : target.roomIds.indexOf(beforeRoomId);
        if (at < 0) at = target.roomIds.length;
        target.roomIds.insert(at, drag.room.id);
      }
      onSaveLayout(newGroups, ungroupedIds);
    }

    Widget draggable(Room room, {String? groupId, bool card = false}) =>
        _DraggableChannelTile(
          tile: tile(room, card: card),
          room: room,
          onAcceptBefore: (drag) =>
              drop(drag, toGroupId: groupId, beforeRoomId: room.id),
        );

    return ListView(
      children: [
        if (requests.isNotEmpty) ...[
          RequestsSection(
            requests: requests,
            onTap: onRoomTap,
            onJoined: onRequestJoined,
          ),
          const SizedBox(height: 16),
        ],
        if (pinned.isNotEmpty) ...[
          PinnedRoomsSection(pinned: pinned, tileBuilder: tile),
          const SizedBox(height: 16),
        ],
        if (directs.isNotEmpty) ...[
          _SectionLabel(context.l10n.directMessages),
          for (final room in directs) draggable(room, card: true),
          const SizedBox(height: 16),
        ],
        if (ungrouped.isNotEmpty || groups.isNotEmpty)
          _SectionDropTarget(
            enabled: true,
            onDrop: (drag) => drop(drag),
            child: _SectionLabel(context.l10n.channels),
          ),
        for (final room in ungrouped) draggable(room),
        for (final group in groups) ...[
          const SizedBox(height: 12),
          _SectionDropTarget(
            enabled: true,
            onDrop: (drag) => drop(drag, toGroupId: group.id),
            child: GestureDetector(
              onSecondaryTapUp: (details) =>
                  _showGroupMenu(context, group, details.globalPosition),
              onLongPressStart: (details) =>
                  _showGroupMenu(context, group, details.globalPosition),
              child: _sectionHeader(
                context,
                group.name,
                collapsed: collapsedCategories.contains(group.id),
                onToggle: () => onToggleCategory(group.id),
              ),
            ),
          ),
          AnimatedCollapse(
            collapsed: collapsedCategories.contains(group.id),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final id in group.roomIds)
                  if (client.getRoomById(id) case final Room room)
                    if (room.membership != Membership.leave &&
                        room.membership != Membership.ban)
                      draggable(room, groupId: group.id),
              ],
            ),
          ),
        ],
        for (final category in categories) ...[
          const SizedBox(height: 12),
          _sectionHeader(
            context,
            category.nickOrDisplayname,
            collapsed: collapsedCategories.contains(category.id),
            onToggle: () => onToggleCategory(category.id),
          ),
          AnimatedCollapse(
            collapsed: collapsedCategories.contains(category.id),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final child in _sortedSpaceChildren(category))
                  if (client.getRoomById(child.roomId) case final Room room)
                    if (!room.isSpace && room.membership != Membership.leave)
                      tile(room),
              ],
            ),
          ),
        ],
        if (notJoined.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionLabel(context.l10n.notJoined),
          for (final chunk in notJoined)
            _NotJoinedTile(
              client: client,
              chunk: chunk,
              via: viaByRoomId[chunk.roomId],
            ),
        ],
      ],
    );
  }
}

/// Highlights and accepts channel drops for a whole section (the top-level
/// label or a group header).
class _SectionDropTarget extends StatelessWidget {
  const _SectionDropTarget({
    required this.enabled,
    required this.onDrop,
    required this.child,
  });

  final bool enabled;
  final void Function(_ChannelDrag drag) onDrop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return DragTarget<_ChannelDrag>(
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidates, _) => ColoredBox(
        color: candidates.isNotEmpty
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        child: child,
      ),
    );
  }
}

/// Lobby-style tile for a hierarchy room the user has not joined: avatar,
/// member count, topic and a join/knock action with its own busy state.
class _NotJoinedTile extends StatefulWidget {
  const _NotJoinedTile({required this.client, required this.chunk, this.via});

  final Client client;
  final SpaceRoomsChunk$2 chunk;
  final List<String>? via;

  @override
  State<_NotJoinedTile> createState() => _NotJoinedTileState();
}

class _NotJoinedTileState extends State<_NotJoinedTile> {
  bool _busy = false;
  bool _knocked = false;

  List<String>? get _via {
    final via = widget.via;
    return (via == null || via.isEmpty) ? null : via;
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  Future<void> _join() async {
    setState(() => _busy = true);
    try {
      await widget.client.joinRoom(widget.chunk.roomId, via: _via);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _knock() async {
    setState(() => _busy = true);
    try {
      await widget.client.knockRoom(widget.chunk.roomId, via: _via);
      if (mounted) setState(() => _knocked = true);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chunk = widget.chunk;
    final name = chunk.name ?? chunk.canonicalAlias ?? chunk.roomId;
    final knocked =
        _knocked ||
        widget.client.getRoomById(chunk.roomId)?.membership == Membership.knock;
    return ListTile(
      dense: true,
      leading: MxcAvatar(
        client: widget.client,
        name: name,
        avatarUrl: chunk.avatarUrl,
        radius: 14,
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          context.l10n.membersCount(chunk.numJoinedMembers),
          if (chunk.topic?.isNotEmpty ?? false) chunk.topic!,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : knocked
          ? Text(context.l10n.knocked)
          : chunk.joinRule == 'knock'
          ? OutlinedButton(onPressed: _knock, child: Text(context.l10n.knock))
          : TextButton(onPressed: _join, child: Text(context.l10n.join)),
    );
  }
}

/// Makes a channel tile draggable and a drop target: dropping another
/// channel on it inserts that channel right before this one.
class _DraggableChannelTile extends StatelessWidget {
  const _DraggableChannelTile({
    required this.tile,
    required this.room,
    required this.onAcceptBefore,
  });

  final Widget tile;
  final Room room;
  final void Function(_ChannelDrag drag) onAcceptBefore;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DragTarget<_ChannelDrag>(
      onWillAcceptWithDetails: (details) => details.data.room.id != room.id,
      onAcceptWithDetails: (details) => onAcceptBefore(details.data),
      builder: (context, candidates, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Insertion indicator while another channel hovers above.
          Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: candidates.isNotEmpty
                ? colorScheme.primary
                : Colors.transparent,
          ),
          Draggable<_ChannelDrag>(
            data: _ChannelDrag(room: room),
            feedback: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: colorScheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(
                  room.nickOrDisplayname,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.35, child: tile),
            child: tile,
          ),
        ],
      ),
    );
  }
}

/// Solid rounded panel for the "Floating" layout: the glass panels'
/// arrangement without the gradient, translucency and blur.
class _FloatingPanel extends StatelessWidget {
  const _FloatingPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // Clip the content separately, inset by the border width: clipping
      // the container itself would let the content paint over the border
      // stroke and cut its corners off.
      child: ClipRRect(borderRadius: BorderRadius.circular(17), child: child),
    );
  }
}

/// A floating frosted-glass panel for the Liquid layout: rounded corners,
/// backdrop blur, translucent tint, hairline border and soft shadow.
class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Discord's "Find or start a conversation" bar above the Home list: opens
/// the quick switcher to search direct messages, rooms and people.
class _ConversationSearchBar extends StatelessWidget {
  const _ConversationSearchBar({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 2),
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => showQuickSwitcher(context, client),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.findOrStartConversation,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    this.card = false,
  });

  final Room room;
  final bool selected;
  final VoidCallback onTap;

  /// Renders as a rounded card with the peer's status message under the
  /// name — the member list look — instead of a flat list tile.
  final bool card;

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
        if (room.directChatMatrixID case final userId?
            when userId != room.client.userID)
          PopupMenuItem(
            value: 'nickname',
            child: Text(context.l10n.setNickname),
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
      case 'nickname':
        await showNicknameDialog(
          context,
          room.client,
          room.directChatMatrixID!,
        );
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
              context.l10n.youWillNoLongerSee(room.nickOrDisplayname),
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

  /// The member-list look: a fixed-height rounded card with a small gap,
  /// the presence avatar and the peer's status message under the name.
  Widget _buildCard(
    BuildContext context,
    bool isInvite,
    bool isKnock,
    String? directUserId,
  ) {
    final theme = Theme.of(context);
    final selectedColor = selected
        ? theme.colorScheme.onSecondaryContainer
        : null;
    Widget content = InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              if (directUserId != null)
                PresenceAvatar(
                  client: room.client,
                  userId: directUserId,
                  name: room.nickOrDisplayname,
                  avatarUrl: room.avatar,
                  radius: 14,
                )
              else
                SizedBox(
                  width: 28,
                  child: Icon(
                    isInvite
                        ? Icons.mail_outline
                        : isKnock
                        ? Icons.hourglass_top
                        : Icons.tag,
                    size: 20,
                    color: selectedColor,
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.nickOrDisplayname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: selectedColor,
                        fontWeight: room.isUnreadOrInvited
                            ? FontWeight.bold
                            : null,
                      ),
                    ),
                    if (directUserId != null)
                      UserStatusText(
                        client: room.client,
                        userId: directUserId,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (room.unreadBadgeCount > 0)
                Badge(label: Text(room.unreadBadgeCount.toString()))
              else if (isInvite)
                const Badge(label: Text('!')),
            ],
          ),
        ),
      ),
    );
    content = Semantics(selected: selected, child: content);
    if (directUserId != null) {
      content = UserBannerBackground(
        client: room.client,
        userId: directUserId,
        child: content,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: GestureDetector(
        onSecondaryTapUp: (details) =>
            _showContextMenu(context, details.globalPosition),
        onLongPressStart: (details) =>
            _showContextMenu(context, details.globalPosition),
        child: _SelectionFrame(
          selected: selected,
          color: theme.colorScheme.surfaceContainer,
          child: content,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isInvite = room.membership == Membership.invite;
    final isKnock = room.membership == Membership.knock;
    final directUserId = room.directChatMatrixID;
    if (card) return _buildCard(context, isInvite, isKnock, directUserId);
    Widget tile = ListTile(
      dense: true,
      selected: selected,
      selectedColor: Theme.of(context).colorScheme.onSecondaryContainer,
      // Together with the 8px margin below, keeps the content where the
      // default padding (16 start, 24 end) put it on a flush row.
      contentPadding: const EdgeInsetsDirectional.only(start: 8, end: 16),
      leading: directUserId != null
          ? PresenceAvatar(
              client: room.client,
              userId: directUserId,
              name: room.nickOrDisplayname,
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
        room.nickOrDisplayname,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: room.isUnreadOrInvited
            ? const TextStyle(fontWeight: FontWeight.bold)
            : null,
      ),
      trailing: room.unreadBadgeCount > 0
          ? Badge(label: Text(room.unreadBadgeCount.toString()))
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: _SelectionFrame(
          selected: selected,
          color: Colors.transparent,
          child: tile,
        ),
      ),
    );
  }
}

/// Rounded backdrop of a channel-list tile that marks the open chat: the
/// selection fill plus an accent bar at the leading edge. The bar is painted
/// above the tile, so a profile banner drawn behind the content can't hide it.
class _SelectionFrame extends StatelessWidget {
  const _SelectionFrame({
    required this.selected,
    required this.color,
    required this.child,
  });

  final bool selected;

  /// Fill while not selected.
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colorScheme.secondaryContainer : color,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          child,
          if (selected)
            PositionedDirectional(
              start: 0,
              top: 6,
              bottom: 6,
              width: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: const BorderRadiusDirectional.horizontal(
                    end: Radius.circular(4),
                  ),
                ),
              ),
            ),
        ],
      ),
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
  const _NoRoomSelected({this.liquid = false});

  final bool liquid;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(
        context,
      ).colorScheme.surface.withValues(alpha: liquid ? 0.35 : 1),
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
