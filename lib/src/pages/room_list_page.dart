import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:matrix/matrix.dart';

import '../client_manager.dart';
import '../room_actions.dart';
import '../settings.dart';
import '../widgets/account_switcher.dart';
import '../widgets/mxc_avatar.dart';
import '../widgets/new_chat_dialog.dart';
import '../widgets/pinned_rooms_section.dart';
import '../widgets/presence_indicator.dart';
import '../widgets/room_settings_dialog.dart';
import 'room_page.dart';
import 'settings_page.dart';

class RoomListPage extends StatelessWidget {
  const RoomListPage({
    super.key,
    required this.client,
    required this.manager,
    required this.settings,
    this.onRoomSelected,
    this.selectedRoomId,
  });

  final Client client;
  final ClientManager manager;
  final AppSettings settings;

  /// When set the page is embedded (split layout): tapped rooms are reported
  /// instead of pushed as a new page.
  final ValueChanged<Room>? onRoomSelected;
  final String? selectedRoomId;

  Future<void> _onRoomTap(BuildContext context, Room room) async {
    if (!await confirmRoomTap(context, room)) return;
    if (!context.mounted) return;
    final onSelected = onRoomSelected;
    if (onSelected != null) {
      onSelected(room);
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => RoomPage(room: room)));
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final isToday =
        time.year == now.year && time.month == now.month && time.day == now.day;
    return isToday
        ? DateFormat.Hm().format(time)
        : DateFormat.MMMd().format(time);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Protea'),
        actions: [
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () => showNewChatDialog(context, client),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'settings':
                  showSettingsDialog(
                    context,
                    client: client,
                    settings: settings,
                  );
                case 'accounts':
                  showAccountSwitcher(context, manager);
                case 'logout':
                  confirmLogout(context, client);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(enabled: false, child: Text(client.userID ?? '')),
              const PopupMenuItem(value: 'settings', child: Text('Settings')),
              const PopupMenuItem(
                value: 'accounts',
                child: Text('Switch account'),
              ),
              const PopupMenuItem(value: 'logout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: StreamBuilder<SyncUpdate>(
        stream: client.onSync.stream,
        builder: (context, _) {
          final rooms = client.rooms.where((room) => !room.isSpace).toList();
          if (rooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.forum_outlined, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    client.prevBatch == null
                        ? 'Syncing…'
                        : 'No rooms yet.\nJoin a room from another client to get started.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          final pinned = pinnedRooms(rooms);
          final pinnedIds = pinned.map((room) => room.id).toSet();
          final directs = rooms
              .where(
                (room) => room.isDirectChat && !pinnedIds.contains(room.id),
              )
              .toList();
          final others = rooms
              .where(
                (room) => !room.isDirectChat && !pinnedIds.contains(room.id),
              )
              .toList();
          return ListView(
            children: [
              if (pinned.isNotEmpty) ...[
                PinnedRoomsSection(
                  pinned: pinned,
                  tileBuilder: (room) => _roomTile(context, room),
                ),
                const SizedBox(height: 16),
              ],
              if (directs.isNotEmpty) ...[
                _SectionLabel('Direct messages'),
                for (final room in directs) _roomTile(context, room),
              ],
              if (directs.isNotEmpty && others.isNotEmpty)
                const SizedBox(height: 16),
              if (others.isNotEmpty) ...[
                _SectionLabel('Rooms'),
                for (final room in others) _roomTile(context, room),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _showRoomMenu(
    BuildContext context,
    Room room,
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
        PopupMenuItem(
          value: 'pin',
          child: Text(room.isFavourite ? 'Unpin' : 'Pin'),
        ),
        const PopupMenuItem(value: 'settings', child: Text('Settings')),
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
    }
  }

  Widget _roomTile(BuildContext context, Room room) {
    final lastEvent = room.lastEvent;
    final displayname = room.getLocalizedDisplayname();
    final isInvite = room.membership == Membership.invite;
    final directUserId = room.directChatMatrixID;
    return GestureDetector(
      onSecondaryTapUp: (details) =>
          _showRoomMenu(context, room, details.globalPosition),
      onLongPressStart: (details) =>
          _showRoomMenu(context, room, details.globalPosition),
      child: ListTile(
        selected: room.id == selectedRoomId,
        leading: directUserId != null
            ? PresenceAvatar(
                client: client,
                userId: directUserId,
                name: displayname,
                avatarUrl: room.avatar,
              )
            : MxcAvatar(
                client: client,
                name: displayname,
                avatarUrl: room.avatar,
              ),
        title: Text(displayname, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          isInvite
              ? 'Invitation — tap to respond'
              : lastEvent?.calcLocalizedBodyFallback(
                      const MatrixDefaultLocalizations(),
                      hideReply: true,
                      plaintextBody: true,
                      removeMarkdown: true,
                      withSenderNamePrefix: true,
                    ) ??
                    'No messages yet',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (lastEvent != null)
              Text(
                _formatTime(lastEvent.originServerTs),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (room.isUnreadOrInvited)
              Badge(
                label: Text(
                  room.notificationCount > 0
                      ? room.notificationCount.toString()
                      : '',
                ),
              ),
          ],
        ),
        onTap: () => _onRoomTap(context, room),
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
