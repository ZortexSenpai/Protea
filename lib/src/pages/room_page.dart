import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:matrix/matrix.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../commands.dart';
import '../l10n.dart';
import '../settings.dart';
import '../widgets/emoji_picker.dart';
import '../widgets/event_image.dart';
import '../widgets/forward_message_dialog.dart';
import '../widgets/gif_picker_dialog.dart';
import '../widgets/html_message.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/link_preview.dart';
import '../widgets/message_search_dialog.dart';
import '../widgets/mxc_avatar.dart';
import '../widgets/pinned_messages_dialog.dart';
import '../widgets/poll.dart';
import '../widgets/presence_indicator.dart';
import '../widgets/sticker_picker.dart';
import '../widgets/user_banner.dart';
import '../widgets/room_settings_dialog.dart';
import '../widgets/user_profile_card.dart';
import '../widgets/voice_message.dart';

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
  final _itemScrollController = ItemScrollController();
  final _itemPositionsListener = ItemPositionsListener.create();
  Event? _replyTo;
  Event? _editing;
  Event? _threadRoot;
  List<User> _mentionSuggestions = [];
  List<SlashCommand> _commandSuggestions = [];

  /// File/GIF sends in flight, shown as skeleton bubbles above the composer.
  final List<_PendingSend> _pendingSends = [];
  bool _showMembers = false;
  DateTime? _typingLastSent;
  String? _highlightedEventId;
  Timer? _highlightTimer;

  /// First unread event when the room was opened; a "New messages" divider
  /// is shown above it.
  String? _unreadMarkerEventId;
  String? _lastMarkedReadEventId;
  StreamSubscription<SyncUpdate>? _syncSubscription;
  bool _dragging = false;

  AudioRecorder? _recorder;
  final List<double> _recordingAmplitudes = [];
  Timer? _recordingTimer;
  DateTime? _recordingStart;
  bool _recording = false;

  String get _draftKey => 'draft_${widget.room.id}';

  static const _bubbleTypes = {
    EventTypes.Message,
    EventTypes.Sticker,
    EventTypes.Encrypted,
    pollStartType,
  };

  Client get _client => widget.room.client;

  @override
  void initState() {
    super.initState();
    _itemPositionsListener.itemPositions.addListener(_onPositionsChanged);
    // Receipts and typing arrive as ephemeral sync data that does not
    // trigger timeline updates, so rebuild on every sync as well.
    _syncSubscription = _client.onSync.stream.listen((_) {
      if (mounted) setState(() {});
      _maybeMarkRead();
    });
    _loadTimeline();
    _loadDraft();
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
    _recordingTimer?.cancel();
    _recorder?.dispose();
    _syncSubscription?.cancel();
    _highlightTimer?.cancel();
    _itemPositionsListener.itemPositions.removeListener(_onPositionsChanged);
    _timeline?.cancelSubscriptions();
    _sendController.dispose();
    super.dispose();
  }

  /// Sends a read receipt for the newest event while the room is open on
  /// the live timeline.
  void _maybeMarkRead() {
    final timeline = _timeline;
    if (timeline == null || timeline.canRequestFuture) return;
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
    if (!SettingsScope.of(context).sendReadReceipts) return;
    timeline.setReadMarker().catchError((_) {});
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
    // Determine where the "New messages" divider belongs before the read
    // marker below moves the fully-read position.
    final fullyRead = widget.room.fullyRead;
    if (fullyRead.isNotEmpty) {
      final events = _visibleEvents(timeline);
      final index = events.indexWhere((event) => event.eventId == fullyRead);
      if (index > 0) {
        _unreadMarkerEventId = events[index - 1].eventId;
      }
    }
    setState(() => _timeline = timeline);
    if (!mounted || !SettingsScope.of(context).sendReadReceipts) return;
    try {
      await timeline.setReadMarker();
    } catch (_) {}
  }

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
      timeline.requestFuture();
    }
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
          if (mounted) setState(() {});
        },
        eventContextId: eventId,
      );
      if (!mounted) {
        contextTimeline.cancelSubscriptions();
        return;
      }
      setState(() => _timeline = contextTimeline);
      _highlight(eventId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final index = _visibleEvents(
          contextTimeline,
        ).indexWhere((event) => event.eventId == eventId);
        if (index != -1) _scrollToIndex(index);
      });
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
    _sendController.clear();
    final replyTo = _replyTo;
    final editing = _editing;
    setState(() {
      _replyTo = null;
      _editing = null;
    });
    _typingLastSent = null;
    _saveDraft('');
    widget.room.setTyping(false).catchError((_) {});
    final wasInHistory = _timeline?.canRequestFuture ?? false;
    try {
      await widget.room.sendTextEvent(
        text,
        inReplyTo: replyTo,
        editEventId: editing?.eventId,
      );
      // When sending from a jumped-to history position, return to the live
      // timeline so the new message is visible.
      if (wasInHistory && mounted) await _returnToLive();
    } catch (e) {
      _showError(e);
    }
  }

  void _startEdit(Event event) {
    final displayEvent = _timeline == null
        ? event
        : event.getDisplayEvent(_timeline!);
    setState(() {
      _editing = event;
      _replyTo = null;
    });
    _sendController.text = displayEvent.body;
    _sendController.selection = TextSelection.collapsed(
      offset: _sendController.text.length,
    );
  }

  void _cancelEdit() {
    setState(() => _editing = null);
    _sendController.clear();
  }

  void _onInputChanged(String text) {
    _saveDraft(text);
    _updateMentionSuggestions();
    _updateCommandSuggestions();
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

  Future<void> _pickEmoji() async {
    final emoji = await showEmojiPicker(context);
    if (emoji != null) _insertEmoji(emoji);
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
  };

  bool _looksLikeImage(String name, String? mimeType) =>
      (mimeType?.startsWith('image/') ?? false) ||
      _imageExtensions.contains(name.split('.').last.toLowerCase());

  /// Shows a preview of the picked [files] and sends them on confirmation.
  Future<void> _stageAndSend(
    List<({Uint8List bytes, String name, String? mimeType})> files,
  ) async {
    if (files.isEmpty) return;
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
                for (final file in files) ...[
                  if (_looksLikeImage(file.name, file.mimeType))
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
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
                    padding: const EdgeInsets.only(top: 4, bottom: 12),
                    child: Text(
                      '${file.name} · '
                      '${_MessageBubbleState._formatSize(file.bytes.length)}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall,
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
    for (final file in files) {
      await _sendBytes(file.bytes, file.name, mimeType: file.mimeType);
    }
  }

  Future<void> _startRecording() async {
    final recorder = AudioRecorder();
    try {
      if (!await recorder.hasPermission()) {
        if (mounted) _showError(context.l10n.microphonePermissionDenied);
        await recorder.dispose();
        return;
      }
      final dir = await getTemporaryDirectory();
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

  Future<void> _pickGif() async {
    final gif = await showGifPicker(context, _client);
    if (gif == null) return;
    final title = gif.title.trim();
    final name = '${title.isEmpty ? 'gif' : title}.gif';
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
          mimeType: mimeType,
          width: width,
          height: height,
        );
      } else {
        file = MatrixFile(bytes: bytes, name: name, mimeType: mimeType);
      }
      await widget.room.sendFileEvent(file);
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

  /// Sends an image from the clipboard, if there is one. Called alongside
  /// the text field's own paste handling, which covers plain text.
  Future<void> _tryPasteImage() async {
    try {
      final bytes = await Pasteboard.image;
      if (bytes == null || bytes.isEmpty) return;
      await _stageAndSend([
        (bytes: bytes, name: 'pasted-image.png', mimeType: 'image/png'),
      ]);
    } catch (_) {}
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.savedFile(file.name))),
        );
      }
    } catch (e) {
      _showError(e);
    }
  }

  List<Event> _visibleEvents(Timeline timeline) =>
      timeline.events.where((event) {
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
        final settings = SettingsScope.of(context);
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

  void _openThread(Event event) {
    setState(() => _threadRoot = event);
  }

  /// Suggests members while an `@word` fragment is being typed before the
  /// cursor.
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
              (user.calcDisplayname().toLowerCase().startsWith(query) ||
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
          1 => context.l10n.isTyping(names[0]),
          2 => context.l10n.areTyping(names[0], names[1]),
          _ => context.l10n.manyTyping(names.length),
        };
        return SizedBox(
          height: 18,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                text,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditBar() {
    final editing = _editing;
    if (editing == null) return const SizedBox.shrink();
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
          Icon(Icons.edit_outlined, size: 20, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(context.l10n.editingMessage)),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: _cancelEdit,
          ),
        ],
      ),
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
                tooltip: context.l10n.channels,
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
            icon: Icon(_showMembers ? Icons.people : Icons.people_outline),
            onPressed: () => setState(() => _showMembers = !_showMembers),
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
                            timeline == null
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : _TimelineList(
                                    timeline: timeline,
                                    events: _visibleEvents(timeline),
                                    itemScrollController: _itemScrollController,
                                    itemPositionsListener:
                                        _itemPositionsListener,
                                    client: _client,
                                    highlightedEventId: _highlightedEventId,
                                    unreadMarkerEventId: _unreadMarkerEventId,
                                    receiptsByEvent: _receiptsByEvent(),
                                    onReply: (event) => setState(() {
                                      _replyTo = event;
                                      _editing = null;
                                    }),
                                    onEdit: _startEdit,
                                    onOpenThread: _openThread,
                                    onSaveAttachment: _saveAttachment,
                                  ),
                            if (timeline?.canRequestFuture ?? false)
                              Positioned(
                                right: 16,
                                bottom: 12,
                                child: FloatingActionButton.small(
                                  tooltip: context.l10n.jumpToLatestMessages,
                                  onPressed: _returnToLive,
                                  child: const Icon(
                                    Icons.keyboard_double_arrow_down,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      _buildPendingSends(),
                      _buildTypingIndicator(),
                      _buildEditBar(),
                      _buildReplyBar(),
                      if (_commandSuggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          constraints: const BoxConstraints(maxHeight: 240),
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              for (final command in _commandSuggestions)
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
                                  onTap: () => _applyCommandSuggestion(command),
                                ),
                            ],
                          ),
                        ),
                      if (_mentionSuggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          constraints: const BoxConstraints(maxHeight: 240),
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              for (final user in _mentionSuggestions)
                                ListTile(
                                  dense: true,
                                  leading: MxcAvatar(
                                    client: _client,
                                    name: user.calcDisplayname(),
                                    avatarUrl: user.avatarUrl,
                                    radius: 12,
                                  ),
                                  title: Text(
                                    user.calcDisplayname(),
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
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                          child: _recording
                              ? _buildRecordingBar()
                              : Row(
                                  children: [
                                    IconButton(
                                      tooltip: context.l10n.attachFile,
                                      onPressed: encryptedWithoutSupport
                                          ? null
                                          : _attachFile,
                                      icon: const Icon(Icons.attach_file),
                                    ),
                                    IconButton(
                                      tooltip: context.l10n.gif,
                                      onPressed: encryptedWithoutSupport
                                          ? null
                                          : _pickGif,
                                      icon: const Icon(Icons.gif_box_outlined),
                                    ),
                                    IconButton(
                                      tooltip: context.l10n.voiceMessage,
                                      onPressed: encryptedWithoutSupport
                                          ? null
                                          : _startRecording,
                                      icon: const Icon(Icons.mic_none),
                                    ),
                                    PopupMenuButton<String>(
                                      tooltip: context.l10n.moreAttachments,
                                      enabled: !encryptedWithoutSupport,
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                      onSelected: (value) {
                                        switch (value) {
                                          case 'poll':
                                            showCreatePollDialog(
                                              context,
                                              widget.room,
                                            );
                                          case 'sticker':
                                            showStickerPicker(
                                              context,
                                              widget.room,
                                            );
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 'poll',
                                          child: Text(context.l10n.poll),
                                        ),
                                        PopupMenuItem(
                                          value: 'sticker',
                                          child: Text(context.l10n.sticker),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      tooltip: context.l10n.emoji,
                                      onPressed: encryptedWithoutSupport
                                          ? null
                                          : _pickEmoji,
                                      icon: const Icon(
                                        Icons.emoji_emotions_outlined,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Focus(
                                        onKeyEvent: (node, event) {
                                          if (event is! KeyDownEvent) {
                                            return KeyEventResult.ignored;
                                          }
                                          // Enter sends, Shift+Enter (or any other
                                          // modifier) inserts a line break.
                                          if (event.logicalKey ==
                                                  LogicalKeyboardKey.enter ||
                                              event.logicalKey ==
                                                  LogicalKeyboardKey
                                                      .numpadEnter) {
                                            final keyboard =
                                                HardwareKeyboard.instance;
                                            if (!keyboard.isShiftPressed &&
                                                !keyboard.isAltPressed &&
                                                !keyboard.isControlPressed &&
                                                !keyboard.isMetaPressed) {
                                              _send();
                                              return KeyEventResult.handled;
                                            }
                                            return KeyEventResult.ignored;
                                          }
                                          // Sends a pasted image alongside the field's
                                          // own (text) paste handling.
                                          if (event.logicalKey ==
                                                  LogicalKeyboardKey.keyV &&
                                              (HardwareKeyboard
                                                      .instance
                                                      .isMetaPressed ||
                                                  HardwareKeyboard
                                                      .instance
                                                      .isControlPressed)) {
                                            _tryPasteImage();
                                          }
                                          return KeyEventResult.ignored;
                                        },
                                        child: TextField(
                                          controller: _sendController,
                                          enabled: !encryptedWithoutSupport,
                                          decoration: InputDecoration(
                                            hintText: context.l10n.message,
                                            filled: true,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                              borderSide: BorderSide.none,
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 10,
                                                ),
                                          ),
                                          keyboardType: TextInputType.multiline,
                                          textInputAction:
                                              TextInputAction.newline,
                                          onChanged: _onInputChanged,
                                          minLines: 1,
                                          maxLines: 8,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton.filled(
                                      onPressed: encryptedWithoutSupport
                                          ? null
                                          : _send,
                                      icon: const Icon(Icons.send),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_threadRoot != null && timeline != null)
                  _ThreadPanel(
                    room: widget.room,
                    timeline: timeline,
                    root: _threadRoot!,
                    onClose: () => setState(() => _threadRoot = null),
                  ),
                if (_showMembers) _MemberListPanel(room: widget.room),
              ],
            ),
            if (_dragging)
              Positioned.fill(
                child: IgnorePointer(
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
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
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
  }
}

/// Right-side panel listing the members of the room.
class _MemberListPanel extends StatelessWidget {
  const _MemberListPanel({required this.room});

  final Room room;

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
    if (selected.startsWith('power:')) {
      final level = int.parse(selected.substring('power:'.length));
      if (level >= PowerLevel.defaultAdminLevel) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              context.l10n.makeUserAdminTitle(user.calcDisplayname()),
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
                ? context.l10n.kickUserTitle(user.calcDisplayname())
                : context.l10n.banUserTitle(user.calcDisplayname()),
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
    // Material (not a decorated box) so the tiles' ink and the banner
    // backgrounds render on top of the panel color.
    return Material(
      color: colorScheme.surfaceContainerLow,
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: FutureBuilder<List<User>>(
          future: room.requestParticipants(),
          initialData: room.getParticipants(),
          builder: (context, snapshot) {
            final members =
                (snapshot.data ?? [])
                    .where((user) => user.membership == Membership.join)
                    .toList()
                  ..sort(
                    (a, b) => a.calcDisplayname().toLowerCase().compareTo(
                      b.calcDisplayname().toLowerCase(),
                    ),
                  );
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
                Expanded(
                  child: ListView.builder(
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final user = members[index];
                      final name = user.calcDisplayname();
                      return GestureDetector(
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
                        child: UserBannerBackground(
                          client: room.client,
                          userId: user.id,
                          child: ListTile(
                            dense: true,
                            leading: PresenceAvatar(
                              client: room.client,
                              userId: user.id,
                              name: name,
                              avatarUrl: user.avatarUrl,
                              radius: 14,
                            ),
                            title: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: switch (user.powerLevel.role) {
                              PowerLevelRole.owner => Text(context.l10n.owner),
                              PowerLevelRole.admin => Text(context.l10n.admin),
                              PowerLevelRole.moderator => Text(
                                context.l10n.moderator,
                              ),
                              PowerLevelRole.user => null,
                            },
                            onTap: () => showUserProfileCard(
                              context,
                              client: room.client,
                              userId: user.id,
                              displayName: name,
                              avatarUrl: user.avatarUrl,
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
        ),
      ),
    );
  }
}

class _TimelineList extends StatelessWidget {
  const _TimelineList({
    required this.timeline,
    required this.events,
    required this.itemScrollController,
    required this.itemPositionsListener,
    required this.client,
    required this.highlightedEventId,
    required this.unreadMarkerEventId,
    required this.receiptsByEvent,
    required this.onReply,
    required this.onEdit,
    required this.onOpenThread,
    required this.onSaveAttachment,
  });

  final Timeline timeline;
  final List<Event> events;
  final ItemScrollController itemScrollController;
  final ItemPositionsListener itemPositionsListener;
  final Client client;
  final String? highlightedEventId;
  final String? unreadMarkerEventId;
  final Map<String, List<User>> receiptsByEvent;
  final ValueChanged<Event> onReply;
  final ValueChanged<Event> onEdit;
  final ValueChanged<Event> onOpenThread;
  final ValueChanged<Event> onSaveAttachment;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(child: Text(context.l10n.noMessagesYet));
    }
    return ScrollablePositionedList.builder(
      itemScrollController: itemScrollController,
      itemPositionsListener: itemPositionsListener,
      reverse: true,
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
          final showSender =
              newDay ||
              previous.senderId != event.senderId ||
              previous.type == EventTypes.RoomMember;
          item = _MessageBubble(
            event: event,
            timeline: timeline,
            ownMessage: event.senderId == client.userID,
            showSender: showSender,
            highlighted: event.eventId == highlightedEventId,
            showUnreadMarker: event.eventId == unreadMarkerEventId,
            receipts: receiptsByEvent[event.eventId] ?? const [],
            onReply: onReply,
            onEdit: onEdit,
            onOpenThread: onOpenThread,
            onSaveAttachment: onSaveAttachment,
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
    required this.onOpenThread,
    required this.onSaveAttachment,
  });

  final Event event;
  final Timeline timeline;
  final bool ownMessage;
  final bool showSender;
  final bool highlighted;
  final bool showUnreadMarker;
  final List<User> receipts;
  final ValueChanged<Event> onOpenThread;
  final ValueChanged<Event> onReply;
  final ValueChanged<Event> onEdit;
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

  Client get _client => event.room.client;

  String? _reactionKey(Event reaction) => reaction.content
      .tryGetMap<String, Object?>('m.relates_to')
      ?.tryGet<String>('key');

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
    final hasAttachment = displayEvent.attachmentOrThumbnailMxcUrl() != null;
    final canPin = event.room.canChangeStateEvent(EventTypes.RoomPinnedEvents);
    final isPinned = event.room.pinnedEventIds.contains(event.eventId);
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
          PopupMenuItem(value: 'forward', child: Text(context.l10n.forward)),
        if (canPin && sent)
          PopupMenuItem(
            value: 'pin',
            child: Text(isPinned ? context.l10n.unpin : context.l10n.pin),
          ),
        if (hasAttachment)
          PopupMenuItem(value: 'save', child: Text(context.l10n.saveFile)),
        if (ownMessage && sent)
          PopupMenuItem(value: 'delete', child: Text(context.l10n.delete)),
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
                    message: context.l10n.reactWith(emoji),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _toggleReaction(context, emoji),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 4,
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 15),
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
    );
  }

  Widget? _buildReactions(BuildContext context) {
    final reactions = event.aggregatedEvents(
      timeline,
      RelationshipTypes.reaction,
    );
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: entry.value.any((r) => r.senderId == _client.userID)
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: entry.value.any((r) => r.senderId == _client.userID)
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
                Text(filename, maxLines: 1, overflow: TextOverflow.ellipsis),
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

  Widget _buildReceiptsRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Tooltip(
        message: context.l10n.readBy(
          widget.receipts.map((user) => user.calcDisplayname()).join(', '),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final user in widget.receipts.take(6))
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: MxcAvatar(
                  client: _client,
                  name: user.calcDisplayname(),
                  avatarUrl: user.avatarUrl,
                  radius: 7,
                ),
              ),
            if (widget.receipts.length > 6)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  '+${widget.receipts.length - 6}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSenderAvatar(double radius) {
    final sender = event.senderFromMemoryOrFallback;
    return GestureDetector(
      onTap: () => showUserProfileCard(
        context,
        client: _client,
        userId: event.senderId,
        displayName: sender.calcDisplayname(),
        avatarUrl: sender.avatarUrl,
      ),
      child: MxcAvatar(
        client: _client,
        name: sender.calcDisplayname(),
        avatarUrl: sender.avatarUrl,
        radius: radius,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final layout = SettingsScope.of(context).messageLayout;
    final displayEvent = event.getDisplayEvent(timeline);
    final body = displayEvent.calcLocalizedBodyFallback(
      const MatrixDefaultLocalizations(),
      hideReply: true,
    );
    final sender = event.senderFromMemoryOrFallback.calcDisplayname();
    final sending = event.status.isSending;
    final failed = event.status.isError;

    final isPoll =
        displayEvent.type == pollStartType ||
        displayEvent.content.containsKey('org.matrix.msc3381.poll.start');
    final isImage =
        (displayEvent.messageType == MessageTypes.Image ||
            displayEvent.messageType == MessageTypes.Sticker) &&
        displayEvent.attachmentOrThumbnailMxcUrl(getThumbnail: true) != null;
    final isAudio =
        displayEvent.messageType == MessageTypes.Audio &&
        displayEvent.attachmentMxcUrl != null;
    final isFile =
        !isAudio &&
        _attachmentTypes.contains(displayEvent.messageType) &&
        displayEvent.attachmentMxcUrl != null;
    final isHtml =
        !isPoll &&
        !isImage &&
        !isAudio &&
        !isFile &&
        displayEvent.content.tryGet<String>('format') ==
            'org.matrix.custom.html' &&
        displayEvent.formattedText.isNotEmpty;
    // For attachments the body is the filename unless a separate `filename`
    // field is set, in which case the body is a real caption worth showing.
    final filename = displayEvent.content.tryGet<String>('filename');
    final caption = isImage && filename != null && filename != displayEvent.body
        ? body
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
            !isPoll &&
            SettingsScope.of(context).showUrlPreviews
        ? LinkPreview.firstLinkOf(displayEvent.body)
        : null;
    final timeText = DateFormat.Hm().format(event.originServerTs);
    final threadChip = threadReplyCount > 0
        ? _buildThreadChip(context, threadReplyCount)
        : null;
    final receiptsRow = widget.receipts.isNotEmpty
        ? _buildReceiptsRow(context)
        : null;

    // The message content itself, shared by all layouts. In the text layout
    // plain/formatted text is rendered inline instead.
    Widget mainContent({required bool includeText}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (inReplyToId != null)
          _ReplyQuote(timeline: timeline, eventId: inReplyToId),
        if (isPoll)
          PollBubble(event: event, timeline: timeline)
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
          if (caption != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(caption),
            ),
        ] else if (isAudio)
          VoiceMessageBubble(event: displayEvent)
        else if (isFile)
          _buildFileContent(context, displayEvent)
        else if (includeText)
          if (isHtml)
            HtmlMessage(
              html: displayEvent.formattedText,
              client: event.room.client,
            )
          else
            Text(body),
        if (linkUrl != null) LinkPreview(client: _client, url: linkUrl),
      ],
    );

    GestureDetector withMenu(Widget child) => GestureDetector(
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
                    ?receiptsRow,
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
        padding: EdgeInsets.fromLTRB(12, showSender && !compact ? 8 : 1, 12, 1),
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
                      ?reactions,
                      ?threadChip,
                      ?receiptsRow,
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
      final showInline = !isImage && !isFile && !isAudio && !isPoll;
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
                if (!showInline || inReplyToId != null || linkUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: mainContent(includeText: false),
                  ),
                if (reactions != null ||
                    threadChip != null ||
                    receiptsRow != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [?reactions, ?threadChip, ?receiptsRow],
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
      MessageLayout.compact => flatLayout(compact: true),
      MessageLayout.text => textLayout(),
    };

    final mentionsMe = _mentionsMe;
    final messageRow = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: DecoratedBox(
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
          children: [
            inner,
            // Floating action bar: painted on top so it never affects the
            // message layout.
            if (_hovered)
              Positioned(top: 0, right: 8, child: _buildHoverActions()),
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
        );
      },
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
        text,
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
            name: sender.calcDisplayname(),
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
                        sender.calcDisplayname(),
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
