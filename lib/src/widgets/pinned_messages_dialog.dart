import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:matrix/matrix.dart';

import 'mxc_avatar.dart';

/// Shows the room's pinned messages with the option to unpin them.
Future<void> showPinnedMessages(
  BuildContext context,
  Room room, {
  ValueChanged<String>? onJumpToMessage,
}) =>
    showDialog(
      context: context,
      builder: (_) => PinnedMessagesDialog(
        room: room,
        onJumpToMessage: onJumpToMessage,
      ),
    );

class PinnedMessagesDialog extends StatefulWidget {
  const PinnedMessagesDialog({
    super.key,
    required this.room,
    this.onJumpToMessage,
  });

  final Room room;

  /// Called with the event ID when a pinned message is tapped; the dialog
  /// closes itself first.
  final ValueChanged<String>? onJumpToMessage;

  @override
  State<PinnedMessagesDialog> createState() => _PinnedMessagesDialogState();
}

class _PinnedMessagesDialogState extends State<PinnedMessagesDialog> {
  List<Event>? _events;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final events = await Future.wait(
      widget.room.pinnedEventIds.map(widget.room.getEventById),
    );
    if (mounted) {
      setState(() => _events = events.nonNulls.toList());
    }
  }

  Future<void> _unpin(Event event) async {
    setState(() => _busy = true);
    try {
      final ids = List<String>.from(widget.room.pinnedEventIds)
        ..remove(event.eventId);
      await widget.room.setPinnedEvents(ids);
      if (mounted) {
        setState(() => _events?.removeWhere((e) => e.eventId == event.eventId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = _events;
    final canUnpin =
        widget.room.canChangeStateEvent(EventTypes.RoomPinnedEvents);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 12, 8),
              child: Row(
                children: [
                  Text(
                    'Pinned messages',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: events == null
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    )
                  : events.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('No pinned messages in this room.'),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: events.length,
                          itemBuilder: (context, index) {
                            final event = events[index];
                            final sender = event.senderFromMemoryOrFallback;
                            return ListTile(
                              leading: MxcAvatar(
                                client: widget.room.client,
                                name: sender.calcDisplayname(),
                                avatarUrl: sender.avatarUrl,
                                radius: 16,
                              ),
                              title: Text(
                                sender.calcDisplayname(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                event.calcLocalizedBodyFallback(
                                  const MatrixDefaultLocalizations(),
                                  hideReply: true,
                                  plaintextBody: true,
                                  removeMarkdown: true,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    DateFormat.yMMMd()
                                        .format(event.originServerTs),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                  ),
                                  if (canUnpin)
                                    IconButton(
                                      tooltip: 'Unpin',
                                      icon: const Icon(
                                        Icons.push_pin,
                                        size: 18,
                                      ),
                                      onPressed:
                                          _busy ? null : () => _unpin(event),
                                    ),
                                ],
                              ),
                              onTap: widget.onJumpToMessage == null
                                  ? null
                                  : () {
                                      Navigator.of(context).pop();
                                      widget.onJumpToMessage!(event.eventId);
                                    },
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
