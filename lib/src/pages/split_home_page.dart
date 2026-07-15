import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../client_manager.dart';
import '../room_navigator.dart';
import '../l10n.dart';
import '../settings.dart';
import 'room_list_page.dart';
import 'room_page.dart';

/// Split layout: the flat room list on the left with the selected chat next
/// to it. On narrow windows it falls back to the plain list with pushed
/// chat pages.
class SplitHomePage extends StatefulWidget {
  const SplitHomePage({
    super.key,
    required this.client,
    required this.manager,
    required this.settings,
  });

  final Client client;
  final ClientManager manager;
  final AppSettings settings;

  @override
  State<SplitHomePage> createState() => _SplitHomePageState();
}

class _SplitHomePageState extends State<SplitHomePage> {
  String? _selectedRoomId;

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

  /// Opens a room requested from elsewhere (profile card "Message"): selects
  /// it in place on wide windows, pushes the chat page on narrow ones.
  void _onRoomRequested() {
    final roomId = RoomNavigator.instance.roomId;
    final room = roomId == null ? null : widget.client.getRoomById(roomId);
    if (room == null) return;
    final wide = MediaQuery.sizeOf(context).width >= 720;
    if (wide) {
      setState(() => _selectedRoomId = room.id);
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => RoomPage(room: room)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    if (!wide) {
      return RoomListPage(
        client: widget.client,
        manager: widget.manager,
        settings: widget.settings,
      );
    }
    final room = _selectedRoomId == null
        ? null
        : widget.client.getRoomById(_selectedRoomId!);
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            SizedBox(
              width: 320,
              child: RoomListPage(
                client: widget.client,
                manager: widget.manager,
                settings: widget.settings,
                selectedRoomId: _selectedRoomId,
                onRoomSelected: (room) =>
                    setState(() => _selectedRoomId = room.id),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: room == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.forum_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(context.l10n.selectChatToStartMessaging),
                        ],
                      ),
                    )
                  : RoomPage(key: ValueKey(room.id), room: room),
            ),
          ],
        ),
      ),
    );
  }
}
