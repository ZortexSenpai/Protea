import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:matrix/matrix.dart';

import '../widgets/initials_avatar.dart';

class RoomPage extends StatefulWidget {
  const RoomPage({super.key, required this.room});

  final Room room;

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  Timeline? _timeline;
  final _sendController = TextEditingController();
  final _scrollController = ScrollController();

  static const _bubbleTypes = {
    EventTypes.Message,
    EventTypes.Sticker,
    EventTypes.Encrypted,
  };

  Client get _client => widget.room.client;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadTimeline();
  }

  @override
  void dispose() {
    _timeline?.cancelSubscriptions();
    _sendController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTimeline() async {
    final timeline = await widget.room.getTimeline(
      onUpdate: () {
        if (mounted) setState(() {});
      },
    );
    if (!mounted) {
      timeline.cancelSubscriptions();
      return;
    }
    setState(() => _timeline = timeline);
    try {
      await timeline.setReadMarker();
    } catch (_) {}
  }

  void _onScroll() {
    final timeline = _timeline;
    if (timeline == null) return;
    // The list is reversed, so maxScrollExtent is the oldest loaded message.
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        timeline.canRequestHistory &&
        !timeline.isRequestingHistory) {
      timeline.requestHistory();
    }
  }

  Future<void> _send() async {
    final text = _sendController.text.trim();
    if (text.isEmpty) return;
    _sendController.clear();
    try {
      await widget.room.sendTextEvent(text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  List<Event> _visibleEvents(Timeline timeline) => timeline.events
      .where(
        (event) =>
            (_bubbleTypes.contains(event.type) ||
                event.type == EventTypes.RoomMember) &&
            event.relationshipType != RelationshipTypes.edit &&
            event.type != EventTypes.Reaction,
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    final timeline = _timeline;
    final encryptedWithoutSupport =
        widget.room.encrypted && !_client.encryptionEnabled;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            InitialsAvatar(name: widget.room.getLocalizedDisplayname(), radius: 16),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.room.getLocalizedDisplayname(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (encryptedWithoutSupport)
            MaterialBanner(
              content: const Text(
                'This room is end-to-end encrypted. This build of Protea was '
                'compiled without E2EE support, so messages cannot be read or sent here.',
              ),
              leading: const Icon(Icons.lock_outline),
              actions: const [SizedBox.shrink()],
            ),
          Expanded(
            child: timeline == null
                ? const Center(child: CircularProgressIndicator())
                : _TimelineList(
                    timeline: timeline,
                    events: _visibleEvents(timeline),
                    scrollController: _scrollController,
                    client: _client,
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _sendController,
                      enabled: !encryptedWithoutSupport,
                      decoration: InputDecoration(
                        hintText: 'Message',
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      minLines: 1,
                      maxLines: 5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: encryptedWithoutSupport ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineList extends StatelessWidget {
  const _TimelineList({
    required this.timeline,
    required this.events,
    required this.scrollController,
    required this.client,
  });

  final Timeline timeline;
  final List<Event> events;
  final ScrollController scrollController;
  final Client client;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Center(child: Text('No messages yet. Say hello!'));
    }
    return ListView.builder(
      controller: scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        if (event.type == EventTypes.RoomMember) {
          return _StateEventLabel(event: event, timeline: timeline);
        }
        final previous =
            index + 1 < events.length ? events[index + 1] : null;
        final showSender = previous == null ||
            previous.senderId != event.senderId ||
            previous.type == EventTypes.RoomMember;
        return _MessageBubble(
          event: event,
          timeline: timeline,
          ownMessage: event.senderId == client.userID,
          showSender: showSender,
        );
      },
    );
  }
}

class _StateEventLabel extends StatelessWidget {
  const _StateEventLabel({required this.event, required this.timeline});

  final Event event;
  final Timeline timeline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Text(
        event.calcLocalizedBodyFallback(const MatrixDefaultLocalizations()),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.event,
    required this.timeline,
    required this.ownMessage,
    required this.showSender,
  });

  final Event event;
  final Timeline timeline;
  final bool ownMessage;
  final bool showSender;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayEvent = event.getDisplayEvent(timeline);
    final body = displayEvent.calcLocalizedBodyFallback(
      const MatrixDefaultLocalizations(),
      hideReply: true,
    );
    final sender = event.senderFromMemoryOrFallback.calcDisplayname();
    final sending = event.status.isSending;
    final failed = event.status.isError;

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ownMessage
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSender && !ownMessage)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                sender,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          Text(body),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat.Hm().format(event.originServerTs),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              if (failed) ...[
                const SizedBox(width: 4),
                Icon(Icons.error_outline, size: 14, color: colorScheme.error),
              ],
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        left: ownMessage ? 48 : 8,
        right: ownMessage ? 8 : 48,
        top: showSender ? 8 : 2,
        bottom: 2,
      ),
      child: Opacity(
        opacity: sending ? 0.6 : 1,
        child: Row(
          mainAxisAlignment:
              ownMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!ownMessage) ...[
              if (showSender)
                InitialsAvatar(name: sender, radius: 14)
              else
                const SizedBox(width: 28),
              const SizedBox(width: 8),
            ],
            Flexible(child: bubble),
          ],
        ),
      ),
    );
  }
}
