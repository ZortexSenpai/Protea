import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../l10n.dart';
import '../pages/room_page.dart';
import '../settings.dart';

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
  bool _encrypted = true;
  bool _busy = false;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  String get _label => switch (_mode) {
    _NewChatMode.dm => context.l10n.userIdLabel,
    _NewChatMode.group => context.l10n.groupName,
    _NewChatMode.join => context.l10n.roomIdOrAliasLabel,
  };

  Future<void> _submit() async {
    final input = _inputController.text.trim();
    if (input.isEmpty) return;
    setState(() => _busy = true);
    try {
      final String roomId;
      switch (_mode) {
        case _NewChatMode.dm:
          roomId = await widget.client.startDirectChat(
            input,
            enableEncryption: SettingsScope.of(context).encryptNewDirectChats,
          );
        case _NewChatMode.group:
          roomId = await widget.client.createGroupChat(
            groupName: input,
            enableEncryption: _encrypted,
          );
        case _NewChatMode.join:
          roomId = await widget.client.joinRoom(input);
      }
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
                  : (selection) => setState(() => _mode = selection.single),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _inputController,
              enabled: !_busy,
              autofocus: true,
              decoration: InputDecoration(
                labelText: _label,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_mode == _NewChatMode.group)
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
