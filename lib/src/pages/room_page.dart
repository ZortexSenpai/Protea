import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:matrix/matrix.dart';

import '../widgets/emoji_picker.dart';
import '../widgets/event_image.dart';
import '../widgets/mxc_avatar.dart';
import '../widgets/presence_indicator.dart';
import '../widgets/user_profile_card.dart';

class RoomPage extends StatefulWidget {
  const RoomPage({super.key, required this.room, this.onOpenMenu});

  final Room room;

  /// When set, the app bar shows a hamburger button that calls this instead
  /// of a back button — used when the page is embedded without a navigation
  /// sidebar (narrow windows).
  final VoidCallback? onOpenMenu;

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  Timeline? _timeline;
  final _sendController = TextEditingController();
  final _scrollController = ScrollController();
  Event? _replyTo;
  DateTime? _typingLastSent;

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

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.toString())));
  }

  Future<void> _send() async {
    final text = _sendController.text.trim();
    if (text.isEmpty) return;
    _sendController.clear();
    final replyTo = _replyTo;
    setState(() => _replyTo = null);
    _typingLastSent = null;
    widget.room.setTyping(false).catchError((_) {});
    try {
      await widget.room.sendTextEvent(text, inReplyTo: replyTo);
    } catch (e) {
      _showError(e);
    }
  }

  void _onInputChanged(String text) {
    if (text.isEmpty) {
      _typingLastSent = null;
      widget.room.setTyping(false).catchError((_) {});
      return;
    }
    final now = DateTime.now();
    if (_typingLastSent == null ||
        now.difference(_typingLastSent!) > const Duration(seconds: 4)) {
      _typingLastSent = now;
      widget.room.setTyping(true, timeout: 10000).catchError((_) {});
    }
  }

  void _insertEmoji(String emoji) {
    final text = _sendController.text;
    final selection = _sendController.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    _sendController.value = TextEditingValue(
      text: text.replaceRange(start, end, emoji),
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  Future<void> _pickEmoji() async {
    final emoji = await showEmojiPicker(context);
    if (emoji != null) _insertEmoji(emoji);
  }

  static const _imageExtensions = {
    'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'avif', 'heic', 'tiff',
  };

  Future<void> _attachFile() async {
    final picked = await openFile();
    if (picked == null) return;
    try {
      final bytes = await picked.readAsBytes();
      final name = picked.name;
      final extension = name.split('.').last.toLowerCase();
      final isImage = (picked.mimeType?.startsWith('image/') ?? false) ||
          _imageExtensions.contains(extension);
      MatrixFile file;
      if (isImage) {
        int? width;
        int? height;
        try {
          final image = await decodeImageFromList(bytes);
          width = image.width;
          height = image.height;
          image.dispose();
        } catch (_) {}
        file = MatrixImageFile(
          bytes: bytes,
          name: name,
          mimeType: picked.mimeType,
          width: width,
          height: height,
        );
      } else {
        file = MatrixFile(bytes: bytes, name: name, mimeType: picked.mimeType);
      }
      await widget.room.sendFileEvent(file);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _saveAttachment(Event event) async {
    try {
      final file = await event.downloadAndDecryptAttachment();
      final location = await getSaveLocation(suggestedName: file.name);
      if (location == null) return;
      await XFile.fromData(
        file.bytes,
        mimeType: file.mimeType,
        name: file.name,
      ).saveTo(location.path);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Saved ${file.name}')));
      }
    } catch (e) {
      _showError(e);
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

  Widget _buildTypingIndicator() {
    return StreamBuilder<SyncUpdate>(
      stream: _client.onSync.stream,
      builder: (context, _) {
        final names = widget.room.typingUsers
            .where((user) => user.id != _client.userID)
            .map((user) => user.calcDisplayname())
            .toList();
        final text = switch (names.length) {
          0 => '',
          1 => '${names[0]} is typing…',
          2 => '${names[0]} and ${names[1]} are typing…',
          _ => 'Several people are typing…',
        };
        return SizedBox(
          height: 18,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                text,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReplyBar() {
    final replyTo = _replyTo;
    if (replyTo == null) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, size: 20, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  replyTo.senderFromMemoryOrFallback.calcDisplayname(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  replyTo.calcLocalizedBodyFallback(
                    const MatrixDefaultLocalizations(),
                    hideReply: true,
                    plaintextBody: true,
                    removeMarkdown: true,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _replyTo = null),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeline = _timeline;
    final encryptedWithoutSupport =
        widget.room.encrypted && !_client.encryptionEnabled;
    final directUserId = widget.room.directChatMatrixID;
    final displayname = widget.room.getLocalizedDisplayname();
    return Scaffold(
      appBar: AppBar(
        leading: widget.onOpenMenu != null
            ? IconButton(
                tooltip: 'Channels',
                icon: const Icon(Icons.menu),
                onPressed: widget.onOpenMenu,
              )
            : null,
        title: Row(
          children: [
            if (directUserId != null)
              GestureDetector(
                onTap: () => showUserProfileCard(
                  context,
                  client: _client,
                  userId: directUserId,
                  displayName: displayname,
                  avatarUrl: widget.room.avatar,
                ),
                child: PresenceAvatar(
                  client: _client,
                  userId: directUserId,
                  name: displayname,
                  avatarUrl: widget.room.avatar,
                  radius: 16,
                ),
              )
            else
              MxcAvatar(
                client: _client,
                name: displayname,
                avatarUrl: widget.room.avatar,
                radius: 16,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (directUserId != null)
                    PresenceLabel(
                      client: _client,
                      userId: directUserId,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
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
                    onReply: (event) => setState(() => _replyTo = event),
                    onSaveAttachment: _saveAttachment,
                  ),
          ),
          _buildTypingIndicator(),
          _buildReplyBar(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Attach file',
                    onPressed: encryptedWithoutSupport ? null : _attachFile,
                    icon: const Icon(Icons.attach_file),
                  ),
                  IconButton(
                    tooltip: 'Emoji',
                    onPressed: encryptedWithoutSupport ? null : _pickEmoji,
                    icon: const Icon(Icons.emoji_emotions_outlined),
                  ),
                  const SizedBox(width: 4),
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
                      onChanged: _onInputChanged,
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
    required this.onReply,
    required this.onSaveAttachment,
  });

  final Timeline timeline;
  final List<Event> events;
  final ScrollController scrollController;
  final Client client;
  final ValueChanged<Event> onReply;
  final ValueChanged<Event> onSaveAttachment;

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
          onReply: onReply,
          onSaveAttachment: onSaveAttachment,
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

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    required this.event,
    required this.timeline,
    required this.ownMessage,
    required this.showSender,
    required this.onReply,
    required this.onSaveAttachment,
  });

  final Event event;
  final Timeline timeline;
  final bool ownMessage;
  final bool showSender;
  final ValueChanged<Event> onReply;
  final ValueChanged<Event> onSaveAttachment;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _hovered = false;

  static const _quickReactions = ['👍', '❤️', '😂', '😮', '😢', '🎉'];
  static const _hoverReactions = ['👍', '❤️', '😂'];

  static const _attachmentTypes = {
    MessageTypes.File,
    MessageTypes.Audio,
    MessageTypes.Video,
  };

  Event get event => widget.event;
  Timeline get timeline => widget.timeline;
  bool get ownMessage => widget.ownMessage;
  bool get showSender => widget.showSender;
  ValueChanged<Event> get onReply => widget.onReply;
  ValueChanged<Event> get onSaveAttachment => widget.onSaveAttachment;

  Client get _client => event.room.client;

  String? _reactionKey(Event reaction) => reaction.content
      .tryGetMap<String, Object?>('m.relates_to')
      ?.tryGet<String>('key');

  Future<void> _toggleReaction(BuildContext context, String key) async {
    final reactions =
        event.aggregatedEvents(timeline, RelationshipTypes.reaction);
    Event? ownReaction;
    for (final reaction in reactions) {
      if (reaction.senderId == _client.userID &&
          _reactionKey(reaction) == key) {
        ownReaction = reaction;
        break;
      }
    }
    try {
      if (ownReaction != null) {
        await ownReaction.redactEvent();
      } else {
        await event.room.sendReaction(event.eventId, key);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('The message will be removed for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await event.redactEvent();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _showMessageMenu(BuildContext context, Offset position) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final displayEvent = event.getDisplayEvent(timeline);
    final sent = event.status.isSent;
    final hasAttachment =
        displayEvent.attachmentOrThumbnailMxcUrl() != null;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      items: [
        if (sent)
          PopupMenuItem<String>(
            enabled: false,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final emoji in _quickReactions)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.pop(context, 'react:$emoji'),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child:
                          Text(emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.pop(context, 'more-reactions'),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.add_reaction_outlined, size: 20),
                  ),
                ),
              ],
            ),
          ),
        if (sent)
          const PopupMenuItem(value: 'reply', child: Text('Reply')),
        const PopupMenuItem(value: 'copy', child: Text('Copy text')),
        if (hasAttachment)
          const PopupMenuItem(value: 'save', child: Text('Save file')),
        if (ownMessage && sent)
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
    if (selected == null || !context.mounted) return;
    if (selected.startsWith('react:')) {
      await _toggleReaction(context, selected.substring('react:'.length));
    } else if (selected == 'more-reactions') {
      final emoji = await showEmojiPicker(context);
      if (emoji != null && context.mounted) {
        await _toggleReaction(context, emoji);
      }
    } else if (selected == 'reply') {
      onReply(event);
    } else if (selected == 'copy') {
      await Clipboard.setData(ClipboardData(
        text: displayEvent.calcLocalizedBodyFallback(
          const MatrixDefaultLocalizations(),
          hideReply: true,
          plaintextBody: true,
        ),
      ));
    } else if (selected == 'save') {
      onSaveAttachment(displayEvent);
    } else if (selected == 'delete') {
      await _confirmDelete(context);
    }
  }

  Widget _hoverButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }

  /// Discord-style action bar shown next to the bubble while hovering.
  Widget _buildHoverActions() {
    final colorScheme = Theme.of(context).colorScheme;
    final sent = event.status.isSent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(18),
        color: colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sent) ...[
                for (final emoji in _hoverReactions)
                  Tooltip(
                    message: 'React with $emoji',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _toggleReaction(context, emoji),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 4,
                        ),
                        child:
                            Text(emoji, style: const TextStyle(fontSize: 15)),
                      ),
                    ),
                  ),
                _hoverButton(
                  icon: Icons.add_reaction_outlined,
                  tooltip: 'Add reaction',
                  onTap: () async {
                    final emoji = await showEmojiPicker(context);
                    if (emoji != null && mounted) {
                      await _toggleReaction(context, emoji);
                    }
                  },
                ),
                _hoverButton(
                  icon: Icons.reply,
                  tooltip: 'Reply',
                  onTap: () => onReply(event),
                ),
              ],
              Builder(
                builder: (buttonContext) => _hoverButton(
                  icon: Icons.more_horiz,
                  tooltip: 'More',
                  onTap: () {
                    final box =
                        buttonContext.findRenderObject() as RenderBox;
                    _showMessageMenu(
                      context,
                      box.localToGlobal(Offset(0, box.size.height + 4)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildReactions(BuildContext context) {
    final reactions =
        event.aggregatedEvents(timeline, RelationshipTypes.reaction);
    if (reactions.isEmpty) return null;
    final colorScheme = Theme.of(context).colorScheme;
    final byKey = <String, List<Event>>{};
    for (final reaction in reactions) {
      final key = _reactionKey(reaction);
      if (key != null) byKey.putIfAbsent(key, () => []).add(reaction);
    }
    if (byKey.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final entry in byKey.entries)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _toggleReaction(context, entry.key),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: entry.value
                          .any((r) => r.senderId == _client.userID)
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: entry.value
                            .any((r) => r.senderId == _client.userID)
                        ? colorScheme.primary
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  '${entry.key} ${entry.value.length}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFileContent(BuildContext context, Event displayEvent) {
    final filename =
        displayEvent.content.tryGet<String>('filename') ?? displayEvent.body;
    final size = displayEvent.infoMap['size'];
    final sizeText = size is int ? _formatSize(size) : null;
    final icon = switch (displayEvent.messageType) {
      MessageTypes.Audio => Icons.audiotrack_outlined,
      MessageTypes.Video => Icons.videocam_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
    return InkWell(
      onTap: () => onSaveAttachment(displayEvent),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  sizeText == null ? 'Click to save' : '$sizeText · save',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

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

    final isImage = (displayEvent.messageType == MessageTypes.Image ||
            displayEvent.messageType == MessageTypes.Sticker) &&
        displayEvent.attachmentOrThumbnailMxcUrl(getThumbnail: true) != null;
    final isFile = _attachmentTypes.contains(displayEvent.messageType) &&
        displayEvent.attachmentMxcUrl != null;
    // For attachments the body is the filename unless a separate `filename`
    // field is set, in which case the body is a real caption worth showing.
    final filename = displayEvent.content.tryGet<String>('filename');
    final caption =
        isImage && filename != null && filename != displayEvent.body
            ? body
            : null;
    final inReplyToId = displayEvent.inReplyToEventId();
    final reactions = _buildReactions(context);

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
          if (inReplyToId != null)
            _ReplyQuote(timeline: timeline, eventId: inReplyToId),
          if (isImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ImageViewerPage(event: displayEvent),
                  ),
                ),
                child: Hero(
                  tag: displayEvent.eventId,
                  child: EventImage(event: displayEvent),
                ),
              ),
            ),
            if (caption != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(caption),
              ),
          ] else if (isFile)
            _buildFileContent(context, displayEvent)
          else
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

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: ColoredBox(
        color: _hovered
            ? colorScheme.onSurface.withValues(alpha: 0.05)
            : Colors.transparent,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(
                left: ownMessage ? 48 : 8,
                right: ownMessage ? 8 : 48,
                top: showSender ? 8 : 2,
                bottom: 2,
              ),
              child: Opacity(
                opacity: sending ? 0.6 : 1,
                child: Row(
                  mainAxisAlignment: ownMessage
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!ownMessage) ...[
                      if (showSender)
                        GestureDetector(
                          onTap: () => showUserProfileCard(
                            context,
                            client: _client,
                            userId: event.senderId,
                            displayName: sender,
                            avatarUrl:
                                event.senderFromMemoryOrFallback.avatarUrl,
                          ),
                          child: MxcAvatar(
                            client: _client,
                            name: sender,
                            avatarUrl:
                                event.senderFromMemoryOrFallback.avatarUrl,
                            radius: 14,
                          ),
                        )
                      else
                        const SizedBox(width: 28),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Column(
                        crossAxisAlignment: ownMessage
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onLongPressStart: (details) => _showMessageMenu(
                                context, details.globalPosition),
                            onSecondaryTapUp: (details) => _showMessageMenu(
                                context, details.globalPosition),
                            child: bubble,
                          ),
                          ?reactions,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Floating action bar: painted on top so it never affects the
            // bubble layout.
            if (_hovered)
              Positioned(
                top: 0,
                right: 8,
                child: _buildHoverActions(),
              ),
          ],
        ),
      ),
    );
  }
}

/// A small quoted box shown inside a bubble for messages that reply to
/// another event.
class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote({required this.timeline, required this.eventId});

  final Timeline timeline;
  final String eventId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FutureBuilder<Event?>(
      future: timeline.getEventById(eventId),
      builder: (context, snapshot) {
        final replied = snapshot.data;
        final sender =
            replied?.senderFromMemoryOrFallback.calcDisplayname() ?? '';
        final snippet = replied == null
            ? 'Loading…'
            : replied.calcLocalizedBodyFallback(
                const MatrixDefaultLocalizations(),
                hideReply: true,
                plaintextBody: true,
                removeMarkdown: true,
              );
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (sender.isNotEmpty)
                          Text(
                            sender,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        Text(
                          snippet,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
