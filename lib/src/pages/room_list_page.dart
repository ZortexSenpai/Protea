import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:matrix/matrix.dart';

import '../client_manager.dart';
import '../room_actions.dart';
import '../settings.dart';
import '../widgets/account_switcher.dart';
import '../widgets/mxc_avatar.dart';
import '../widgets/new_chat_dialog.dart';
import '../widgets/presence_indicator.dart';
import 'room_page.dart';
import 'settings_page.dart';

class RoomListPage extends StatelessWidget {
  const RoomListPage({
    super.key,
    required this.client,
    required this.manager,
    required this.settings,
  });

  final Client client;
  final ClientManager manager;
  final AppSettings settings;

  Future<void> _onRoomTap(BuildContext context, Room room) async {
    if (!await confirmRoomTap(context, room)) return;
    if (context.mounted) {
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
          return ListView.builder(
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              final lastEvent = room.lastEvent;
              final displayname = room.getLocalizedDisplayname();
              final isInvite = room.membership == Membership.invite;
              final directUserId = room.directChatMatrixID;
              return ListTile(
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
                title: Text(
                  displayname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
              );
            },
          );
        },
      ),
    );
  }
}
