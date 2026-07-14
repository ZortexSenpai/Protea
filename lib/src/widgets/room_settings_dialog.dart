import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matrix/matrix.dart';

import 'mxc_avatar.dart';

/// Settings for a room or space: image, name, topic, notifications,
/// invitations and leaving.
Future<void> showRoomSettingsDialog(BuildContext context, Room room) =>
    showDialog(
      context: context,
      builder: (_) => RoomSettingsDialog(room: room),
    );

/// Searches the user directory (or takes a raw user ID) and invites the
/// picked user to [room].
Future<void> showInviteDialog(BuildContext context, Room room) => showDialog(
  context: context,
  builder: (_) => InviteDialog(room: room),
);

class InviteDialog extends StatefulWidget {
  const InviteDialog({super.key, required this.room});

  final Room room;

  @override
  State<InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<InviteDialog> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Profile> _results = [];
  bool _searching = false;
  bool _busy = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _search);
    setState(() {});
  }

  Future<void> _search() async {
    final term = _controller.text.trim();
    if (term.length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final response = await widget.room.client.searchUserDirectory(
        term,
        limit: 10,
      );
      if (mounted) setState(() => _results = response.results);
    } catch (_) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _invite(String userId) async {
    setState(() => _busy = true);
    try {
      await widget.room.invite(userId);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Invited $userId')));
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
    final input = _controller.text.trim();
    final looksLikeUserId = RegExp(r'^@[^:]+:.+$').hasMatch(input);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Text(
                    widget.room.isSpace ? 'Invite to space' : 'Invite to room',
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                enabled: !_busy,
                decoration: InputDecoration(
                  hintText: 'Search by name, or enter @user:server',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                onChanged: _onChanged,
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (looksLikeUserId)
                    ListTile(
                      leading: const Icon(Icons.person_add_outlined),
                      title: Text('Invite $input'),
                      enabled: !_busy,
                      onTap: () => _invite(input),
                    ),
                  for (final profile in _results)
                    ListTile(
                      dense: true,
                      enabled: !_busy,
                      leading: MxcAvatar(
                        client: widget.room.client,
                        name: profile.displayName ?? profile.userId,
                        avatarUrl: profile.avatarUrl,
                        radius: 14,
                      ),
                      title: Text(
                        profile.displayName ?? profile.userId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        profile.userId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _invite(profile.userId),
                    ),
                  if (!looksLikeUserId && _results.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Type at least two characters to search the user '
                        'directory.',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoomSettingsDialog extends StatefulWidget {
  const RoomSettingsDialog({super.key, required this.room});

  final Room room;

  @override
  State<RoomSettingsDialog> createState() => _RoomSettingsDialogState();
}

class _RoomSettingsDialogState extends State<RoomSettingsDialog> {
  bool _busy = false;

  Room get room => widget.room;

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _promptText({
    required String title,
    required String initial,
    bool multiline = false,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: multiline ? 4 : 1,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onSubmitted: multiline
              ? null
              : (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _rename() async {
    final name = await _promptText(title: 'Name', initial: room.name);
    if (name == null || name.isEmpty) return;
    await _run(() => room.setName(name));
  }

  Future<void> _editTopic() async {
    final topic = await _promptText(
      title: 'Topic',
      initial: room.topic,
      multiline: true,
    );
    if (topic == null) return;
    await _run(() => room.setDescription(topic));
  }

  Future<void> _changeImage() async {
    final picked = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Images',
          extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp'],
        ),
      ],
    );
    if (picked == null) return;
    await _run(() async {
      final bytes = await picked.readAsBytes();
      await room.setAvatar(MatrixImageFile(bytes: bytes, name: picked.name));
    });
  }

  Future<void> _leave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(room.isSpace ? 'Leave space?' : 'Leave room?'),
        content: Text(
          'You will no longer see ${room.getLocalizedDisplayname()}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await room.leave();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _showError(e);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayname = room.getLocalizedDisplayname();
    final canRename = room.canChangeStateEvent(EventTypes.RoomName);
    final canTopic = room.canChangeStateEvent(EventTypes.RoomTopic);
    final canAvatar = room.canChangeStateEvent(EventTypes.RoomAvatar);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 12, 8),
              child: Row(
                children: [
                  Text(
                    room.isSpace ? 'Space settings' : 'Channel settings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
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
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  ListTile(
                    leading: MxcAvatar(
                      client: room.client,
                      name: displayname,
                      avatarUrl: room.avatar,
                    ),
                    title: Text(displayname),
                    subtitle: Text(
                      room.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      tooltip: 'Copy room ID',
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: room.id)),
                    ),
                  ),
                  if (canAvatar || canRename)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          if (canAvatar)
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _changeImage,
                              icon: const Icon(Icons.image_outlined, size: 18),
                              label: Text(
                                room.isSpace
                                    ? 'Change space image'
                                    : 'Change image',
                              ),
                            ),
                          if (canRename)
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _rename,
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Rename'),
                            ),
                        ],
                      ),
                    ),
                  ListTile(
                    leading: const Icon(Icons.notes_outlined),
                    title: const Text('Topic'),
                    subtitle: Text(
                      room.topic.isEmpty ? 'No topic set' : room.topic,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: canTopic
                        ? IconButton(
                            tooltip: 'Edit topic',
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: _busy ? null : _editTopic,
                          )
                        : null,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('Notifications'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SegmentedButton<PushRuleState>(
                      segments: const [
                        ButtonSegment(
                          value: PushRuleState.notify,
                          label: Text('All'),
                        ),
                        ButtonSegment(
                          value: PushRuleState.mentionsOnly,
                          label: Text('Mentions'),
                        ),
                        ButtonSegment(
                          value: PushRuleState.dontNotify,
                          label: Text('Muted'),
                        ),
                      ],
                      selected: {room.pushRuleState},
                      onSelectionChanged: _busy
                          ? null
                          : (selection) => _run(
                              () => room.setPushRuleState(selection.single),
                            ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(
                      room.encrypted ? Icons.lock_outline : Icons.lock_open,
                    ),
                    title: Text(
                      room.encrypted ? 'End-to-end encrypted' : 'Not encrypted',
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_add_outlined),
                    title: Text(
                      room.isSpace ? 'Invite to space' : 'Invite to room',
                    ),
                    enabled: room.canInvite && !_busy,
                    onTap: () => showInviteDialog(context, room),
                  ),
                  ListTile(
                    leading: Icon(Icons.logout, color: colorScheme.error),
                    title: Text(
                      room.isSpace ? 'Leave space' : 'Leave room',
                      style: TextStyle(color: colorScheme.error),
                    ),
                    enabled: !_busy,
                    onTap: _leave,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
