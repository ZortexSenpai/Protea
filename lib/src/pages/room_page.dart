import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:matrix/matrix.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../attachment_actions.dart';
import '../commands.dart';
import '../emoji_shortcodes.dart';
import '../event_body.dart';
import '../gif_proxy.dart';
import '../l10n.dart';
import '../motion.dart';
import '../nicknames.dart';
import '../notifications.dart';
import '../room_navigator.dart';
import '../settings.dart';
import '../svg.dart';
import '../temp_directory.dart';
import '../widgets/chat_wallpaper.dart';
import '../widgets/emoji_picker.dart';
import '../widgets/event_image.dart';
import '../widgets/event_video.dart';
import '../widgets/file_preview.dart';
import '../widgets/forward_message_dialog.dart';
import '../widgets/gif_picker_dialog.dart';
import '../widgets/html_message.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/link_preview.dart';
import '../widgets/linkified_text.dart';
import '../widgets/location.dart';
import '../widgets/message_search_dialog.dart';
import '../widgets/mxc_avatar.dart';
import '../widgets/nickname_dialog.dart';
import '../widgets/pinned_messages_dialog.dart';
import '../widgets/poll.dart';
import '../widgets/presence_indicator.dart';
import '../widgets/reactions_dialog.dart';
import '../widgets/sticker_picker.dart';
import '../widgets/user_banner.dart';
import '../widgets/room_banner.dart';
import '../widgets/room_settings_dialog.dart';
import '../widgets/user_profile_card.dart';
import '../widgets/voice_message.dart';

/// Pickers and forms that rise above the composer as inline panels instead
/// of opening popup dialogs.
enum _ComposerPanelKind { emoji, gif, sticker, poll }

class RoomPage extends StatefulWidget {
  const RoomPage({
    super.key,
    required this.room,
    this.onOpenMenu,
    this.initialEventId,
  });

  final Room room;

  /// When set, the app bar shows a hamburger button that calls this instead
  /// of a back button — used when the page is embedded without a navigation
  /// sidebar (narrow windows).
  final VoidCallback? onOpenMenu;

  /// When set, the page scrolls to this event once the timeline has loaded
  /// (used by search results and notifications).
  final String? initialEventId;

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  Timeline? _timeline;
  final _sendController = TextEditingController();
  final _itemScrollController = ItemScrollController();
  final _itemPositionsListener = ItemPositionsListener.create();
  Event? _replyTo;

  /// The message being edited in place, Discord-style, in the timeline.
  Event? _editing;

  /// The in-place editor's text and focus. Owned here rather than by the
  /// message bubble: the list drops bubbles scrolled out of view, and an
  /// edit in progress must survive that.
  final _editController = TextEditingController();
  final _editFocusNode = FocusNode();

  /// Keeps the editor (with its focus and text input connection) alive when
  /// a new message shifts every list item by one: the list reuses its
  /// items by position, so without it the field would be rebuilt in
  /// another bubble and lose the keyboard.
  final _editorKey = GlobalKey();
  Event? _threadRoot;
  final _pageScaffoldKey = GlobalKey<ScaffoldState>();
  final _inputFocusNode = FocusNode();
  List<User> _mentionSuggestions = [];
  List<SlashCommand> _commandSuggestions = [];

  /// File/GIF sends in flight, shown as skeleton bubbles above the composer.
  final List<_PendingSend> _pendingSends = [];
  DateTime? _typingLastSent;
  String? _highlightedEventId;

  /// Where a freshly built timeline list starts: the newest message, or the
  /// target of a jump into unloaded history.
  int _initialScrollIndex = 0;
  Timer? _highlightTimer;

  /// First unread event when the room was opened; a "New messages" divider
  /// is shown above it.
  String? _unreadMarkerEventId;
  String? _lastMarkedReadEventId;

  /// Set by "Mark as unread": the page stops marking the room read until
  /// it is left or the user sends a message.
  bool _keepUnread = false;
  StreamSubscription<SyncUpdate>? _syncSubscription;
  bool _dragging = false;

  AudioRecorder? _recorder;
  final List<double> _recordingAmplitudes = [];
  Timer? _recordingTimer;
  DateTime? _recordingStart;
  bool _recording = false;

  String get _draftKey => 'draft_${widget.room.id}';

  /// Event a "Mark as unread" started from, so the "New messages" divider
  /// can be restored there when the room is reopened. The fully-read marker
  /// can't carry this: homeservers refuse to move it backwards.
  String get _unreadFromKey => 'unread_from_${widget.room.id}';

  static const _bubbleTypes = {
    EventTypes.Message,
    EventTypes.Sticker,
    EventTypes.Encrypted,
    pollStartType,
  };

  Client get _client => widget.room.client;

  /// Settings resolved in [didChangeDependencies]: the sync listener and
  /// code after awaits can run while this element is deactivated (the
  /// outgoing page of a room switch), where ancestor lookups throw.
  AppSettings? _settings;

  @override
  void initState() {
    super.initState();
    NotificationService.activeRoomId = widget.room.id;
    // Opening the room reads it: its desktop notifications can go.
    NotificationService.clearRoomNotifications(widget.room.id);
    HardwareKeyboard.instance.addHandler(_handleComposerPanelKey);
    ComposerFocus.instance.addListener(_onComposerFocusRequested);
    // A request that switched to this room arrives before the page exists.
    _onComposerFocusRequested();
    _itemPositionsListener.itemPositions.addListener(_onPositionsChanged);
    // Syncs for other rooms don't affect this page. For this room's syncs,
    // rebuilding stays narrow: timeline events rebuild through the
    // timeline's own onUpdate callback, receipts reach only the per-bubble
    // rows through [_receiptsNotifier], and the typing label has its own
    // StreamBuilder — so only the rare rest (state changes, account data
    // like the fully-read marker, leaving the room) rebuilds the page.
    _syncSubscription = _client.onSync.stream.listen((update) {
      final joinUpdate = update.rooms?.join?[widget.room.id];
      final leftRoom =
          update.rooms?.leave?.containsKey(widget.room.id) ?? false;
      if (joinUpdate == null && !leftRoom) return;
      _receiptsNotifier.value = _receiptsByEvent();
      _maybeMarkRead();
      final needsRebuild =
          leftRoom ||
          (joinUpdate?.state?.isNotEmpty ?? false) ||
          (joinUpdate?.accountData?.isNotEmpty ?? false) ||
          joinUpdate?.summary != null;
      if (needsRebuild && mounted) setState(() {});
    });
    _loadTimeline();
    _loadDraft();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _settings = SettingsScope.of(context);
    // Settings feed the visible-events filter (deleted/membership events).
    _visibleEventsCache = null;
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draft = prefs.getString(_draftKey);
    if (draft != null &&
        draft.isNotEmpty &&
        mounted &&
        _sendController.text.isEmpty) {
      _sendController.text = draft;
    }
  }

  Future<void> _saveDraft(String text) async {
    final prefs = await SharedPreferences.getInstance();
    if (text.isEmpty) {
      await prefs.remove(_draftKey);
    } else {
      await prefs.setString(_draftKey, text);
    }
  }

  @override
  void dispose() {
    // Another room may already have claimed the slot (its initState runs
    // before this dispose when switching rooms) — only clear our own claim.
    if (NotificationService.activeRoomId == widget.room.id) {
      NotificationService.activeRoomId = null;
    }
    _recordingTimer?.cancel();
    _recorder?.dispose();
    _syncSubscription?.cancel();
    _highlightTimer?.cancel();
    _itemPositionsListener.itemPositions.removeListener(_onPositionsChanged);
    _timeline?.cancelSubscriptions();
    HardwareKeyboard.instance.removeHandler(_handleComposerPanelKey);
    ComposerFocus.instance.removeListener(_onComposerFocusRequested);
    _receiptsNotifier.dispose();
    _sendController.dispose();
    _inputFocusNode.dispose();
    _editController.dispose();
    _editFocusNode.dispose();
    super.dispose();
  }

  /// Focuses the message box when keyboard navigation asked for it. Plain
  /// `autofocus` isn't enough: the outgoing room's page is still mounted
  /// (fading out), so the route's scope has a focused child and Flutter
  /// drops the autofocus.
  void _onComposerFocusRequested() {
    if (ComposerFocus.instance.roomId != widget.room.id) return;
    ComposerFocus.instance.roomId = null;
    // On a fresh page the field isn't attached yet; the focus request
    // waits until it is.
    _inputFocusNode.requestFocus();
  }

  /// Sends a read receipt for the newest event while the room is open on
  /// the live timeline.
  void _maybeMarkRead() {
    final timeline = _timeline;
    if (_keepUnread || timeline == null || timeline.canRequestFuture) return;
    Event? lastEvent;
    for (final event in timeline.events) {
      if (event.status.isSynced) {
        lastEvent = event;
        break;
      }
    }
    if (lastEvent == null || lastEvent.eventId == _lastMarkedReadEventId) {
      return;
    }
    _lastMarkedReadEventId = lastEvent.eventId;
    NotificationService.clearRoomNotifications(widget.room.id);
    if (!(_settings?.sendReadReceipts ?? false)) return;
    timeline.setReadMarker().catchError((_) {});
  }

