import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../l10n.dart';
import 'mxc_avatar.dart';

/// Forwards [event]'s content to a room picked from a list.
Future<void> showForwardDialog(BuildContext context, Event event) => showDialog(
  context: context,
  builder: (_) => ForwardMessageDialog(event: event),
);

class ForwardMessageDialog extends StatefulWidget {
  const ForwardMessageDialog({super.key, required this.event});

  final Event event;

  @override
  State<ForwardMessageDialog> createState() => _ForwardMessageDialogState();
}

class _ForwardMessageDialogState extends State<ForwardMessageDialog> {
  String _query = '';
  bool _busy = false;

  List<Room> get _rooms {
    final rooms =
        widget.event.room.client.rooms
            .where(
              (room) => !room.isSpace && room.membership == Membership.join,
            )
            .toList()
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

  Future<void> _forward(Room target) async {
    setState(() => _busy = true);
    try {
      // Strip relations (reply/edit) so the forwarded message stands alone.
      final content = Map<String, Object?>.from(widget.event.content)
        ..remove('m.relates_to');
      await target.sendEvent(content);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.forwardedTo(target.getLocalizedDisplayname()),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rooms = _rooms;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Text(
                    context.l10n.forwardTo,
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
              child: TextField(
                autofocus: true,
                enabled: !_busy,
                decoration: InputDecoration(
                  hintText: context.l10n.filterRoomsHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: rooms.length,
                itemBuilder: (context, index) {
                  final room = rooms[index];
                  return ListTile(
                    dense: true,
                    enabled: !_busy,
                    leading: MxcAvatar(
                      client: room.client,
                      name: room.getLocalizedDisplayname(),
                      avatarUrl: room.avatar,
                      radius: 14,
                    ),
                    title: Text(
                      room.getLocalizedDisplayname(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _forward(room),
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
