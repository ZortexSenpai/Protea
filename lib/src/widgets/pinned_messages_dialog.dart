import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:matrix/matrix.dart';

import '../l10n.dart';
import 'event_image.dart';
import 'mxc_avatar.dart';

/// Shows the room's pinned messages with the option to unpin them.
Future<void> showPinnedMessages(
  BuildContext context,
  Room room, {
  ValueChanged<String>? onJumpToMessage,
}) => showDialog(
  context: context,
  builder: (_) =>
      PinnedMessagesDialog(room: room, onJumpToMessage: onJumpToMessage),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Preview under the sender name: a thumbnail for images, stickers and
  /// videos with one, a file chip for other attachments, text otherwise.
  Widget _buildPreview(BuildContext context, Event event) {
    final messageType = event.messageType;
    final isImage =
        messageType == MessageTypes.Image ||
        messageType == MessageTypes.Sticker;
    if (isImage || (messageType == MessageTypes.Video && event.hasThumbnail)) {
      final filename = event.content.tryGet<String>('filename');
      final caption = filename != null && filename != event.body
          ? event.body
          : null;
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 140,
                height: 90,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    EventImage(event: event, fit: BoxFit.cover),
                    if (messageType == MessageTypes.Video)
                      const Center(
                        child: Icon(Icons.play_circle_outline, size: 32),
                      ),
                  ],
                ),
              ),
            ),
            if (caption != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      );
    }
    if (messageType == MessageTypes.File ||
        messageType == MessageTypes.Video ||
        messageType == MessageTypes.Audio) {
      final filename = event.content.tryGet<String>('filename') ?? event.body;
      final size = event.infoMap['size'];
      final icon = switch (messageType) {
        MessageTypes.Audio => Icons.audiotrack_outlined,
        MessageTypes.Video => Icons.videocam_outlined,
        _ => Icons.insert_drive_file_outlined,
      };
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                size is int ? '$filename · ${_formatSize(size)}' : filename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
    return Text(
      event.calcLocalizedBodyFallback(
        const MatrixDefaultLocalizations(),
        hideReply: true,
        plaintextBody: true,
        removeMarkdown: true,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final events = _events;
    final canUnpin = widget.room.canChangeStateEvent(
      EventTypes.RoomPinnedEvents,
    );
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
                    context.l10n.pinnedMessages,
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
            const Divider(height: 1),
            Flexible(
              child: events == null
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    )
                  : events.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(context.l10n.noPinnedMessages),
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
                          subtitle: _buildPreview(context, event),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat.yMMMd().format(event.originServerTs),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              if (canUnpin)
                                IconButton(
                                  tooltip: context.l10n.unpin,
                                  icon: const Icon(Icons.push_pin, size: 18),
                                  onPressed: _busy ? null : () => _unpin(event),
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
