import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matrix/matrix.dart';

import '../l10n.dart';
import '../pages/room_page.dart';
import 'mxc_avatar.dart';

/// Opens the quick switcher: type to filter rooms, Enter or click to open.
Future<void> showQuickSwitcher(BuildContext context, Client client) =>
    showDialog(
      context: context,
      builder: (_) => QuickSwitcherDialog(client: client),
    );

/// Listens for Ctrl/Cmd+K anywhere in the app and opens the quick switcher.
class QuickSwitcherListener extends StatefulWidget {
  const QuickSwitcherListener({
    super.key,
    required this.client,
    required this.child,
  });

  final Client client;
  final Widget child;

  @override
  State<QuickSwitcherListener> createState() => _QuickSwitcherListenerState();
}

class _QuickSwitcherListenerState extends State<QuickSwitcherListener> {
  bool _open = false;

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyK &&
        (HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed) &&
        !_open) {
      _open = true;
      showQuickSwitcher(
        context,
        widget.client,
      ).whenComplete(() => _open = false);
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class QuickSwitcherDialog extends StatefulWidget {
  const QuickSwitcherDialog({super.key, required this.client});

  final Client client;

  @override
  State<QuickSwitcherDialog> createState() => _QuickSwitcherDialogState();
}

class _QuickSwitcherDialogState extends State<QuickSwitcherDialog> {
  String _query = '';

  List<Room> get _filtered {
    final rooms = widget.client.rooms.where((room) => !room.isSpace).toList()
      ..sort(
        (a, b) => (b.lastEvent?.originServerTs ?? DateTime(0)).compareTo(
          a.lastEvent?.originServerTs ?? DateTime(0),
        ),
      );
    if (_query.isEmpty) return rooms;
    final query = _query.toLowerCase();
    return rooms
        .where(
          (room) =>
              room.getLocalizedDisplayname().toLowerCase().contains(query),
        )
        .toList();
  }

  void _open(Room room) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute(builder: (_) => RoomPage(room: room)));
  }

  @override
  Widget build(BuildContext context) {
    final rooms = _filtered;
    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 80, left: 24, right: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: context.l10n.jumpToRoomHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _query = value.trim()),
                onSubmitted: (_) {
                  if (rooms.isNotEmpty) _open(rooms.first);
                },
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: rooms.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(context.l10n.noMatchingRooms),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: rooms.length,
                      itemBuilder: (context, index) {
                        final room = rooms[index];
                        return ListTile(
                          dense: true,
                          leading: MxcAvatar(
                            client: widget.client,
                            name: room.getLocalizedDisplayname(),
                            avatarUrl: room.avatar,
                            radius: 14,
                          ),
                          title: Text(
                            room.getLocalizedDisplayname(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: room.notificationCount > 0
                              ? Badge(
                                  label: Text(
                                    room.notificationCount.toString(),
                                  ),
                                )
                              : null,
                          onTap: () => _open(room),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
