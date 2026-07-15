import 'dart:async';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../l10n.dart';
import '../pages/room_page.dart';
import '../settings.dart';
import 'mxc_avatar.dart';

enum _NewChatMode { dm, group, join }

/// Dialog to start a direct chat, create a group room or join an existing
/// room by ID or alias.
Future<void> showNewChatDialog(BuildContext context, Client client) =>
    showDialog(
      context: context,
      builder: (_) => NewChatDialog(client: client),
    );

class NewChatDialog extends StatefulWidget {
  const NewChatDialog({super.key, required this.client});

  final Client client;

  @override
  State<NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<NewChatDialog> {
  _NewChatMode _mode = _NewChatMode.dm;
  final _inputController = TextEditingController();
  Timer? _debounce;
  List<Profile> _results = [];
  bool _searching = false;
  bool _encrypted = true;
  bool _encryptedInitialized = false;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_encryptedInitialized) {
      _encryptedInitialized = true;
      _encrypted = _defaultEncrypted;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _inputController.dispose();
    super.dispose();
  }

  bool get _defaultEncrypted => switch (_mode) {
    _NewChatMode.dm => SettingsScope.of(context).encryptNewDirectChats,
    _ => true,
  };

  void _onModeChanged(_NewChatMode mode) {
    _debounce?.cancel();
    setState(() {
      _mode = mode;
      _encrypted = _defaultEncrypted;
      _results = [];
      _searching = false;
    });
  }

  void _onInputChanged(String text) {
    if (_mode != _NewChatMode.dm) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _search);
    setState(() {});
  }

  Future<void> _search() async {
    if (_busy || _mode != _NewChatMode.dm) return;
    final term = _inputController.text.trim();
    if (term.length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final response = await widget.client.searchUserDirectory(term, limit: 10);
      if (mounted) setState(() => _results = response.results);
    } catch (_) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  String get _label => switch (_mode) {
    _NewChatMode.dm => context.l10n.userIdLabel,
    _NewChatMode.group => context.l10n.groupName,
    _NewChatMode.join => context.l10n.roomIdOrAliasLabel,
  };

  Future<void> _submit() {
    final input = _inputController.text.trim();
    if (input.isEmpty) return Future.value();
    return switch (_mode) {
      _NewChatMode.dm => _startDm(input),
      _NewChatMode.group => _open(
        () => widget.client.createGroupChat(
          groupName: input,
          enableEncryption: _encrypted,
        ),
      ),
      _NewChatMode.join => _open(() => widget.client.joinRoom(input)),
    };
  }

  Future<void> _startDm(String userId) => _open(
    () => widget.client.startDirectChat(userId, enableEncryption: _encrypted),
  );

  Future<void> _open(Future<String> Function() create) async {
    _debounce?.cancel();
    setState(() => _busy = true);
    try {
      final roomId = await create();
      if (!mounted) return;
      final room = widget.client.getRoomById(roomId);
      final navigator = Navigator.of(context);
      navigator.pop();
      if (room != null) {
        navigator.push(MaterialPageRoute(builder: (_) => RoomPage(room: room)));
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
    return AlertDialog(
      title: Text(context.l10n.newChat),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<_NewChatMode>(
              segments: [
                ButtonSegment(
                  value: _NewChatMode.dm,
                  label: Text(context.l10n.direct),
                  icon: const Icon(Icons.person_outline),
                ),
                ButtonSegment(
                  value: _NewChatMode.group,
                  label: Text(context.l10n.group),
                  icon: const Icon(Icons.group_outlined),
                ),
                ButtonSegment(
                  value: _NewChatMode.join,
                  label: Text(context.l10n.join),
                  icon: const Icon(Icons.tag),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: _busy
                  ? null
                  : (selection) => _onModeChanged(selection.single),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _inputController,
              enabled: !_busy,
              autofocus: true,
              decoration: InputDecoration(
                labelText: _label,
                hintText: _mode == _NewChatMode.dm
                    ? context.l10n.searchUserHint
                    : null,
                border: const OutlineInputBorder(),
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
              onChanged: _onInputChanged,
              onSubmitted: (_) => _submit(),
            ),
            if (_mode == _NewChatMode.dm && _results.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final profile in _results)
                      ListTile(
                        dense: true,
                        enabled: !_busy,
                        leading: MxcAvatar(
                          client: widget.client,
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
                        onTap: () => _startDm(profile.userId),
                      ),
                  ],
                ),
              ),
            if (_mode != _NewChatMode.join)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.endToEndEncrypted),
                value: _encrypted,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _encrypted = value),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(switch (_mode) {
                  _NewChatMode.dm => context.l10n.startChat,
                  _NewChatMode.group => context.l10n.create,
                  _NewChatMode.join => context.l10n.join,
                }),
        ),
      ],
    );
  }
}