  Future<void> _loadTimeline() async {
    final timeline = await widget.room.getTimeline(
      onUpdate: () {
        _visibleEventsCache = null;
        if (mounted) setState(() {});
      },
    );
    if (!mounted) {
      timeline.cancelSubscriptions();
      return;
    }
    // Determine where the "New messages" divider belongs before the read
    // marker below moves the fully-read position.
    final events = _visibleEvents(timeline);
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      timeline.cancelSubscriptions();
      return;
    }
    final unreadFrom = prefs.getString(_unreadFromKey);
    final fullyRead = widget.room.fullyRead;
    if (_keepUnread) {
      // Reloaded (e.g. after a failed jump) while marked unread: keep the
      // divider where the user put it.
    } else if (unreadFrom != null &&
        widget.room.markedUnread &&
        events.any((event) => event.eventId == unreadFrom)) {
      _unreadMarkerEventId = unreadFrom;
    } else if (fullyRead.isNotEmpty) {
      final index = events.indexWhere((event) => event.eventId == fullyRead);
      if (index > 0) {
        _unreadMarkerEventId = events[index - 1].eventId;
      }
    }
    // Opening the room reads it, which ends a manual "Mark as unread".
    if (!_keepUnread) _clearMarkedUnread();
    setState(() {
      _timeline = timeline;
      _initialScrollIndex = 0;
    });
    final initialEventId = widget.initialEventId;
    if (initialEventId != null && !_jumpedToInitialEvent) {
      // One-shot: _jumpToEvent falls back to _loadTimeline on failure, which
      // must not retrigger the jump.
      _jumpedToInitialEvent = true;
      unawaited(_jumpToEvent(initialEventId));
    }
    if (!mounted || _keepUnread || !(_settings?.sendReadReceipts ?? false)) {
      return;
    }
    try {
      await timeline.setReadMarker();
    } catch (_) {}
  }

  bool _jumpedToInitialEvent = false;

  /// Flags the room unread from [event] on: sets `m.marked_unread` so every
  /// client shows it unread, and moves the "New messages" divider here.
  Future<void> _markUnread(Event event) async {
    setState(() {
      _keepUnread = true;
      _unreadMarkerEventId = event.eventId;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_unreadFromKey, event.eventId);
      await widget.room.markUnread(true);
    } catch (e) {
      _showError(e);
    }
  }

  void _clearMarkedUnread() {
    _keepUnread = false;
    SharedPreferences.getInstance()
        .then((prefs) => prefs.remove(_unreadFromKey))
        .catchError((_) => false);
    if (widget.room.markedUnread) {
      widget.room.markUnread(false).catchError((_) {});
    }
  }

  /// Read receipts for the bubbles, updated from the sync listener without
  /// rebuilding the page: every mounted bubble rebuilding on each receipt
  /// (constant churn in busy rooms) is what made large chats lag.
  late final ValueNotifier<Map<String, List<User>>> _receiptsNotifier =
      ValueNotifier(_receiptsByEvent());

  /// Users (excluding ourselves) whose latest read receipt points at each
  /// event.
  Map<String, List<User>> _receiptsByEvent() {
    final result = <String, List<User>>{};
    for (final entry in widget.room.receiptState.global.otherUsers.entries) {
      if (entry.key == _client.userID) continue;
      final user = widget.room.unsafeGetUserFromMemoryOrFallback(entry.key);
      result.putIfAbsent(entry.value.eventId, () => []).add(user);
    }
    return result;
  }

  void _onPositionsChanged() {
    final timeline = _timeline;
    if (timeline == null) return;
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;
    var minIndex = positions.first.index;
    var maxIndex = positions.first.index;
    for (final position in positions) {
      if (position.index < minIndex) minIndex = position.index;
      if (position.index > maxIndex) maxIndex = position.index;
    }
    // The list is reversed: high indices are the oldest loaded messages,
    // index 0 is the newest.
    if (maxIndex >= _visibleEvents(timeline).length - 3 &&
        timeline.canRequestHistory &&
        !timeline.isRequestingHistory) {
      timeline.requestHistory();
    }
    if (minIndex <= 1 &&
        timeline.canRequestFuture &&
        !timeline.isRequestingFuture) {
      unawaited(_requestFutureKeepingPosition(timeline, positions));
    }
  }

  /// Loads newer messages of a jumped-to history timeline without moving
  /// the view. The list is reversed, so newer messages are inserted at
  /// index 0 and shift every index; without correcting for that the list
  /// would show the newly loaded messages instead of the ones being read.
  Future<void> _requestFutureKeepingPosition(
    Timeline timeline,
    Iterable<ItemPosition> positions,
  ) async {
    final events = _visibleEvents(timeline);
    // Anchor on the visible message nearest the middle of the viewport.
    ItemPosition? anchor;
    for (final position in positions) {
      if (position.index >= events.length) continue;
      if (anchor == null ||
          (position.itemLeadingEdge - 0.5).abs() <
              (anchor.itemLeadingEdge - 0.5).abs()) {
        anchor = position;
      }
    }
    final anchorEventId = anchor == null ? null : events[anchor.index].eventId;
    try {
      await timeline.requestFuture();
    } catch (_) {
      return;
    }
    if (!mounted || anchor == null || _timeline != timeline) return;
    final newIndex = _visibleEvents(
      timeline,
    ).indexWhere((event) => event.eventId == anchorEventId);
    if (newIndex == -1 ||
        newIndex == anchor.index ||
        !_itemScrollController.isAttached) {
      return;
    }
    _itemScrollController.jumpTo(
      index: newIndex,
      alignment: anchor.itemLeadingEdge,
    );
  }

  void _scrollToIndex(int index) {
    if (_itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 300),
        alignment: 0.5,
      );
    }
  }

  void _highlight(String eventId) {
    _highlightTimer?.cancel();
    setState(() => _highlightedEventId = eventId);
    _highlightTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _highlightedEventId = null);
    });
  }

  /// Scrolls to [eventId], loading a timeline anchored around it when it is
  /// not in the currently loaded part of the history.
  Future<void> _jumpToEvent(String eventId) async {
    final timeline = _timeline;
    if (timeline != null) {
      final index = _visibleEvents(
        timeline,
      ).indexWhere((event) => event.eventId == eventId);
      if (index != -1) {
        _scrollToIndex(index);
        _highlight(eventId);
        return;
      }
    }
    timeline?.cancelSubscriptions();
    setState(() => _timeline = null);
    try {
      final contextTimeline = await widget.room.getTimeline(
        onUpdate: () {
          _visibleEventsCache = null;
          if (mounted) setState(() {});
        },
        eventContextId: eventId,
      );
      if (!mounted) {
        contextTimeline.cancelSubscriptions();
        return;
      }
      // Build the new list already positioned at the target. Starting at
      // the newest loaded message and animating from there would request
      // newer messages on the way, shifting the target's index mid-scroll.
      final index = _visibleEvents(
        contextTimeline,
      ).indexWhere((event) => event.eventId == eventId);
      setState(() {
        _timeline = contextTimeline;
        _initialScrollIndex = index == -1 ? 0 : index;
      });
      _highlight(eventId);
    } catch (e) {
      _showError(e);
      await _loadTimeline();
    }
  }

  /// Leaves a jumped-to history position and returns to the live timeline.
  Future<void> _returnToLive() async {
    final old = _timeline;
    setState(() => _timeline = null);
    old?.cancelSubscriptions();
    await _loadTimeline();
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  Future<void> _send() async {
    final text = _sendController.text.trim();
    if (text.isEmpty) return;
    // Validate slash commands before the SDK parses them: unknown commands
    // would be dropped silently. A double slash escapes to plain text.
    if (text.startsWith('/') && !text.startsWith('//')) {
      final command = text.substring(1).split(' ').first.toLowerCase();
      if (command == 'help') {
        _sendController.clear();
        setState(() => _commandSuggestions = []);
        _saveDraft('');
        _showCommandHelp();
        return;
      }
      if (!_client.commands.containsKey(command)) {
        _showError(context.l10n.unknownCommand(command));
        return;
      }
    }
    if (_commandSuggestions.isNotEmpty) {
      setState(() => _commandSuggestions = []);
    }
    if (_emojiSuggestions.isNotEmpty) {
      setState(() => _emojiSuggestions = []);
    }
    _sendController.clear();
    final replyTo = _replyTo;
    setState(() => _replyTo = null);
    _typingLastSent = null;
    _saveDraft('');
    widget.room.setTyping(false).catchError((_) {});
    // Replying means the room has been read after all.
    if (_keepUnread) _clearMarkedUnread();
    final wasInHistory = _timeline?.canRequestFuture ?? false;
    try {
      await widget.room.sendTextEvent(
        replaceEmojiShortcodes(text),
        inReplyTo: replyTo,
      );
      // When sending from a jumped-to history position, return to the live
      // timeline so the new message is visible.
      if (wasInHistory && mounted) await _returnToLive();
    } catch (e) {
      _showError(e);
    }
  }

  /// Opens the Discord-style editor in place of [event]'s text. The
  /// composer is left alone, so a draft (or a reply) in it survives.
  void _startEdit(Event event) {
    final timeline = _timeline;
    final text =
        (timeline == null ? event : event.getDisplayEvent(timeline)).rawBody;
    setState(() => _editing = event);
    _editController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    // The editor's field is only built with the next frame. A focus node
    // that is not in the tree yet takes the focus once it is, and one that
    // already is (switching from another edit) keeps it as it moves.
    _editFocusNode.requestFocus();
    if (timeline == null) return;
    // Arrow up can pick a message scrolled out of view.
    final index = _visibleEvents(
      timeline,
    ).indexWhere((e) => e.eventId == event.eventId);
    final fullyVisible = _itemPositionsListener.itemPositions.value.any(
      (position) =>
          position.index == index &&
          position.itemLeadingEdge >= 0 &&
          position.itemTrailingEdge <= 1,
    );
    if (index != -1 && !fullyVisible) _scrollToIndex(index);
  }

  /// Closes the in-place editor without changing the message and hands the
  /// keyboard back to the composer.
  void _cancelEdit() {
    if (_editing == null) return;
    setState(() => _editing = null);
    _inputFocusNode.requestFocus();
  }

  /// Saves the in-place edit. An unchanged or emptied text closes the
  /// editor without sending anything.
  Future<void> _submitEdit() async {
    final editing = _editing;
    if (editing == null) return;
    final timeline = _timeline;
    final original =
        (timeline == null ? editing : editing.getDisplayEvent(timeline)).rawBody
            .trim();
    final text = _editController.text.trim();
    _cancelEdit();
    if (text.isEmpty || text == original) return;
    try {
      await widget.room.sendTextEvent(
        replaceEmojiShortcodes(text),
        editEventId: editing.eventId,
        // A leading slash is message text here, not a command.
        parseCommands: false,
      );
    } catch (e) {
      _showError(e);
    }
  }

  /// Starts editing the newest own text message in the loaded timeline
  /// (arrow up in the empty composer, like Discord). Returns false when
  /// there is nothing editable yet.
  bool _editLastOwnMessage() {
    final timeline = _timeline;
    if (timeline == null) return false;
    for (final event in timeline.events) {
      if (event.senderId != _client.userID ||
          event.type != EventTypes.Message ||
          event.redacted ||
          event.status.isSending ||
          event.status.isError) {
        continue;
      }
      // Skip relations that are no standalone messages: edits (the
      // original is found further down) and thread replies.
      if (event.relationshipType == RelationshipTypes.edit ||
          event.relationshipType == RelationshipTypes.thread) {
        continue;
      }
      if (event.messageType != MessageTypes.Text &&
          event.messageType != MessageTypes.Emote &&
          event.messageType != MessageTypes.Notice) {
        continue;
      }
      _startEdit(event);
      return true;
    }
    return false;
  }

  void _onInputChanged(String text) {
    _saveDraft(text);
    _replaceCompletedShortcode();
    _updateMentionSuggestions();
    _updateCommandSuggestions();
    _updateEmojiSuggestions();
    if (!SettingsScope.of(context).sendTypingNotifications) return;
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

  /// Composer panel (emoji/GIF/sticker/poll) rising above the input bar
  /// instead of opening popup dialogs.
  _ComposerPanelKind? _composerPanel;

  /// Tap group shared by the panel and its toggle buttons, so pressing a
  /// toggle button doesn't first count as a tap outside the open panel.
  final Object _composerPanelTapGroup = Object();

  void _toggleComposerPanel(_ComposerPanelKind kind) {
    setState(() => _composerPanel = _composerPanel == kind ? null : kind);
  }

  /// Closes an open composer panel on Escape no matter where focus is
  /// (composer, panel search field, or nothing at all). Registered for the
  /// page's lifetime; defers to dialogs stacked above the room.
  bool _handleComposerPanelKey(KeyEvent event) {
    if (!mounted ||
        event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape ||
        _composerPanel == null) {
      return false;
    }
    if (ModalRoute.of(context)?.isCurrent != true) return false;
    _closeComposerPanel();
    return true;
  }

  void _closeComposerPanel() {
    if (_composerPanel == null) return;
    setState(() => _composerPanel = null);
  }

  Widget? _buildComposerPanel() {
    final kind = _composerPanel;
    if (kind == null) return null;
    final Widget content = switch (kind) {
      // Stays open so several emoji can be inserted in a row; Esc, the
      // toggle button or a tap elsewhere closes it. Width only: the grid
      // fills the panel's height cap.
      _ComposerPanelKind.emoji => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: EmojiPickerPanel(onSelected: _insertEmoji, room: widget.room),
      ),
      _ComposerPanelKind.gif => GifPickerPanel(
        client: _client,
        onPicked: (gif) {
          _closeComposerPanel();
          _sendGif(gif);
        },
        onClose: _closeComposerPanel,
      ),
      _ComposerPanelKind.sticker => StickerPickerPanel(
        room: widget.room,
        onClose: _closeComposerPanel,
      ),
      _ComposerPanelKind.poll => CreatePollPanel(
        room: widget.room,
        onClose: _closeComposerPanel,
      ),
    };
    // Shorter windows get a shorter panel; the timeline keeps the rest and
    // the composer stays glued to the bottom.
    final maxHeight = ((MediaQuery.sizeOf(context).height - 220).clamp(
      160.0,
      440.0,
    )).toDouble();
    return TapRegion(
      groupId: _composerPanelTapGroup,
      onTapOutside: (_) => _closeComposerPanel(),
      child: Container(
        clipBehavior: Clip.antiAlias,
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          boxShadow: kElevationToShadow[4],
        ),
        child: KeyedSubtree(key: ValueKey(kind), child: content),
      ),
    );
  }

  static const _imageExtensions = {
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
    'bmp',
    'avif',
    'heic',
    'tiff',
    'svg',
  };

  bool _looksLikeImage(String name, String? mimeType) =>
      (mimeType?.startsWith('image/') ?? false) ||
      _imageExtensions.contains(name.split('.').last.toLowerCase());

  /// Shows a preview of the picked [files] and sends them on confirmation.
  ///
  /// Each file gets a caption field. Anything already typed in the composer
  /// seeds the first one — attaching a file to a half-written message is
  /// how people expect to caption it — and is cleared once the send goes
  /// through.
  ///
  /// A caption is sent as its own text message right after its file rather
  /// than inside the file event, so it can be edited like any other message.
  Future<void> _stageAndSend(
    List<({Uint8List bytes, String name, String? mimeType})> files,
  ) async {
    if (files.isEmpty) return;
    final draft = _sendController.text.trim();
    final captionControllers = [
      for (var i = 0; i < files.length; i++)
        TextEditingController(text: i == 0 ? draft : ''),
    ];
    try {
      await _stageAndSendWithCaptions(files, captionControllers, draft);
    } finally {
      for (final controller in captionControllers) {
        controller.dispose();
      }
    }
  }

  Future<void> _stageAndSendWithCaptions(
    List<({Uint8List bytes, String name, String? mimeType})> files,
    List<TextEditingController> captionControllers,
    String draft,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.sendFilesTitle(files.length)),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, file) in files.indexed) ...[
                  if (_looksLikeImage(file.name, file.mimeType))
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: memoryImage(
                        file.bytes,
                        height: 160,
                        fit: BoxFit.contain,
                      ),
                    )
                  else
                    Row(
                      children: [
                        const Icon(Icons.insert_drive_file_outlined),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            file.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      '${file.name} · '
                      '${_MessageBubbleState._formatSize(file.bytes.length)}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: captionControllers[index],
                      autofocus: index == 0,
                      maxLines: 3,
                      minLines: 1,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => Navigator.of(context).pop(true),
                      decoration: InputDecoration(
                        isDense: true,
                        border: const OutlineInputBorder(),
                        hintText: context.l10n.addACaption,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.send),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // The composer text moved into the first caption, so it must not stay
    // behind as a draft that gets sent again.
    if (draft.isNotEmpty && _sendController.text.trim() == draft) {
      _sendController.clear();
      _saveDraft('');
    }
    for (final (index, file) in files.indexed) {
      final caption = captionControllers[index].text.trim();
      await _sendBytes(file.bytes, file.name, mimeType: file.mimeType);
      if (caption.isEmpty) continue;
      // Sent even if the file failed: a failed upload stays in the timeline
      // to retry, while text dropped here would be lost. Commands are not
      // parsed — the caption field never offered them.
      try {
        await widget.room.sendTextEvent(
          replaceEmojiShortcodes(caption),
          parseCommands: false,
        );
      } catch (e) {
        _showError(e);
      }
    }
  }

  Future<void> _startRecording() async {
    // The recording bar replaces the composer the panel is anchored to.
    _closeComposerPanel();
    final recorder = AudioRecorder();
    try {
      if (!await recorder.hasPermission()) {
        if (mounted) _showError(context.l10n.microphonePermissionDenied);
        await recorder.dispose();
        return;
      }
      final dir = await temporaryDirectory();
      final path = '${dir.path}/protea_voice_${widget.room.id.hashCode}.m4a';
      await recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
        path: path,
      );
      if (!mounted) {
        await recorder.dispose();
        return;
      }
      setState(() {
        _recorder = recorder;
        _recording = true;
        _recordingAmplitudes.clear();
        _recordingStart = DateTime.now();
      });
      _recordingTimer = Timer.periodic(const Duration(milliseconds: 150), (
        _,
      ) async {
        final amplitude = await recorder.getAmplitude();
        // dBFS, roughly -40 (silence) to 0 (max).
        final normalized = ((amplitude.current + 40) / 40).clamp(0.0, 1.0);
        if (mounted && _recording) {
          setState(() => _recordingAmplitudes.add(normalized));
        }
      });
    } catch (e) {
      _showError(e);
      await recorder.dispose();
    }
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    final recorder = _recorder;
    setState(() {
      _recording = false;
      _recorder = null;
    });
    try {
      final path = await recorder?.stop();
      await recorder?.dispose();
      if (path != null) await File(path).delete();
    } catch (_) {}
  }

  Future<void> _sendRecording() async {
    _recordingTimer?.cancel();
    final recorder = _recorder;
    final start = _recordingStart;
    final amplitudes = List<double>.from(_recordingAmplitudes);
    setState(() {
      _recording = false;
      _recorder = null;
    });
    if (recorder == null || start == null) return;
    try {
      final path = await recorder.stop();
      await recorder.dispose();
      if (path == null) return;
      final bytes = await File(path).readAsBytes();
      try {
        await File(path).delete();
      } catch (_) {}
      final durationMs = DateTime.now().difference(start).inMilliseconds;
      // MSC3245 waveform: up to ~50 samples in the range 0..1024.
      const sampleCount = 50;
      final waveform = <int>[];
      for (var i = 0; i < sampleCount; i++) {
        if (amplitudes.isEmpty) {
          waveform.add(512);
          continue;
        }
        final index = (i * amplitudes.length / sampleCount).floor().clamp(
          0,
          amplitudes.length - 1,
        );
        waveform.add((amplitudes[index] * 1024).round().clamp(0, 1024));
      }
      final file = MatrixAudioFile(
        bytes: bytes,
        name: 'Voice message.m4a',
        mimeType: 'audio/mp4',
        duration: durationMs,
      );
      await widget.room.sendFileEvent(
        file,
        extraContent: {
          'org.matrix.msc1767.audio': {
            'duration': durationMs,
            'waveform': waveform,
          },
          'org.matrix.msc3245.voice': <String, Object?>{},
        },
      );
    } catch (e) {
      _showError(e);
    }
  }

  Widget _buildRecordingBar() {
    final colorScheme = Theme.of(context).colorScheme;
    final elapsed = _recordingStart == null
        ? Duration.zero
        : DateTime.now().difference(_recordingStart!);
    final recent = _recordingAmplitudes.length > 60
        ? _recordingAmplitudes.sublist(_recordingAmplitudes.length - 60)
        : _recordingAmplitudes;
    return Row(
      children: [
        IconButton(
          tooltip: context.l10n.discardRecording,
          icon: Icon(Icons.delete_outline, color: colorScheme.error),
          onPressed: _cancelRecording,
        ),
        Icon(Icons.mic, size: 18, color: colorScheme.error),
        const SizedBox(width: 4),
        Text(formatAudioDuration(elapsed)),
        const SizedBox(width: 8),
        Expanded(
          child: Waveform(
            values: recent.isEmpty ? const [0.1] : recent,
            progress: 1,
            height: 24,
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: context.l10n.sendVoiceMessage,
          onPressed: _sendRecording,
          icon: const Icon(Icons.send),
        ),
      ],
    );
  }

  Future<void> _sendGif(PickedGif gif) async {
    final title = gif.title.trim();
    final name = '${title.isEmpty ? 'gif' : title}.gif';
    final settings = SettingsScope.of(context);
    final proxied = settings.gifProxyEnabled
        ? gifProxyMxcUrl(gif.url, settings.gifProxyServer)
        : null;
    // Through the proxy nothing is downloaded or uploaded: the event just
    // points at the proxy's mxc URI, so there is no pipeline to show a
    // skeleton for. A GIF the proxy can't resolve falls through and is sent
    // the normal way.
    if (proxied != null) {
      try {
        await widget.room.sendEvent(
          gifProxyImageContent(
            name: name,
            mxcUrl: proxied,
            width: gif.width,
            height: gif.height,
            size: gif.size,
          ),
        );
      } catch (e) {
        _showError(e);
      }
      return;
    }
    // One pending entry spans the whole pipeline (Klipy download, upload,
    // send), so the skeleton appears the moment the GIF is picked.
    final pending = _PendingSend(name: name, isImage: true);
    setState(() => _pendingSends.add(pending));
    try {
      final response = await _client.httpClient.get(Uri.parse(gif.url));
      if (response.statusCode != 200) {
        throw Exception('GIF download failed (HTTP ${response.statusCode})');
      }
      await _sendBytes(
        response.bodyBytes,
        name,
        mimeType: 'image/gif',
        showPending: false,
      );
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _pendingSends.remove(pending));
    }
  }

  /// The first frame of [bytes], decoded by the engine and scaled down to
  /// at most 512 px wide, PNG-encoded — a cheap static thumbnail for
  /// animated GIFs. Returns null when decoding fails (the SDK then falls
  /// back to its own generator).
  Future<MatrixImageFile?> _firstFrameThumbnail(
    Uint8List bytes, {
    int? width,
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        // Cap the decode size, but never upscale a smaller image.
        targetWidth: width != null && width < 512 ? width : 512,
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      final image = frame.image;
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final (thumbWidth, thumbHeight) = (image.width, image.height);
      image.dispose();
      if (data == null) return null;
      return MatrixImageFile(
        bytes: data.buffer.asUint8List(),
        name: 'thumbnail.png',
        mimeType: 'image/png',
        width: thumbWidth,
        height: thumbHeight,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _attachFile() async {
    final picked = await openFile();
    if (picked == null) return;
    await _stageAndSend([
      (
        bytes: await picked.readAsBytes(),
        name: picked.name,
        mimeType: picked.mimeType,
      ),
    ]);
  }

  Future<void> _sendBytes(
    Uint8List bytes,
    String name, {
    String? mimeType,
    bool showPending = true,
  }) async {
    final extension = name.split('.').last.toLowerCase();
    final isImage =
        (mimeType?.startsWith('image/') ?? false) ||
        _imageExtensions.contains(extension);
    final pending = showPending
        ? _PendingSend(name: name, isImage: isImage)
        : null;
    if (pending != null) setState(() => _pendingSends.add(pending));
    try {
      MatrixFile file;
      MatrixImageFile? thumbnail;
      if (isImage) {
        int? width;
        int? height;
        final svg = looksLikeSvg(bytes);
        if (svg) {
          // The engine can't decode SVG, and neither can the SDK's
          // thumbnailer: take the size from the document and send a PNG
          // rendering as the thumbnail, for clients that can't draw SVG.
          final raster = await rasterizeSvg(bytes, maxExtent: 800);
          if (raster != null) {
            width = raster.intrinsicWidth;
            height = raster.intrinsicHeight;
            thumbnail = MatrixImageFile(
              bytes: raster.png,
              name: 'thumbnail.png',
              mimeType: 'image/png',
              width: raster.width,
              height: raster.height,
            );
          }
        } else {
          try {
            final image = await decodeImageFromList(bytes);
            width = image.width;
            height = image.height;
            image.dispose();
          } catch (_) {}
        }
        file = MatrixImageFile(
          bytes: bytes,
          name: name,
          // Pasted files arrive without a mimetype, and the SDK's sniffing
          // only knows SVG by its file extension.
          mimeType: mimeType ?? (svg ? 'image/svg+xml' : null),
          width: width,
          height: height,
        );
        // The SDK generates missing thumbnails in pure Dart; for animated
        // GIFs that decodes every frame and re-encodes the whole GIF —
        // many seconds for a typical file. A PNG of the engine-decoded
        // first frame does the same job in milliseconds.
        if (mimeType == 'image/gif' || extension == 'gif') {
          thumbnail = await _firstFrameThumbnail(bytes, width: width);
        }
      } else {
        file = MatrixFile(bytes: bytes, name: name, mimeType: mimeType);
      }
      await widget.room.sendFileEvent(file, thumbnail: thumbnail);
    } catch (e) {
      _showError(e);
    } finally {
      if (pending != null && mounted) {
        setState(() => _pendingSends.remove(pending));
      }
    }
  }

  Future<void> _onDropFiles(DropDoneDetails details) async {
    setState(() => _dragging = false);
    final files = <({Uint8List bytes, String name, String? mimeType})>[];
    for (final file in details.files) {
      files.add((
        bytes: await file.readAsBytes(),
        name: file.name,
        mimeType: file.mimeType,
      ));
    }
    await _stageAndSend(files);
  }

  late final _composerPasteAction = _ComposerPasteAction(_pasteFromClipboard);

  /// Ctrl/Cmd+V in the composer. Files copied in a file manager are offered
  /// for sending instead of pasting their names, which come along as text;
  /// on macOS they also carry the file's icon as image data, so they must
  /// win over the image check. Otherwise [pasteText] pastes the text as
  /// usual and an image on the clipboard (a screenshot, an image copied in
  /// a browser) is offered for sending as well.
  Future<void> _pasteFromClipboard(VoidCallback pasteText) async {
    var files = const <File>[];
    try {
      files = await readClipboardFiles();
    } catch (e, s) {
      Logs().w('Could not read files from the clipboard', e, s);
    }
    if (!mounted) return;
    if (files.isNotEmpty) {
      try {
        await _stageAndSend([
          for (final file in files)
            (
              bytes: await file.readAsBytes(),
              name: p.basename(file.path),
              mimeType: null,
            ),
        ]);
      } catch (e) {
        _showError(e);
      }
      return;
    }
    pasteText();
    try {
      final bytes = await Pasteboard.image;
      if (bytes == null || bytes.isEmpty || !mounted) return;
      await _stageAndSend([
        (bytes: bytes, name: 'pasted-image.png', mimeType: 'image/png'),
      ]);
    } catch (e, s) {
      Logs().w('Could not read an image from the clipboard', e, s);
    }
  }

  Future<void> _saveAttachment(Event event) => saveAttachment(context, event);

  /// Cache for [_visibleEvents]: the filter is O(loaded events) and runs on
  /// every rebuild and scroll notification, which adds up once a lot of
  /// history is loaded. Cleared by the timeline's onUpdate callbacks (the
  /// only paths that change the event list) and on dependency changes
  /// (settings can alter the filter).
  List<Event>? _visibleEventsCache;
  Timeline? _visibleEventsCacheFor;

  List<Event> _visibleEvents(Timeline timeline) {
    if (_visibleEventsCacheFor == timeline && _visibleEventsCache != null) {
      return _visibleEventsCache!;
    }
    final settings = SettingsScope.of(context);
    final events = timeline.events.where((event) {
      if (!_bubbleTypes.contains(event.type) &&
          event.type != EventTypes.RoomMember) {
        return false;
      }
      if (event.relationshipType == RelationshipTypes.edit ||
          // Thread replies only show in the thread panel.
          event.relationshipType == RelationshipTypes.thread ||
          event.type == EventTypes.Reaction) {
        return false;
      }
      if (event.type == EventTypes.RoomMember) {
        // A member event that keeps membership 'join' is a display name
        // or avatar change; everything else is a join/leave/invite/ban.
        final isProfileChange =
            event.content['membership'] == 'join' &&
            event.prevContent?['membership'] == 'join';
        return isProfileChange
            ? settings.showProfileChangeEvents
            : settings.showMembershipEvents;
      }
      if (event.redacted && !settings.showDeletedMessages) return false;
      return true;
    }).toList();
    _visibleEventsCacheFor = timeline;
    _visibleEventsCache = events;
    return events;
  }

  void _openThread(Event event) {
    setState(() => _threadRoot = event);
  }

  /// Suggests members while an `@word` fragment is being typed before the
  /// cursor.
  /// Matches an unclosed `:shortcode` fragment right before the cursor;
  /// the colon must start a word so URLs (`https:`) and times don't
  /// trigger suggestions.
  static final _shortcodeFragment = RegExp(r'(?:^|\s):([a-zA-Z0-9_+\-]{2,})$');

  /// Emoji shortcode suggestions for the fragment being typed, Discord
  /// style: shown above the composer, tap to insert.
  List<MapEntry<String, String>> _emojiSuggestions = [];

  void _updateEmojiSuggestions() {
    final text = _sendController.text;
    final selection = _sendController.selection;
    final cursor = selection.isValid ? selection.baseOffset : text.length;
    final match = _shortcodeFragment.firstMatch(text.substring(0, cursor));
    if (match == null) {
      if (_emojiSuggestions.isNotEmpty) {
        setState(() => _emojiSuggestions = []);
      }
      return;
    }
    final query = match.group(1)!.toLowerCase();
    // Prefix matches first, then substring matches, capped for the panel.
    final prefix = <MapEntry<String, String>>[];
    final contains = <MapEntry<String, String>>[];
    for (final entry in emojiShortcodes.entries) {
      if (entry.key.startsWith(query)) {
        prefix.add(entry);
      } else if (entry.key.contains(query)) {
        contains.add(entry);
      }
    }
    setState(
      () => _emojiSuggestions = [...prefix, ...contains].take(6).toList(),
    );
  }

  void _insertEmojiSuggestion(MapEntry<String, String> suggestion) {
    final text = _sendController.text;
    final selection = _sendController.selection;
    final cursor = selection.isValid ? selection.baseOffset : text.length;
    final match = _shortcodeFragment.firstMatch(text.substring(0, cursor));
    if (match == null) return;
    final colon = text.lastIndexOf(':', cursor - 1);
    final newText = text.replaceRange(colon, cursor, '${suggestion.value} ');
    _sendController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: colon + suggestion.value.length + 1,
      ),
    );
    setState(() => _emojiSuggestions = []);
    _saveDraft(newText);
  }

  /// Typing the closing colon of a known shortcode replaces it with the
  /// emoji right in the field, so the message previews what will be sent.
  void _replaceCompletedShortcode() {
    final text = _sendController.text;
    final selection = _sendController.selection;
    final cursor = selection.isValid ? selection.baseOffset : text.length;
    final match = RegExp(
      r'(?:^|\s):([a-zA-Z0-9_+\-]+):$',
    ).firstMatch(text.substring(0, cursor));
    if (match == null) return;
    final emoji = emojiShortcodes[match.group(1)!.toLowerCase()];
    if (emoji == null) return;
    final colon = text.lastIndexOf(':', cursor - 2);
    final newText = text.replaceRange(colon, cursor, emoji);
    _sendController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: colon + emoji.length),
    );
  }

  void _updateMentionSuggestions() {
    final text = _sendController.text;
    final selection = _sendController.selection;
    final cursor = selection.isValid ? selection.baseOffset : text.length;
    final match = RegExp(r'@(\w*)$').firstMatch(text.substring(0, cursor));
    if (match == null) {
      if (_mentionSuggestions.isNotEmpty) {
        setState(() => _mentionSuggestions = []);
      }
      return;
    }
    final query = match.group(1)!.toLowerCase();
    final suggestions = widget.room
        .getParticipants()
        .where(
          (user) =>
              user.membership == Membership.join &&
              user.id != _client.userID &&
              (user.nickOrDisplayname.toLowerCase().startsWith(query) ||
                  user.calcDisplayname().toLowerCase().startsWith(query) ||
                  user.id.toLowerCase().substring(1).startsWith(query)),
        )
        .take(5)
        .toList();
    setState(() => _mentionSuggestions = suggestions);
  }

  void _insertMention(User user) {
    final text = _sendController.text;
    final selection = _sendController.selection;
    final cursor = selection.isValid ? selection.baseOffset : text.length;
    final match = RegExp(r'@(\w*)$').firstMatch(text.substring(0, cursor));
    if (match == null) return;
    // Mention fragments are converted to matrix.to pills by the SDK's
    // markdown parser on send; the raw ID works as a plain fallback.
    final fragments = user.mentionFragments;
    final mention = fragments.isNotEmpty ? fragments.first : user.id;
    final newText = text.replaceRange(match.start, cursor, '$mention ');
    _sendController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: match.start + mention.length + 1,
      ),
    );
    setState(() => _mentionSuggestions = []);
    _saveDraft(newText);
  }

  /// Suggests slash commands while the composer holds only `/word`.
  void _updateCommandSuggestions() {
    final match = RegExp(
      r'^/([a-zA-Z]*)$',
    ).firstMatch(_sendController.text.trimRight());
    if (match == null) {
      if (_commandSuggestions.isNotEmpty) {
        setState(() => _commandSuggestions = []);
      }
      return;
    }
    final query = match.group(1)!.toLowerCase();
    setState(
      () => _commandSuggestions = slashCommands
          .where((command) => command.name.startsWith(query))
          .toList(),
    );
  }

  void _applyCommandSuggestion(SlashCommand command) {
    setState(() => _commandSuggestions = []);
    if (command.name == 'help') {
      _sendController.clear();
      _saveDraft('');
      _showCommandHelp();
      return;
    }
    final text = command.argsHint.isEmpty
        ? '/${command.name}'
        : '/${command.name} ';
    _sendController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _saveDraft(text);
  }

  void _showCommandHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.commands),
        content: SizedBox(
          width: 420,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final command in slashCommands)
                ListTile(
                  dense: true,
                  title: Text('/${command.name} ${command.argsHint}'.trim()),
                  subtitle: Text(
                    localizedCommandDescription(context.l10n, command),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(context.l10n.doubleSlashHint),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.close),
          ),
        ],
      ),
    );
  }

  /// Skeleton bubbles for uploads in flight, right-aligned like own
  /// messages, so picking a GIF or file gives immediate feedback.
  Widget _buildPendingSends() {
    if (_pendingSends.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final pending in _pendingSends)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _PendingSendBubble(pending: pending),
            ),
        ],
      ),
    );
  }

  /// Last non-empty typing text, kept so the label can fade out instead of
  /// vanishing the moment everyone stops typing.
  String _lastTypingText = '';

  Widget _buildTypingIndicator() {
    return StreamBuilder<SyncUpdate>(
      stream: _client.onSync.stream,
      builder: (context, _) {
        final names = widget.room.typingUsers
            .where((user) => user.id != _client.userID)
            .map((user) => user.nickOrDisplayname)
            .toList();
        final text = switch (names.length) {
          0 => '',
          1 => context.l10n.isTyping(names[0]),
          2 => context.l10n.areTyping(names[0], names[1]),
          _ => context.l10n.manyTyping(names.length),
        };
        if (text.isNotEmpty) _lastTypingText = text;
        return SizedBox(
          height: 18,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedOpacity(
                opacity: text.isEmpty ? 0 : 1,
                duration: Motion.short,
                child: Text(
                  text.isEmpty ? _lastTypingText : text,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Whether the markdown formatting toolbar shows above the composer.
  bool _formattingBar = false;

  /// Wraps the composer selection in markdown markers ([suffix] defaults
  /// to [prefix]); with no selection the markers are inserted and the
  /// caret placed between them.
  void _wrapSelection(String prefix, [String? suffix]) {
    _sendController.value = _wrappedSelection(
      _sendController.value,
      prefix,
      suffix ?? prefix,
    );
    _saveDraft(_sendController.text);
    _inputFocusNode.requestFocus();
  }

  /// Inserts a markdown link: the selected text becomes the label and the
  /// caret selects the url placeholder for immediate typing.
  void _insertLink() {
    final text = _sendController.text;
    final selection = _sendController.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final selected = text.substring(start, end);
    final label = selected.isEmpty ? 'text' : selected;
    const placeholder = 'url';
    // '[' + label + ']('
    final urlStart = start + label.length + 3;
    _sendController.value = TextEditingValue(
      text: text.replaceRange(start, end, '[$label]($placeholder)'),
      selection: TextSelection(
        baseOffset: urlStart,
        extentOffset: urlStart + placeholder.length,
      ),
    );
    _saveDraft(_sendController.text);
    _inputFocusNode.requestFocus();
  }

  /// Markdown formatting toolbar; the SDK's markdown parser turns the
  /// markers into formatted messages on send.
  Widget? _buildFormattingBar() {
    if (!_formattingBar) return null;
    final colorScheme = Theme.of(context).colorScheme;
    Widget button(String tooltip, IconData icon, VoidCallback onPressed) =>
        IconButton(
          tooltip: tooltip,
          icon: Icon(icon, size: 18),
          visualDensity: VisualDensity.compact,
          onPressed: onPressed,
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  button(
                    context.l10n.formatBold,
                    Icons.format_bold,
                    () => _wrapSelection('**'),
                  ),
                  button(
                    context.l10n.formatItalic,
                    Icons.format_italic,
                    () => _wrapSelection('*'),
                  ),
                  button(
                    context.l10n.formatStrikethrough,
                    Icons.format_strikethrough,
                    () => _wrapSelection('~~'),
                  ),
                  button(
                    context.l10n.formatInlineCode,
                    Icons.code,
                    () => _wrapSelection('`'),
                  ),
                  button(
                    context.l10n.formatCodeBlock,
                    Icons.data_object,
                    () => _wrapSelection('```\n', '\n```'),
                  ),
                  button(
                    context.l10n.formatSpoiler,
                    Icons.visibility_off_outlined,
                    () => _wrapSelection('||'),
                  ),
                  button(context.l10n.formatLink, Icons.link, _insertLink),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _formattingBar = false),
          ),
        ],
      ),
    );
  }

  Widget? _buildReplyBar() {
    final replyTo = _replyTo;
    if (replyTo == null) return null;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: _ReplyTapTarget(
        onTap: () => _jumpToEvent(replyTo.eventId),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.reply, size: 20, color: colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    replyTo.senderFromMemoryOrFallback.nickOrDisplayname,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeline = _timeline;
    final encryptedWithoutSupport =
        widget.room.encrypted && !_client.encryptionEnabled;
    final directUserId = widget.room.directChatMatrixID;
    final displayname = widget.room.nickOrDisplayname;
    return LayoutBuilder(
      builder: (context, constraints) {
        // On narrow panes the member list overlays the chat as an end
        // drawer instead of squeezing the content aside.
        final overlayMembers = constraints.maxWidth < 600;
        return Scaffold(
          key: _pageScaffoldKey,
          endDrawer: overlayMembers
              ? Drawer(width: 280, child: MemberListPanel(room: widget.room))
              : null,
          appBar: AppBar(
            leading: widget.onOpenMenu != null
                ? IconButton(
                    tooltip: context.l10n.channels,
                    icon: const Icon(Icons.menu),
                    onPressed: widget.onOpenMenu,
                  )
                : null,
            title: Row(
              children: [
                if (directUserId != null)
                  // Builder so the profile popover anchors to the avatar,
                  // not the whole page.
                  Builder(
                    builder: (context) => GestureDetector(
                      onTap: () => showUserProfileCard(
                        context,
                        client: _client,
                        userId: directUserId,
                        displayName: displayname,
                        avatarUrl: widget.room.avatar,
                        room: widget.room,
                      ),
                      child: PresenceAvatar(
                        client: _client,
                        userId: directUserId,
                        name: displayname,
                        avatarUrl: widget.room.avatar,
                        radius: 16,
                      ),
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
            actions: [
              IconButton(
                tooltip: context.l10n.searchMessages,
                icon: const Icon(Icons.search),
                onPressed: () => showMessageSearch(
                  context,
                  widget.room,
                  onJumpToMessage: _jumpToEvent,
                ),
              ),
              IconButton(
                tooltip: context.l10n.pinnedMessages,
                icon: const Icon(Icons.push_pin_outlined),
                onPressed: () => showPinnedMessages(
                  context,
                  widget.room,
                  onJumpToMessage: _jumpToEvent,
                ),
              ),
              IconButton(
                tooltip: context.l10n.members,
                icon: Icon(
                  SettingsScope.of(context).showMemberList
                      ? Icons.people
                      : Icons.people_outline,
                ),
                onPressed: () {
                  if (overlayMembers) {
                    _pageScaffoldKey.currentState?.openEndDrawer();
                    return;
                  }
                  final settings = SettingsScope.of(context);
                  settings.setShowMemberList(!settings.showMemberList);
                },
              ),
              IconButton(
                tooltip: context.l10n.channelSettings,
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => showRoomSettingsDialog(context, widget.room),
              ),
            ],
          ),
          body: DropTarget(
            onDragDone: _onDropFiles,
            onDragEntered: (_) => setState(() => _dragging = true),
            onDragExited: (_) => setState(() => _dragging = false),
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          if (encryptedWithoutSupport)
                            MaterialBanner(
                              content: Text(
                                context.l10n.roomEncryptedNoE2eeSupport,
                              ),
                              leading: const Icon(Icons.lock_outline),
                              actions: const [SizedBox.shrink()],
                            ),
                          Expanded(
                            child: Stack(
                              children: [
                                // Behind the messages only: the composer and
                                // the member list keep their solid surfaces
                                // so their text stays readable.
                                const Positioned.fill(child: ChatWallpaper()),
                                timeline == null
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    // SelectionArea makes every message text
                                    // mouse-selectable and copyable.
                                    : SelectionArea(
                                        child: _TimelineList(
                                          // A new timeline (jump or return
                                          // to live) gets a fresh list so
                                          // its initial position applies.
                                          key: ObjectKey(timeline),
                                          timeline: timeline,
                                          initialScrollIndex:
                                              _initialScrollIndex,
                                          events: _visibleEvents(timeline),
                                          itemScrollController:
                                              _itemScrollController,
                                          itemPositionsListener:
                                              _itemPositionsListener,
                                          client: _client,
                                          highlightedEventId:
                                              _highlightedEventId,
                                          unreadMarkerEventId:
                                              _unreadMarkerEventId,
                                          receiptsByEvent: _receiptsNotifier,
                                          onReply: (event) {
                                            setState(() => _replyTo = event);
                                            _inputFocusNode.requestFocus();
                                          },
                                          onEdit: _startEdit,
                                          editingEventId: _editing?.eventId,
                                          editor: _InlineMessageEditor(
                                            key: _editorKey,
                                            controller: _editController,
                                            focusNode: _editFocusNode,
                                            onSave: _submitEdit,
                                            onCancel: _cancelEdit,
                                          ),
                                          onOpenThread: _openThread,
                                          onSaveAttachment: _saveAttachment,
                                          onMarkUnread: _markUnread,
                                          onJumpToMessage: _jumpToEvent,
                                        ),
                                      ),
                                Positioned(
                                  right: 16,
                                  bottom: 12,
                                  child: _JumpToLiveButton(
                                    visible:
                                        timeline?.canRequestFuture ?? false,
                                    onPressed: _returnToLive,
                                  ),
                                ),
                                // Floats over the messages instead of
                                // squeezing them upwards. Bounded on both
                                // sides so the panel shrinks to the pane
                                // width on narrow screens instead of
                                // overflowing off the left edge.
                                Positioned(
                                  left: 8,
                                  right: 8,
                                  bottom: 8,
                                  child: Align(
                                    alignment: Alignment.bottomRight,
                                    child: CollapsiblePanel(
                                      axis: Axis.vertical,
                                      alignment: Alignment.bottomCenter,
                                      child: _buildComposerPanel(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildPendingSends(),
                          _buildTypingIndicator(),
                          // Bars and suggestion panels rise out of the
                          // composer and slide back into it when dismissed.
                          CollapsiblePanel(
                            axis: Axis.vertical,
                            alignment: Alignment.bottomCenter,
                            child: _buildReplyBar(),
                          ),
                          CollapsiblePanel(
                            axis: Axis.vertical,
                            alignment: Alignment.bottomCenter,
                            child: _buildFormattingBar(),
                          ),
                          CollapsiblePanel(
                            axis: Axis.vertical,
                            alignment: Alignment.bottomCenter,
                            child: _commandSuggestions.isEmpty
                                ? null
                                : Container(
                                    margin: const EdgeInsets.fromLTRB(
                                      8,
                                      4,
                                      8,
                                      0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    constraints: const BoxConstraints(
                                      maxHeight: 240,
                                    ),
                                    child: ListView(
                                      shrinkWrap: true,
                                      children: [
                                        for (final command
                                            in _commandSuggestions)
                                          ListTile(
                                            dense: true,
                                            title: Text(
                                              '/${command.name} ${command.argsHint}'
                                                  .trim(),
                                            ),
                                            subtitle: Text(
                                              localizedCommandDescription(
                                                context.l10n,
                                                command,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            onTap: () =>
                                                _applyCommandSuggestion(
                                                  command,
                                                ),
                                          ),
                                      ],
                                    ),
                                  ),
                          ),
                          CollapsiblePanel(
                            axis: Axis.vertical,
                            alignment: Alignment.bottomCenter,
                            child: _mentionSuggestions.isEmpty
                                ? null
                                : Container(
                                    margin: const EdgeInsets.fromLTRB(
                                      8,
                                      4,
                                      8,
                                      0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    constraints: const BoxConstraints(
                                      maxHeight: 240,
                                    ),
                                    child: ListView(
                                      shrinkWrap: true,
                                      children: [
                                        for (final user in _mentionSuggestions)
                                          ListTile(
                                            dense: true,
                                            leading: MxcAvatar(
                                              client: _client,
                                              name: user.nickOrDisplayname,
                                              avatarUrl: user.avatarUrl,
                                              radius: 12,
                                            ),
                                            title: Text(
                                              user.nickOrDisplayname,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            subtitle: Text(
                                              user.id,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            onTap: () => _insertMention(user),
                                          ),
                                      ],
                                    ),
                                  ),
                          ),
                          CollapsiblePanel(
                            axis: Axis.vertical,
                            alignment: Alignment.bottomCenter,
                            child: _emojiSuggestions.isEmpty
                                ? null
                                : Container(
                                    margin: const EdgeInsets.fromLTRB(
                                      8,
                                      4,
                                      8,
                                      0,
                                    ),
                                    constraints: const BoxConstraints(
                                      maxHeight: 240,
                                    ),
                                    // Material so the tiles' ink renders on
                                    // the panel color.
                                    child: Material(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(12),
                                      clipBehavior: Clip.antiAlias,
                                      child: ListView(
                                        shrinkWrap: true,
                                        children: [
                                          for (final suggestion
                                              in _emojiSuggestions)
                                            ListTile(
                                              dense: true,
                                              leading: Text(
                                                suggestion.value,
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                ),
                                              ),
                                              title: Text(
                                                ':${suggestion.key}:',
                                              ),
                                              onTap: () =>
                                                  _insertEmojiSuggestion(
                                                    suggestion,
                                                  ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                          SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                              child: _recording
                                  ? _buildRecordingBar()
                                  : Container(
                                      // Discord-style composer: one rounded box
                                      // with every control inside it.
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHigh,
                                        borderRadius: BorderRadius.circular(26),
                                      ),
                                      child: Row(
                                        // Icons hug the bottom while the field
                                        // grows over multiple lines.
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          const SizedBox(width: 4),
                                          SizedBox(
                                            height: 48,
                                            child: Center(
                                              child: TapRegion(
                                                groupId: _composerPanelTapGroup,
                                                child: PopupMenuButton<String>(
                                                  tooltip:
                                                      context.l10n.attachments,
                                                  enabled:
                                                      !encryptedWithoutSupport,
                                                  icon: Icon(
                                                    Icons.add_circle_outline,
                                                    size: 22,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                  onSelected: (value) {
                                                    switch (value) {
                                                      case 'file':
                                                        _attachFile();
                                                      case 'poll':
                                                        _toggleComposerPanel(
                                                          _ComposerPanelKind
                                                              .poll,
                                                        );
                                                      case 'sticker':
                                                        _toggleComposerPanel(
                                                          _ComposerPanelKind
                                                              .sticker,
                                                        );
                                                      case 'location':
                                                        showShareLocationDialog(
                                                          context,
                                                          widget.room,
                                                        );
                                                    }
                                                  },
                                                  itemBuilder: (context) => [
                                                    PopupMenuItem(
                                                      value: 'file',
                                                      child: Text(
                                                        context.l10n.attachFile,
                                                      ),
                                                    ),
                                                    PopupMenuItem(
                                                      value: 'poll',
                                                      child: Text(
                                                        context.l10n.poll,
                                                      ),
                                                    ),
                                                    PopupMenuItem(
                                                      value: 'sticker',
                                                      child: Text(
                                                        context.l10n.sticker,
                                                      ),
                                                    ),
                                                    PopupMenuItem(
                                                      value: 'location',
                                                      child: Text(
                                                        context.l10n.location,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Focus(
                                              onKeyEvent: (node, event) {
                                                if (event is! KeyDownEvent) {
                                                  return KeyEventResult.ignored;
                                                }
                                                // Enter sends, Shift+Enter (or any other
                                                // modifier) inserts a line break.
                                                if (event.logicalKey ==
                                                        LogicalKeyboardKey
                                                            .enter ||
                                                    event.logicalKey ==
                                                        LogicalKeyboardKey
                                                            .numpadEnter) {
                                                  final keyboard =
                                                      HardwareKeyboard.instance;
                                                  if (!keyboard
                                                          .isShiftPressed &&
                                                      !keyboard.isAltPressed &&
                                                      !keyboard
                                                          .isControlPressed &&
                                                      !keyboard.isMetaPressed) {
                                                    _send();
                                                    return KeyEventResult
                                                        .handled;
                                                  }
                                                  return KeyEventResult.ignored;
                                                }
                                                // Ctrl+B / Ctrl+I wrap the
                                                // selection in markdown.
                                                if (HardwareKeyboard
                                                        .instance
                                                        .isControlPressed ||
                                                    HardwareKeyboard
                                                        .instance
                                                        .isMetaPressed) {
                                                  if (event.logicalKey ==
                                                      LogicalKeyboardKey.keyB) {
                                                    _wrapSelection('**');
                                                    return KeyEventResult
                                                        .handled;
                                                  }
                                                  if (event.logicalKey ==
                                                      LogicalKeyboardKey.keyI) {
                                                    _wrapSelection('*');
                                                    return KeyEventResult
                                                        .handled;
                                                  }
                                                }
                                                // Arrow up in an empty
                                                // composer edits the own
                                                // last message, like
                                                // Discord (toggleable in
                                                // the settings).
                                                if (event.logicalKey ==
                                                        LogicalKeyboardKey
                                                            .arrowUp &&
                                                    _sendController
                                                        .text
                                                        .isEmpty &&
                                                    SettingsScope.of(
                                                      context,
                                                    ).arrowUpToEdit &&
                                                    _editLastOwnMessage()) {
                                                  return KeyEventResult.handled;
                                                }
                                                return KeyEventResult.ignored;
                                              },
                                              child: Actions(
                                                actions: {
                                                  PasteTextIntent:
                                                      _composerPasteAction,
                                                },
                                                child: TextField(
                                                  controller: _sendController,
                                                  focusNode: _inputFocusNode,
                                                  enabled:
                                                      !encryptedWithoutSupport,
                                                  decoration: InputDecoration(
                                                    hintText:
                                                        context.l10n.message,
                                                    border: InputBorder.none,
                                                    contentPadding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 12,
                                                        ),
                                                  ),
                                                  keyboardType:
                                                      TextInputType.multiline,
                                                  textInputAction:
                                                      TextInputAction.newline,
                                                  onChanged: _onInputChanged,
                                                  minLines: 1,
                                                  maxLines: 8,
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            height: 48,
                                            child: Center(
                                              child: IconButton(
                                                tooltip:
                                                    context.l10n.formatting,
                                                onPressed:
                                                    encryptedWithoutSupport
                                                    ? null
                                                    : () => setState(
                                                        () => _formattingBar =
                                                            !_formattingBar,
                                                      ),
                                                icon: Icon(
                                                  Icons.text_fields,
                                                  size: 22,
                                                  color: _formattingBar
                                                      ? Theme.of(
                                                          context,
                                                        ).colorScheme.primary
                                                      : Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            height: 48,
                                            child: Center(
                                              child: TapRegion(
                                                groupId: _composerPanelTapGroup,
                                                child: IconButton(
                                                  tooltip: context.l10n.gif,
                                                  onPressed:
                                                      encryptedWithoutSupport
                                                      ? null
                                                      : () =>
                                                            _toggleComposerPanel(
                                                              _ComposerPanelKind
                                                                  .gif,
                                                            ),
                                                  icon: Icon(
                                                    Icons.gif_box_outlined,
                                                    size: 22,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            height: 48,
                                            child: Center(
                                              child: TapRegion(
                                                groupId: _composerPanelTapGroup,
                                                child: IconButton(
                                                  tooltip: context.l10n.emoji,
                                                  onPressed:
                                                      encryptedWithoutSupport
                                                      ? null
                                                      : () =>
                                                            _toggleComposerPanel(
                                                              _ComposerPanelKind
                                                                  .emoji,
                                                            ),
                                                  icon: Icon(
                                                    Icons
                                                        .emoji_emotions_outlined,
                                                    size: 22,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            height: 48,
                                            child: Center(
                                              child: IconButton(
                                                tooltip:
                                                    context.l10n.voiceMessage,
                                                onPressed:
                                                    encryptedWithoutSupport
                                                    ? null
                                                    : _startRecording,
                                                icon: Icon(
                                                  Icons.mic_none,
                                                  size: 22,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            height: 48,
                                            child: Center(
                                              child: IconButton(
                                                tooltip: context.l10n.send,
                                                onPressed:
                                                    encryptedWithoutSupport
                                                    ? null
                                                    : _send,
                                                icon: Icon(
                                                  Icons.send,
                                                  size: 22,
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Side panels slide in and out instead of popping.
                    CollapsiblePanel(
                      child: _threadRoot == null || timeline == null
                          ? null
                          : _ThreadPanel(
                              room: widget.room,
                              timeline: timeline,
                              root: _threadRoot!,
                              onClose: () => setState(() => _threadRoot = null),
                            ),
                    ),
                    CollapsiblePanel(
                      child:
                          !overlayMembers &&
                              SettingsScope.of(context).showMemberList
                          ? MemberListPanel(room: widget.room)
                          : null,
                    ),
                  ],
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _dragging ? 1 : 0,
                      duration: Motion.quick,
                      child: Container(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.12),
                        alignment: Alignment.center,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.file_upload_outlined),
                                const SizedBox(width: 8),
                                Text(
                                  context.l10n.dropFilesToUpload,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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

/// The "jump to latest messages" button: scales and fades in while the
/// timeline is scrolled back in history, instead of popping.
class _JumpToLiveButton extends StatelessWidget {
  const _JumpToLiveButton({required this.visible, required this.onPressed});

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedScale(
        scale: visible ? 1 : 0.6,
        duration: Motion.short,
        curve: Motion.easeOut,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: Motion.short,
          child: FloatingActionButton.small(
            // No hero: room pages can stack (pushed full-screen over the
            // home layout), and duplicate FAB hero tags crash transitions.
            heroTag: null,
            tooltip: context.l10n.jumpToLatestMessages,
            onPressed: onPressed,
            child: const Icon(Icons.keyboard_double_arrow_down),
          ),
        ),
      ),
    );
  }
}

/// Right-side panel listing the members of the room.
/// Shows everyone in [room] — used for spaces, whose members aren't listed
/// beside any channel — in a searchable dialog.
Future<void> showMemberListDialog(BuildContext context, Room room) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 420,
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      room.nickOrDisplayname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.close,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(child: MemberListPanel(room: room, framed: false)),
          ],
        ),
      ),
    ),
  );
}

/// Searchable member list of [room], grouped by presence. Shown beside a
/// channel, and in a dialog for a whole space ([framed] off).
class MemberListPanel extends StatefulWidget {
  const MemberListPanel({super.key, required this.room, this.framed = true});

  final Room room;

  /// Draws the side-panel frame: fixed width, left border and room banner.
  final bool framed;

  @override
  State<MemberListPanel> createState() => MemberListPanelState();
}

class MemberListPanelState extends State<MemberListPanel> {
  StreamSubscription<CachedPresence>? _presenceSubscription;

  /// Presence (state and status message) per member, seeded by
  /// [_ensurePresence] and kept fresh by the presence stream.
  final _presenceByUser = <String, CachedPresence>{};
  final _presenceRequested = <String>{};

  /// Profile-field status text per member ([statusReadFields]), seeded by [_ensureStatus] and refreshed when a
  /// profile is invalidated (e.g. the user edits their status).
  final _statusByUser = <String, String>{};
  final _statusRequested = <String>{};

  final _searchController = TextEditingController();
  String _query = '';

  Room get room => widget.room;

  /// Whether [user] matches the search: nickname, display name or user ID.
  bool _matches(User user) {
    if (_query.isEmpty) return true;
    return [
      user.nickOrDisplayname,
      user.calcDisplayname(),
      user.id,
    ].any((text) => text.toLowerCase().contains(_query));
  }

  @override
  void initState() {
    super.initState();
    // Presence updates arrive per user; regroup the list live.
    _presenceSubscription = room.client.onPresenceChanged.stream.listen((
      presence,
    ) {
      if (mounted) {
        setState(() => _presenceByUser[presence.userid] = presence);
      }
    });
    profileUpdates.addListener(_onProfilesInvalidated);
    profileDrops.addListener(_onProfileDropped);
  }

  /// One member's profile was dropped (their presence hinted they edited
  /// their status): let the rebuild refetch just that member. The old text
  /// stays on the tile until the new one arrives, so nothing flickers.
  void _onProfileDropped() {
    final userId = droppedProfileUserId;
    if (!mounted || userId == null || !_statusRequested.contains(userId)) {
      return;
    }
    setState(() => _statusRequested.remove(userId));
  }

  void _onProfilesInvalidated() {
    if (!mounted) return;
    setState(() {
      // Refetch through the profile cache; only invalidated users actually
      // hit the network again.
      _statusRequested.clear();
      _statusByUser.clear();
    });
  }

  void _ensurePresence(User user) {
    if (!_presenceRequested.add(user.id)) return;
    () async {
      try {
        final presence = await room.client.fetchCurrentPresence(user.id);
        if (mounted) {
          setState(() => _presenceByUser[user.id] = presence);
        }
      } catch (_) {}
    }();
  }

  void _ensureStatus(User user) {
    if (!_statusRequested.add(user.id)) return;
    () async {
      final status = await fetchUserStatus(room.client, user.id);
      if (!mounted || status == _statusByUser[user.id]) return;
      setState(() {
        // A cleared status drops the entry, so the tile falls back to the
        // presence status message or the room role instead of keeping text
        // the user has removed.
        if (status == null) {
          _statusByUser.remove(user.id);
        } else {
          _statusByUser[user.id] = status;
        }
      });
    }();
  }

  @override
  void dispose() {
    profileDrops.removeListener(_onProfileDropped);
    profileUpdates.removeListener(_onProfilesInvalidated);
    _presenceSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showMemberMenu(
    BuildContext context,
    User user,
    Offset position,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final ignored = room.client.ignoredUsers.contains(user.id);
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      items: [
        // Not offered for yourself, nor in the direct chat with this user.
        if (user.id != room.client.userID && room.directChatMatrixID != user.id)
          PopupMenuItem(value: 'message', child: Text(context.l10n.message)),
        if (user.id != room.client.userID)
          PopupMenuItem(
            value: 'nickname',
            child: Text(context.l10n.setNickname),
          ),
        PopupMenuItem(
          value: 'ignore',
          child: Text(ignored ? context.l10n.unblock : context.l10n.block),
        ),
        if (user.canChangeUserPowerLevel) ...[
          if (user.powerLevel.level < PowerLevel.defaultAdminLevel)
            PopupMenuItem(
              value: 'power:100',
              child: Text(context.l10n.makeAdmin),
            ),
          if (user.powerLevel.level < PowerLevel.defaultModeratorLevel)
            PopupMenuItem(
              value: 'power:50',
              child: Text(context.l10n.makeModerator),
            ),
          if (user.powerLevel.level > PowerLevel.defaultUserLevel)
            PopupMenuItem(
              value: 'power:0',
              child: Text(context.l10n.resetToMember),
            ),
        ],
        if (user.canKick)
          PopupMenuItem(value: 'kick', child: Text(context.l10n.kick)),
        if (user.canBan)
          PopupMenuItem(value: 'ban', child: Text(context.l10n.ban)),
      ],
    );
    if (selected == null || !context.mounted) return;
    if (selected == 'message') {
      await openDirectChat(context, room.client, user.id);
      return;
    }
    if (selected == 'nickname') {
      await showNicknameDialog(context, room.client, user.id);
      return;
    }
    if (selected.startsWith('power:')) {
      final level = int.parse(selected.substring('power:'.length));
      if (level >= PowerLevel.defaultAdminLevel) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              context.l10n.makeUserAdminTitle(user.nickOrDisplayname),
            ),
            content: Text(context.l10n.makeAdminWarning),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.l10n.makeAdmin),
              ),
            ],
          ),
        );
        if (confirmed != true || !context.mounted) return;
      }
      try {
        await user.setPower(level);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
      return;
    }
    if (selected == 'kick' || selected == 'ban') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            selected == 'kick'
                ? context.l10n.kickUserTitle(user.nickOrDisplayname)
                : context.l10n.banUserTitle(user.nickOrDisplayname),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                selected == 'kick' ? context.l10n.kick : context.l10n.ban,
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }
    try {
      switch (selected) {
        case 'ignore':
          ignored
              ? await room.client.unignoreUser(user.id)
              : await room.client.ignoreUser(user.id);
        case 'kick':
          await user.kick();
        case 'ban':
          await user.ban();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (!widget.framed) return _buildMemberList();
    // Material (not a decorated box) so the tiles' ink and the banner
    // backgrounds render on top of the panel color.
    return Material(
      color: colorScheme.surfaceContainerLow,
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: Column(
          children: [
            RoomBanner(room: room),
            Expanded(child: _buildMemberList()),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberList() {
    return FutureBuilder<List<User>>(
      future: room.requestParticipants(),
      initialData: room.getParticipants(),
      builder: (context, snapshot) {
        final members =
            (snapshot.data ?? [])
                .where((user) => user.membership == Membership.join)
                .toList()
              ..sort(
                (a, b) => a.nickOrDisplayname.toLowerCase().compareTo(
                  b.nickOrDisplayname.toLowerCase(),
                ),
              );
        // Group by cached presence; users the server sent no presence
        // for count as offline.
        final online = <User>[];
        final away = <User>[];
        final offline = <User>[];
        for (final user in members) {
          if (!_matches(user)) continue;
          _ensurePresence(user);
          _ensureStatus(user);
          switch (_presenceByUser[user.id]?.presence ?? PresenceType.offline) {
            case PresenceType.online:
              online.add(user);
            case PresenceType.unavailable:
              away.add(user);
            case PresenceType.offline:
              offline.add(user);
          }
        }
        final items = <Object>[
          if (online.isNotEmpty) ...[
            '${context.l10n.online} — ${online.length}',
            ...online,
          ],
          if (away.isNotEmpty) ...[
            '${context.l10n.away} — ${away.length}',
            ...away,
          ],
          if (offline.isNotEmpty) ...[
            '${context.l10n.offline} — ${offline.length}',
            ...offline,
          ],
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                context.l10n.membersWithCount(members.length),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: TextField(
                controller: _searchController,
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: context.l10n.searchMembersHint,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: context.l10n.clearSearch,
                          iconSize: 18,
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            if (items.isEmpty && _query.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.l10n.noMatchingMembers,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  if (item is String) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        item.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }
                  final user = item as User;
                  final name = user.nickOrDisplayname;
                  // Each member is a rounded card with a small gap, like
                  // Discord's redesigned member list.
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    child: GestureDetector(
                      onSecondaryTapUp: (details) => _showMemberMenu(
                        context,
                        user,
                        details.globalPosition,
                      ),
                      onLongPressStart: (details) => _showMemberMenu(
                        context,
                        user,
                        details.globalPosition,
                      ),
                      // Material so the banner background and the tile's
                      // ink are clipped to the card's rounded corners.
                      child: Material(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                        clipBehavior: Clip.antiAlias,
                        child: UserBannerBackground(
                          client: room.client,
                          userId: user.id,
                          // Builder so the profile popover anchors to this
                          // row, not the whole member list.
                          child: Builder(
                            builder: (context) {
                              final theme = Theme.of(context);
                              // Discord-style: the user's status message
                              // under the name; the room role when there is
                              // none. Resolved the same way as in the chat
                              // title, so the same person can't read
                              // differently in the two places.
                              final subtitle = switch ((
                                resolveUserStatus(
                                  profileStatus: _statusByUser[user.id],
                                  presenceStatusMsg:
                                      _presenceByUser[user.id]?.statusMsg,
                                ),
                                user.powerLevel.role,
                              )) {
                                (final String status, _)
                                    when status.isNotEmpty =>
                                  status,
                                (_, PowerLevelRole.owner) => context.l10n.owner,
                                (_, PowerLevelRole.admin) => context.l10n.admin,
                                (_, PowerLevelRole.moderator) =>
                                  context.l10n.moderator,
                                _ => null,
                              };
                              // Hand-rolled row instead of a ListTile: the
                              // same fixed height for every card, with the
                              // content truly centered whether it has one
                              // or two lines.
                              return InkWell(
                                onTap: () => showUserProfileCard(
                                  context,
                                  client: room.client,
                                  userId: user.id,
                                  displayName: name,
                                  avatarUrl: user.avatarUrl,
                                  room: room,
                                ),
                                child: SizedBox(
                                  height: 48,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        PresenceAvatar(
                                          client: room.client,
                                          userId: user.id,
                                          name: name,
                                          avatarUrl: user.avatarUrl,
                                          radius: 14,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style:
                                                    theme.textTheme.bodyMedium,
                                              ),
                                              if (subtitle != null)
                                                Text(
                                                  subtitle,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: theme
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TimelineList extends StatelessWidget {
  const _TimelineList({
    super.key,
    required this.timeline,
    required this.initialScrollIndex,
    required this.events,
    required this.itemScrollController,
    required this.itemPositionsListener,
    required this.client,
    required this.highlightedEventId,
    required this.unreadMarkerEventId,
    required this.receiptsByEvent,
    required this.onReply,
    required this.onEdit,
    required this.editingEventId,
    required this.editor,
    required this.onOpenThread,
    required this.onSaveAttachment,
    required this.onMarkUnread,
    required this.onJumpToMessage,
  });

  final Timeline timeline;
  final int initialScrollIndex;
  final List<Event> events;
  final ItemScrollController itemScrollController;
  final ItemPositionsListener itemPositionsListener;
  final Client client;
  final String? highlightedEventId;
  final String? unreadMarkerEventId;
  final ValueListenable<Map<String, List<User>>> receiptsByEvent;
  final ValueChanged<Event> onReply;
  final ValueChanged<Event> onEdit;

  /// The message being edited in place, which shows [editor] instead of
  /// its text.
  final String? editingEventId;
  final Widget editor;
  final ValueChanged<Event> onOpenThread;
  final ValueChanged<Event> onSaveAttachment;
  final ValueChanged<Event> onMarkUnread;
  final ValueChanged<String> onJumpToMessage;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(child: Text(context.l10n.noMessagesYet));
    }
    return ScrollablePositionedList.builder(
      itemScrollController: itemScrollController,
      itemPositionsListener: itemPositionsListener,
      reverse: true,
      initialScrollIndex: initialScrollIndex.clamp(0, events.length - 1),
      // Matches the centered placement of in-place jumps (_scrollToIndex).
      initialAlignment: initialScrollIndex == 0 ? 0 : 0.5,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final previous = index + 1 < events.length ? events[index + 1] : null;
        // The list is reversed, so the item after this one is the older
        // message; a day change between the two gets a date divider.
        final newDay =
            previous == null ||
            !_isSameDay(previous.originServerTs, event.originServerTs);
        final Widget item;
        if (event.type == EventTypes.RoomMember) {
          item = _StateEventLabel(event: event, timeline: timeline);
        } else {
          // Discord-style grouping: consecutive messages of the same sender
          // within two minutes form one block (no sender header, no gap);
          // anything else starts a new block.
          final showSender =
              newDay ||
              previous.senderId != event.senderId ||
              previous.type == EventTypes.RoomMember ||
              event.originServerTs.difference(previous.originServerTs) >
                  const Duration(minutes: 2);
          item = _MessageBubble(
            event: event,
            timeline: timeline,
            ownMessage: event.senderId == client.userID,
            showSender: showSender,
            highlighted: event.eventId == highlightedEventId,
            showUnreadMarker: event.eventId == unreadMarkerEventId,
            receipts: receiptsByEvent,
            onReply: onReply,
            onEdit: onEdit,
            editor: event.eventId == editingEventId ? editor : null,
            onOpenThread: onOpenThread,
            onSaveAttachment: onSaveAttachment,
            onMarkUnread: onMarkUnread,
            onJumpToMessage: onJumpToMessage,
          );
        }
        if (!newDay) return item;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _DateDivider(date: event.originServerTs),
            item,
          ],
        );
      },
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// WhatsApp-style centered date chip shown above the first message of a day.
class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final day = DateTime(date.year, date.month, date.day);
    final label = day == today
        ? context.l10n.today
        : day == yesterday
        ? context.l10n.yesterday
        : DateFormat.yMMMd(
            Localizations.localeOf(context).toString(),
          ).format(date);
    final layout = SettingsScope.of(context).messageLayout;
    if (layout == MessageLayout.cozy || layout == MessageLayout.text) {
      // Discord style: a hairline with the date resting in the middle.
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Row(
          children: [
            Expanded(child: Divider(color: colorScheme.outlineVariant)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(child: Divider(color: colorScheme.outlineVariant)),
          ],
        ),
      );
    }
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
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
    required this.highlighted,
    required this.showUnreadMarker,
    required this.receipts,
    required this.onReply,
    required this.onEdit,
    this.editor,
    required this.onOpenThread,
    required this.onSaveAttachment,
    required this.onMarkUnread,
    required this.onJumpToMessage,
  });

  final Event event;
  final Timeline timeline;
  final bool ownMessage;
  final bool showSender;
  final bool highlighted;
  final bool showUnreadMarker;
  final ValueListenable<Map<String, List<User>>> receipts;
  final ValueChanged<Event> onOpenThread;
  final ValueChanged<Event> onReply;
  final ValueChanged<Event> onEdit;

  /// Set while this message is being edited: shown in place of its text.
  final Widget? editor;
  final ValueChanged<Event> onSaveAttachment;
  final ValueChanged<Event> onMarkUnread;
  final ValueChanged<String> onJumpToMessage;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _hovered = false;

  /// The built [HtmlMessage], kept across rebuilds: parsing HTML into
  /// widgets is expensive, and returning the identical widget instance lets
  /// Flutter skip that whole subtree when the source hasn't changed.
  Widget? _htmlContent;
  String? _htmlSource;

  Widget _htmlMessage(String html) {
    if (_htmlSource != html) {
      _htmlSource = html;
      _htmlContent = HtmlMessage(
        html: html,
        client: event.room.client,
        room: event.room,
      );
    }
    return _htmlContent!;
  }

  static const _quickReactions = ['👍', '❤️', '😂', '😮', '😢', '🎉'];
  static const _hoverReactions = ['👍', '❤️', '😂'];

  static const _attachmentTypes = {
    MessageTypes.File,
    MessageTypes.Audio,
    MessageTypes.Video,
  };

  static const _failedUploadTypes = {
    MessageTypes.Image,
    MessageTypes.Sticker,
    MessageTypes.File,
    MessageTypes.Audio,
    MessageTypes.Video,
  };

  Event get event => widget.event;
  Timeline get timeline => widget.timeline;

  /// True when someone else's message mentions the current user — via the
  /// `m.mentions` field, an `@room` mention, or (legacy fallback for clients
  /// that don't send `m.mentions`) the raw user ID in the body.
  bool get _mentionsMe {
    final userId = event.room.client.userID;
    if (userId == null || widget.ownMessage) return false;
    for (final content in [
      event.content,
      if (event.content['m.new_content'] is Map<String, Object?>)
        event.content['m.new_content'] as Map<String, Object?>,
    ]) {
      final mentions = content['m.mentions'];
      if (mentions is Map) {
        final userIds = mentions['user_ids'];
        if (userIds is List && userIds.contains(userId)) return true;
        if (mentions['room'] == true) return true;
        continue;
      }
      final formatted = content['formatted_body'];
      if (formatted is String && formatted.contains(userId)) return true;
      final body = content['body'];
      if (body is String && body.contains(userId)) return true;
    }
    return false;
  }

  bool get ownMessage => widget.ownMessage;
  bool get showSender => widget.showSender;
  ValueChanged<Event> get onReply => widget.onReply;
  ValueChanged<Event> get onEdit => widget.onEdit;
  ValueChanged<Event> get onOpenThread => widget.onOpenThread;
  ValueChanged<Event> get onSaveAttachment => widget.onSaveAttachment;
  ValueChanged<Event> get onMarkUnread => widget.onMarkUnread;

  Client get _client => event.room.client;

  String? _reactionKey(Event reaction) => reaction.content
      .tryGetMap<String, Object?>('m.relates_to')
      ?.tryGet<String>('key');

  /// The message's reactions grouped by reaction key, in arrival order.
  Map<String, List<Event>> _reactionsByKey() {
    final byKey = <String, List<Event>>{};
    for (final reaction in event.aggregatedEvents(
      timeline,
      RelationshipTypes.reaction,
    )) {
      final key = _reactionKey(reaction);
      if (key != null) byKey.putIfAbsent(key, () => []).add(reaction);
    }
    return byKey;
  }

  void _showReactions(BuildContext context, [String? key]) =>
      showReactionsDialog(
        context,
        room: event.room,
        reactions: _reactionsByKey(),
        initialKey: key,
      );

  Future<void> _toggleReaction(BuildContext context, String key) async {
    final reactions = event.aggregatedEvents(
      timeline,
      RelationshipTypes.reaction,
    );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteMessageTitle),
        content: Text(context.l10n.deleteMessageWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await event.redactEvent();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _showMessageMenu(BuildContext context, Offset position) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final displayEvent = event.getDisplayEvent(timeline);
    final sent = event.status.isSent;
    final failed = event.status.isError;
    final hasAttachment = displayEvent.attachmentOrThumbnailMxcUrl() != null;
    final isImage =
        (displayEvent.messageType == MessageTypes.Image ||
            displayEvent.messageType == MessageTypes.Sticker) &&
        displayEvent.attachmentMxcUrl != null;
    final canPin = event.room.canChangeStateEvent(EventTypes.RoomPinnedEvents);
    final isPinned = event.room.pinnedEventIds.contains(event.eventId);
    final hasReactions = _reactionsByKey().isNotEmpty;
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
                      child: Text(emoji, style: const TextStyle(fontSize: 20)),
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
        if (hasReactions)
          PopupMenuItem(
            value: 'reactions',
            child: Text(context.l10n.viewReactions),
          ),
        if (sent)
          PopupMenuItem(value: 'reply', child: Text(context.l10n.reply)),
        if (sent)
          PopupMenuItem(
            value: 'thread',
            child: Text(context.l10n.replyInThread),
          ),
        if (ownMessage && sent && displayEvent.messageType == MessageTypes.Text)
          PopupMenuItem(value: 'edit', child: Text(context.l10n.edit)),
        if (ownMessage && sent && displayEvent.type == pollStartType)
          PopupMenuItem(value: 'endpoll', child: Text(context.l10n.endPoll)),
        PopupMenuItem(value: 'copy', child: Text(context.l10n.copyText)),
        if (sent)
          PopupMenuItem(value: 'unread', child: Text(context.l10n.markUnread)),
        if (sent)
          PopupMenuItem(value: 'forward', child: Text(context.l10n.forward)),
        if (canPin && sent)
          PopupMenuItem(
            value: 'pin',
            child: Text(isPinned ? context.l10n.unpin : context.l10n.pin),
          ),
        if (isImage)
          PopupMenuItem(
            value: 'copyimage',
            child: Text(context.l10n.copyImage),
          ),
        if (hasAttachment)
          PopupMenuItem(value: 'save', child: Text(context.l10n.saveFile)),
        if (ownMessage && sent)
          PopupMenuItem(value: 'delete', child: Text(context.l10n.delete)),
        // A failed send stays in the SDK's sending queue, which is always
        // listed at the newest end of the timeline, until it is resent or
        // discarded.
        if (failed)
          PopupMenuItem(value: 'retry', child: Text(context.l10n.retrySend)),
        if (failed)
          PopupMenuItem(value: 'discard', child: Text(context.l10n.delete)),
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
    } else if (selected == 'reactions') {
      _showReactions(context);
    } else if (selected == 'reply') {
      onReply(event);
    } else if (selected == 'thread') {
      onOpenThread(event);
    } else if (selected == 'edit') {
      onEdit(event);
    } else if (selected == 'endpoll') {
      try {
        await endPoll(event);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    } else if (selected == 'forward') {
      await showForwardDialog(context, displayEvent);
    } else if (selected == 'pin') {
      final ids = List<String>.from(event.room.pinnedEventIds);
      isPinned ? ids.remove(event.eventId) : ids.add(event.eventId);
      try {
        await event.room.setPinnedEvents(ids);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    } else if (selected == 'copy') {
      await Clipboard.setData(
        ClipboardData(
          text: displayEvent.calcLocalizedBodyFallback(
            const MatrixDefaultLocalizations(),
            hideReply: true,
            plaintextBody: true,
          ),
        ),
      );
    } else if (selected == 'unread') {
      onMarkUnread(event);
    } else if (selected == 'copyimage') {
      await copyImageAttachment(context, displayEvent);
    } else if (selected == 'save') {
      onSaveAttachment(displayEvent);
    } else if (selected == 'delete') {
      await _confirmDelete(context);
    } else if (selected == 'retry') {
      await _retrySend(context);
    } else if (selected == 'discard') {
      await event.cancelSend();
    }
  }

  Future<void> _retrySend(BuildContext context) async {
    try {
      await event.sendAgain();
    } on FileNoLongerInCacheException {
      // Attachments are only cached in memory, so after a restart a
      // failed upload cannot be retried.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.fileNoLongerCached)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  /// "Not sent" notice with retry/delete under a failed message. A failed
  /// send stays pinned to the bottom of the timeline until it is resent or
  /// discarded, so both have to be reachable without the context menu.
  Widget _buildFailedRow(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final buttonStyle = TextButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      minimumSize: const Size(0, 28),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return SelectionContainer.disabled(
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Icon(Icons.error_outline, size: 16, color: colorScheme.error),
            Text(
              context.l10n.messageNotSent,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: colorScheme.error),
            ),
            TextButton.icon(
              style: buttonStyle,
              onPressed: () => _retrySend(context),
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(context.l10n.retrySend),
            ),
            TextButton.icon(
              style: buttonStyle.copyWith(
                foregroundColor: WidgetStatePropertyAll(colorScheme.error),
              ),
              onPressed: () => event.cancelSend(),
              icon: const Icon(Icons.delete_outline, size: 16),
              label: Text(context.l10n.delete),
            ),
          ],
        ),
      ),
    );
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
        mouseCursor: SystemMouseCursors.click,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: Icon(icon, size: 16),
        ),
      ),
    );
  }

  /// Discord-style action bar shown next to the bubble while hovering.
  Widget _buildHoverActions() {
    final colorScheme = Theme.of(context).colorScheme;
    final sent = event.status.isSent;
    // Buttons, not message text: kept out of the page's SelectionArea so
    // the emoji labels show the click cursor instead of the text I-beam
    // (see _buildReactions).
    return SelectionContainer.disabled(
      child: Padding(
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
                      message: context.l10n.reactWith(emoji),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        mouseCursor: SystemMouseCursors.click,
                        onTap: () => _toggleReaction(context, emoji),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 3,
                          ),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                  _hoverButton(
                    icon: Icons.add_reaction_outlined,
                    tooltip: context.l10n.addReaction,
                    onTap: () async {
                      final emoji = await showEmojiPicker(context);
                      if (emoji != null && mounted) {
                        await _toggleReaction(context, emoji);
                      }
                    },
                  ),
                  _hoverButton(
                    icon: Icons.reply,
                    tooltip: context.l10n.reply,
                    onTap: () => onReply(event),
                  ),
                ],
                Builder(
                  builder: (buttonContext) => _hoverButton(
                    icon: Icons.more_horiz,
                    tooltip: context.l10n.more,
                    onTap: () {
                      final box = buttonContext.findRenderObject() as RenderBox;
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
      ),
    );
  }

  Widget? _buildReactions(BuildContext context) {
    final byKey = _reactionsByKey();
    if (byKey.isEmpty) return null;
    final colorScheme = Theme.of(context).colorScheme;
    // The chips are buttons, not message text: leaving them inside the
    // page's SelectionArea would make their labels drag-selectable and
    // show the text I-beam instead of the InkWell's click cursor (the
    // selectable text's own cursor sits deeper, so it wins).
    return SelectionContainer.disabled(
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final entry in byKey.entries)
              // Right-click / long-press shows who reacted, opened on this
              // emoji's tab (and keeps the message menu from opening).
              GestureDetector(
                onSecondaryTap: () => _showReactions(context, entry.key),
                onLongPress: () => _showReactions(context, entry.key),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  // InkWell's default (adaptiveClickable) resolves to the
                  // plain arrow everywhere but the web.
                  mouseCursor: SystemMouseCursors.click,
                  onTap: () => _toggleReaction(context, entry.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          entry.value.any((r) => r.senderId == _client.userID)
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            entry.value.any((r) => r.senderId == _client.userID)
                            ? colorScheme.primary
                            : Colors.transparent,
                      ),
                    ),
                    child: _reactionChipContent(entry.key, entry.value),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The inside of one reaction chip: the reaction key and the count. A key
  /// that is an `mxc://` URI is a custom emoji reaction (MSC4027) and shows
  /// the image instead of the raw URI text.
  Widget _reactionChipContent(String key, List<Event> reactions) {
    const style = TextStyle(fontSize: 13);
    final mxc = Uri.tryParse(key);
    if (mxc == null || !mxc.isScheme('mxc')) {
      return Text('$key ${reactions.length}', style: style);
    }
    // MSC4027 names the emote in an optional top-level shortcode field,
    // shown as tooltip and as text fallback when the image fails to load.
    final shortcode = reactions
        .map((reaction) => reaction.content.tryGet<String>('shortcode') ?? '')
        .firstWhere((code) => code.isNotEmpty, orElse: () => '');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InlineEmote(client: _client, uri: mxc, name: shortcode, size: 18),
        const SizedBox(width: 4),
        Text('${reactions.length}', style: style),
      ],
    );
  }

  Widget _buildFileContent(BuildContext context, Event displayEvent) {
    final filename = displayEvent.attachmentName;
    final size = displayEvent.infoMap['size'];
    final sizeText = size is int ? _formatSize(size) : null;
    final icon = switch (displayEvent.messageType) {
      MessageTypes.Audio => Icons.audiotrack_outlined,
      MessageTypes.Video => Icons.videocam_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
    // A compact file card: tapping it saves, and previewable attachments
    // (text, PDF) get an eye button on the same line that opens the
    // full-screen viewer.
    final colorScheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Material(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: InkWell(
                onTap: () => onSaveAttachment(displayEvent),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 28, color: colorScheme.primary),
                      const SizedBox(width: 10),
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
                              sizeText == null
                                  ? context.l10n.clickToSave
                                  : context.l10n.saveWithSize(sizeText),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (FilePreviewButton.isPreviewable(displayEvent))
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: FilePreviewButton(
                  event: displayEvent,
                  onSave: () => onSaveAttachment(displayEvent),
                ),
              ),
          ],
        ),
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

  Widget _buildThreadChip(BuildContext context, int count) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onOpenThread(event),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.forum_outlined, size: 14, color: colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                context.l10n.repliesCount(count),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptsRow(BuildContext context, List<User> receipts) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      // Right-aligned, dimmed and overlapping so it reads as a status
      // marker rather than another message.
      child: Align(
        alignment: Alignment.centerRight,
        child: Tooltip(
          message: context.l10n.readBy(
            receipts.map((user) => user.nickOrDisplayname).join(', '),
          ),
          child: Opacity(
            opacity: 0.65,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.done_all,
                  size: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 3),
                SizedBox(
                  width: 14.0 + (receipts.length.clamp(1, 6) - 1) * 9.0,
                  height: 14,
                  child: Stack(
                    children: [
                      for (final (index, user) in receipts.take(6).indexed)
                        Positioned(
                          left: index * 9.0,
                          child: MxcAvatar(
                            client: _client,
                            name: user.nickOrDisplayname,
                            avatarUrl: user.avatarUrl,
                            radius: 7,
                          ),
                        ),
                    ],
                  ),
                ),
                if (receipts.length > 6)
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Text(
                      '+${receipts.length - 6}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSenderAvatar(double radius) {
    final sender = event.senderFromMemoryOrFallback;
    // Builder so the profile popover anchors to the avatar, not the whole
    // message row.
    return Builder(
      builder: (context) => GestureDetector(
        onTap: () => showUserProfileCard(
          context,
          client: _client,
          userId: event.senderId,
          displayName: sender.nickOrDisplayname,
          avatarUrl: sender.avatarUrl,
          room: event.room,
        ),
        child: MxcAvatar(
          client: _client,
          name: sender.nickOrDisplayname,
          avatarUrl: sender.avatarUrl,
          radius: radius,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final layout = SettingsScope.of(context).messageLayout;
    // Deleted messages are an inert outline pill: no hover actions, no
    // context menu, no reactions — nothing to interact with.
    if (event.redacted) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          mainAxisAlignment:
              widget.ownMessage && layout == MessageLayout.bubbles
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.delete_outline,
                    size: 14,
                    color: colorScheme.outline,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.l10n.messageDeletedFrom(
                      event.senderFromMemoryOrFallback.nickOrDisplayname,
                    ),
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                      color: colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final displayEvent = event.getDisplayEvent(timeline);
    final sending = event.status.isSending;
    final failed = event.status.isError;
    // An attachment whose upload failed has no mxc URL, so it would fall
    // back to "… sent a picture", which reads like a successful send.
    final failedUpload =
        failed &&
        _failedUploadTypes.contains(displayEvent.messageType) &&
        displayEvent.attachmentMxcUrl == null;
    final body = failedUpload
        ? context.l10n.uploadFailed(
            displayEvent.content.tryGet<String>('filename') ??
                displayEvent.rawBody,
          )
        : replaceEmojiShortcodes(
            displayEvent.calcLocalizedBodyFallback(
              const MatrixDefaultLocalizations(),
              hideReply: true,
            ),
          );
    final sender = event.senderFromMemoryOrFallback.nickOrDisplayname;
    final editor = widget.editor;
    // Whether an m.replace aggregation rewrote this message. The label
    // belongs to the text, so it goes while the editor stands in for it.
    final edited =
        editor == null &&
        event.hasAggregatedEvents(timeline, RelationshipTypes.edit);
    final editedLabel = edited
        ? Text(
            context.l10n.edited,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
              fontStyle: FontStyle.italic,
            ),
          )
        : null;

    final isPoll =
        displayEvent.type == pollStartType ||
        displayEvent.content.containsKey('org.matrix.msc3381.poll.start');
    final isLocation = displayEvent.messageType == MessageTypes.Location;
    final isImage =
        (displayEvent.messageType == MessageTypes.Image ||
            displayEvent.messageType == MessageTypes.Sticker) &&
        displayEvent.attachmentOrThumbnailMxcUrl(getThumbnail: true) != null;
    final isAudio =
        displayEvent.messageType == MessageTypes.Audio &&
        displayEvent.attachmentMxcUrl != null;
    final isVideo =
        displayEvent.messageType == MessageTypes.Video &&
        displayEvent.attachmentMxcUrl != null;
    final isFile =
        !isAudio &&
        !isVideo &&
        _attachmentTypes.contains(displayEvent.messageType) &&
        displayEvent.attachmentMxcUrl != null;
    final isHtml =
        !isPoll &&
        !isImage &&
        !isAudio &&
        !isVideo &&
        !isFile &&
        displayEvent.content.tryGet<String>('format') ==
            'org.matrix.custom.html' &&
        displayEvent.formattedText.isNotEmpty;
    // For attachments the body is the filename unless a separate `filename`
    // field is set, in which case the body is a real caption worth showing
    // (MSC2530). It has to come from the event itself: `body` above is the
    // localized fallback, which for an attachment is "… sent a picture".
    final filename = displayEvent.content.tryGet<String>('filename');
    final rawBody = displayEvent.rawBody;
    final hasCaption =
        (isImage || isAudio || isVideo || isFile) &&
        filename != null &&
        filename != rawBody &&
        rawBody.isNotEmpty;
    final caption = hasCaption ? replaceEmojiShortcodes(rawBody) : null;
    // Captions carry markdown like any other message, so render the
    // formatted variant when the sender provided one.
    final captionHtml =
        hasCaption &&
            displayEvent.content.tryGet<String>('format') ==
                'org.matrix.custom.html' &&
            displayEvent.formattedText.isNotEmpty
        ? replaceEmojiShortcodes(displayEvent.formattedText)
        : null;
    final inReplyToId = displayEvent.inReplyToEventId();
    final reactions = _buildReactions(context);
    final threadReplyCount = event
        .aggregatedEvents(timeline, RelationshipTypes.thread)
        .length;
    final linkUrl =
        !isImage &&
            !isFile &&
            !isAudio &&
            !isVideo &&
            !isPoll &&
            SettingsScope.of(context).showUrlPreviews
        ? LinkPreview.firstLinkOf(displayEvent.body)
        : null;
    final timeText = DateFormat.Hm().format(event.originServerTs);
    final threadChip = threadReplyCount > 0
        ? _buildThreadChip(context, threadReplyCount)
        : null;
    // Listens to the page-level receipts notifier so receipt churn only
    // rebuilds this small row instead of every mounted bubble. Zero-sized
    // while there is nothing to show.
    final receiptsRow = ValueListenableBuilder<Map<String, List<User>>>(
      valueListenable: widget.receipts,
      builder: (context, receiptsByEvent, _) {
        if (!SettingsScope.of(context).showReadReceipts) {
          return const SizedBox.shrink();
        }
        final receiptUsers = [
          for (final user in receiptsByEvent[event.eventId] ?? const <User>[])
            if (user.id != event.senderId) user,
        ];
        if (receiptUsers.isEmpty) return const SizedBox.shrink();
        return _buildReceiptsRow(context, receiptUsers);
      },
    );

    // An attachment's caption, laid out under the media it belongs to.
    final captionWidget = caption == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 6),
            child: captionHtml != null
                ? _htmlMessage(captionHtml)
                : LinkifiedText(caption),
          );

    // The message content itself, shared by all layouts. In the text layout
    // plain/formatted text is rendered inline instead.
    Widget mainContent({required bool includeText}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (inReplyToId != null)
          _ReplyQuote(
            timeline: timeline,
            eventId: inReplyToId,
            onTap: () => widget.onJumpToMessage(inReplyToId),
          ),
        if (isPoll)
          PollBubble(event: event, timeline: timeline)
        else if (isLocation)
          LocationBubble(event: displayEvent)
        else if (isImage) ...[
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
          ?captionWidget,
        ] else if (isAudio) ...[
          VoiceMessageBubble(event: displayEvent),
          ?captionWidget,
        ] else if (isVideo) ...[
          EventVideo(event: displayEvent),
          ?captionWidget,
        ] else if (isFile) ...[
          _buildFileContent(context, displayEvent),
          ?captionWidget,
        ] else if (editor != null)
          editor
        else if (includeText)
          if (isHtml)
            _htmlMessage(replaceEmojiShortcodes(displayEvent.formattedText))
          else if (isSingleEmoji(body))
            // Jumbo: a message that is just one emoji renders it large.
            Text(body, style: const TextStyle(fontSize: jumboEmojiSize))
          else
            LinkifiedText(body),
        if (linkUrl != null) LinkPreview(client: _client, url: linkUrl),
        if (failed) _buildFailedRow(context),
      ],
    );

    // While editing, right-click and long-press belong to the text field
    // (cut, copy, paste) rather than the message menu.
    Widget withMenu(Widget child) => editor != null
        ? child
        : GestureDetector(
            behavior: HitTestBehavior.translucent,
            onLongPressStart: (details) =>
                _showMessageMenu(context, details.globalPosition),
            onSecondaryTapUp: (details) =>
                _showMessageMenu(context, details.globalPosition),
            child: child,
          );

    Widget bubblesLayout() {
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
            mainContent(includeText: true),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(timeText, style: Theme.of(context).textTheme.labelSmall),
                if (editedLabel != null) ...[
                  const SizedBox(width: 4),
                  editedLabel,
                ],
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
          // A clear gap between message blocks, none within a block.
          top: showSender ? 12 : 2,
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
                  _buildSenderAvatar(14)
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
                    withMenu(bubble),
                    ?reactions,
                    ?threadChip,
                    receiptsRow,
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget flatLayout({required bool compact}) {
      final header = showSender
          ? Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      sender,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (compact
                                  ? Theme.of(context).textTheme.labelSmall
                                  : Theme.of(context).textTheme.labelMedium)
                              ?.copyWith(
                                color: InitialsAvatar.colorFor(sender),
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 8),
                    Text(
                      timeText,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                  if (failed) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.error_outline,
                      size: 14,
                      color: colorScheme.error,
                    ),
                  ],
                ],
              ),
            )
          : null;

      return Padding(
        // A clear gap above each message block, none within a block.
        padding: EdgeInsets.fromLTRB(
          12,
          showSender && !compact ? 12 : 1,
          12,
          1,
        ),
        child: Opacity(
          opacity: sending ? 0.6 : 1,
          child: withMenu(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (compact)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: SizedBox(
                      width: 38,
                      child: Text(
                        timeText,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  )
                else if (showSender)
                  _buildSenderAvatar(16)
                else
                  const SizedBox(width: 32),
                SizedBox(width: compact ? 6 : 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ?header,
                      mainContent(includeText: true),
                      ?editedLabel,
                      ?reactions,
                      ?threadChip,
                      receiptsRow,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget textLayout() {
      final showInline =
          editor == null &&
          !isImage &&
          !isFile &&
          !isAudio &&
          !isVideo &&
          !isPoll &&
          !isLocation;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
        child: Opacity(
          opacity: sending ? 0.6 : 1,
          child: withMenu(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '[$timeText] ',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                      TextSpan(
                        text: '<$sender> ',
                        style: TextStyle(
                          color: InitialsAvatar.colorFor(sender),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (showInline) TextSpan(text: body),
                      if (showInline && edited)
                        TextSpan(
                          text: ' ${context.l10n.edited}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colorScheme.outline,
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      if (failed)
                        WidgetSpan(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.error_outline,
                              size: 14,
                              color: colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!showInline ||
                    inReplyToId != null ||
                    linkUrl != null ||
                    failed)
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: mainContent(includeText: false),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [?reactions, ?threadChip, receiptsRow],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final inner = switch (layout) {
      MessageLayout.bubbles => bubblesLayout(),
      MessageLayout.cozy => flatLayout(compact: false),
      MessageLayout.text => textLayout(),
    };

    final mentionsMe = _mentionsMe;
    final messageRow = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: Motion.quick,
        decoration: BoxDecoration(
          color: widget.highlighted
              ? colorScheme.tertiaryContainer.withValues(alpha: 0.6)
              : mentionsMe
              ? colorScheme.primary.withValues(alpha: _hovered ? 0.12 : 0.08)
              : _hovered
              ? colorScheme.onSurface.withValues(alpha: 0.05)
              : Colors.transparent,
          border: mentionsMe
              ? Border(left: BorderSide(color: colorScheme.primary, width: 3))
              : null,
        ),
        child: Stack(
          // The hover bar may be taller than a single-line row; let it
          // overflow instead of being cut off.
          clipBehavior: Clip.none,
          children: [
            inner,
            // Floating action bar: painted on top so it never affects the
            // message layout. Kept mounted and toggled via opacity (rather
            // than added on hover), and excluded from semantics entirely:
            // as a hover-only affordance it is unreachable for assistive
            // tech anyway, and its tooltip targets appearing/disappearing
            // on every hover flick crashes Flutter 3.44's semantics
            // pipeline (the '!child.attached' assert loop). Hidden while
            // editing, where it would cover the editor's field.
            Positioned(
              top: 0,
              right: 8,
              child: ExcludeSemantics(
                child: IgnorePointer(
                  ignoring: !_hovered || editor != null,
                  child: Opacity(
                    opacity: _hovered && editor == null ? 1 : 0,
                    child: _buildHoverActions(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!widget.showUnreadMarker) return messageRow;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [const _UnreadMarker(), messageRow],
    );
  }
}

/// [value] with its selection wrapped in [prefix] and [suffix] (markdown
/// emphasis). The wrapped text stays selected; with nothing selected the
/// caret lands between the two markers.
TextEditingValue _wrappedSelection(
  TextEditingValue value,
  String prefix,
  String suffix,
) {
  final text = value.text;
  final selection = value.selection;
  final start = selection.isValid ? selection.start : text.length;
  final end = selection.isValid ? selection.end : text.length;
  final selected = text.substring(start, end);
  return TextEditingValue(
    text: text.replaceRange(start, end, '$prefix$selected$suffix'),
    selection: selected.isEmpty
        ? TextSelection.collapsed(offset: start + prefix.length)
        : TextSelection(
            baseOffset: start + prefix.length,
            extentOffset: start + prefix.length + selected.length,
          ),
  );
}

/// Discord-style editor shown in place of a message's text while it is
/// being edited. Like the composer, Enter saves and Shift+Enter starts a
/// new line; Escape cancels. The hint below doubles as buttons for both,
/// which is how touch screens without those keys get there.
class _InlineMessageEditor extends StatelessWidget {
  const _InlineMessageEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSave,
    required this.onCancel,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      onCancel();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (keyboard.isShiftPressed ||
          keyboard.isAltPressed ||
          keyboard.isControlPressed ||
          keyboard.isMetaPressed) {
        return KeyEventResult.ignored;
      }
      onSave();
      return KeyEventResult.handled;
    }
    if (keyboard.isControlPressed || keyboard.isMetaPressed) {
      final marker = key == LogicalKeyboardKey.keyB
          ? '**'
          : key == LogicalKeyboardKey.keyI
          ? '*'
          : null;
      if (marker != null) {
        controller.value = _wrappedSelection(controller.value, marker, marker);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hintStyle = theme.textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final linkStyle = hintStyle?.copyWith(color: colorScheme.primary);
    Widget link(String label, VoidCallback onTap) => MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(label, style: linkStyle),
      ),
    );
    // Not message text: kept out of the timeline's SelectionArea so drags
    // select inside the field and the links show a click cursor.
    return SelectionContainer.disabled(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: _handleKey,
            child: Actions(
              actions: {
                ExtendSelectionVerticallyToAdjacentLineIntent:
                    _FieldCaretMovementAction(),
              },
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                // The message's own text size, so it doesn't jump on opening.
                style: theme.textTheme.bodyMedium,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                minLines: 1,
                maxLines: 12,
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHigh,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                link(context.l10n.escapeToCancel, onCancel),
                Text('  •  ', style: hintStyle),
                link(context.l10n.enterToSave, onSave),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hands arrow up/down back to the text field they were pressed in.
///
/// A field's line-wise caret move is an overridable action that looks for
/// an override above the field — and inside the timeline it finds the
/// SelectionArea's, which (as of Flutter 3.47) fails a type cast on its way
/// back to the field: the caret stays put and a TypeError is logged.
/// Registered between the field and the SelectionArea, this override wins
/// the lookup and simply runs the field's own move.
class _FieldCaretMovementAction extends Action<DirectionalCaretMovementIntent> {
  @override
  bool get isActionEnabled => callingAction?.isActionEnabled ?? false;

  @override
  bool consumesKey(DirectionalCaretMovementIntent intent) =>
      callingAction?.consumesKey(intent) ?? false;

  @override
  Object? invoke(DirectionalCaretMovementIntent intent) =>
      callingAction?.invoke(intent);
}

/// Overrides the composer's paste shortcut (Ctrl/Cmd+V) so the clipboard
/// can be checked for files and images before the field's own text paste.
class _ComposerPasteAction extends Action<PasteTextIntent> {
  _ComposerPasteAction(this.onPaste);

  /// Handles the paste; calls the passed callback to run the field's own
  /// text paste.
  final Future<void> Function(VoidCallback pasteText) onPaste;

  @override
  Object? invoke(PasteTextIntent intent) {
    // The field's own paste action. Only set while this call runs, so it is
    // captured before [onPaste] goes async.
    final textPaste = callingAction;
    onPaste(() => textPaste?.invoke(intent));
    return null;
  }
}

/// A file or GIF send in flight.
class _PendingSend {
  _PendingSend({required this.name, required this.isImage});

  final String name;
  final bool isImage;
}

/// Pulsing skeleton bubble shown while a file/GIF is downloaded, uploaded
/// and sent.
class _PendingSendBubble extends StatefulWidget {
  const _PendingSendBubble({required this.pending});

  final _PendingSend pending;

  @override
  State<_PendingSendBubble> createState() => _PendingSendBubbleState();
}

class _PendingSendBubbleState extends State<_PendingSendBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = Text(
      '${widget.pending.name} · ${context.l10n.sending}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
    );
    return FadeTransition(
      opacity: Tween(
        begin: 0.45,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: widget.pending.isImage
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 180,
                    height: 100,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  label,
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: label),
                ],
              ),
      ),
    );
  }
}

/// Divider between the last read and the first unread message.
class _UnreadMarker extends StatelessWidget {
  const _UnreadMarker();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(child: Divider(color: color)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              context.l10n.newMessages,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Divider(color: color)),
        ],
      ),
    );
  }
}

/// A small quoted box shown inside a bubble for messages that reply to
/// another event.
class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote({
    required this.timeline,
    required this.eventId,
    required this.onTap,
  });

  final Timeline timeline;
  final String eventId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FutureBuilder<Event?>(
      future: timeline.getEventById(eventId),
      builder: (context, snapshot) {
        final replied = snapshot.data;
        final sender =
            replied?.senderFromMemoryOrFallback.nickOrDisplayname ?? '';
        final snippet = replied == null
            ? context.l10n.loading
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
          clipBehavior: Clip.antiAlias,
          child: _ReplyTapTarget(
            onTap: onTap,
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
                              style: Theme.of(context).textTheme.labelSmall
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
          ),
        );
      },
    );
  }
}

/// Makes a reply preview clickable: tapping it jumps to the replied-to
/// message.
class _ReplyTapTarget extends StatelessWidget {
  const _ReplyTapTarget({
    required this.onTap,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final VoidCallback onTap;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    // Kept out of the page's SelectionArea so the preview shows the click
    // cursor instead of the text I-beam.
    return SelectionContainer.disabled(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Right-side panel showing a thread: the root message, its replies and a
/// composer that sends into the thread.
class _ThreadPanel extends StatefulWidget {
  const _ThreadPanel({
    required this.room,
    required this.timeline,
    required this.root,
    required this.onClose,
  });

  final Room room;
  final Timeline timeline;
  final Event root;
  final VoidCallback onClose;

  @override
  State<_ThreadPanel> createState() => _ThreadPanelState();
}

class _ThreadPanelState extends State<_ThreadPanel> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Event> get _replies =>
      widget.root
          .aggregatedEvents(widget.timeline, RelationshipTypes.thread)
          .toList()
        ..sort((a, b) => a.originServerTs.compareTo(b.originServerTs));

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    try {
      final replies = _replies;
      await widget.room.sendTextEvent(
        replaceEmojiShortcodes(text),
        threadRootEventId: widget.root.eventId,
        threadLastEventId: replies.isEmpty ? null : replies.last.eventId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final replies = _replies;
    return Container(
      width: 320,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: colorScheme.outlineVariant)),
        color: colorScheme.surfaceContainerLow,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
            child: Row(
              children: [
                Text(
                  context.l10n.thread,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                IconButton(
                  tooltip: context.l10n.closeThread,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SelectionArea(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _ThreadMessage(event: widget.root, timeline: widget.timeline),
                  const Divider(),
                  if (replies.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(context.l10n.noRepliesYet),
                    )
                  else
                    for (final reply in replies)
                      _ThreadMessage(event: reply, timeline: widget.timeline),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: Focus(
                      onKeyEvent: (node, event) {
                        // Enter sends, Shift+Enter inserts a line break.
                        if (event is KeyDownEvent &&
                            (event.logicalKey == LogicalKeyboardKey.enter ||
                                event.logicalKey ==
                                    LogicalKeyboardKey.numpadEnter) &&
                            !HardwareKeyboard.instance.isShiftPressed &&
                            !HardwareKeyboard.instance.isAltPressed &&
                            !HardwareKeyboard.instance.isControlPressed &&
                            !HardwareKeyboard.instance.isMetaPressed) {
                          _send();
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: context.l10n.replyInThread,
                          filled: true,
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        minLines: 1,
                        maxLines: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    iconSize: 18,
                    onPressed: _send,
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

/// Compact message rendering used inside the thread panel.
class _ThreadMessage extends StatelessWidget {
  const _ThreadMessage({required this.event, required this.timeline});

  final Event event;
  final Timeline timeline;

  @override
  Widget build(BuildContext context) {
    final displayEvent = event.getDisplayEvent(timeline);
    final sender = event.senderFromMemoryOrFallback;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MxcAvatar(
            client: event.room.client,
            name: sender.nickOrDisplayname,
            avatarUrl: sender.avatarUrl,
            radius: 12,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        sender.nickOrDisplayname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat.Hm().format(event.originServerTs),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
                Text(
                  displayEvent.calcLocalizedBodyFallback(
                    const MatrixDefaultLocalizations(),
                    hideReply: true,
                    plaintextBody: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
