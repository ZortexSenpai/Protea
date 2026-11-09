// Matrix's Visibility enum is used below; Flutter's Visibility widget is not.
import 'package:flutter/material.dart' hide Visibility;
import 'package:matrix/matrix.dart';

import '../l10n.dart';

enum _SpaceMode { create, join }

/// Dialog to create a new space or join an existing one by ID or alias.
Future<void> showNewSpaceDialog(BuildContext context, Client client) =>
    showDialog(
      context: context,
      builder: (_) => NewSpaceDialog(client: client),
    );

class NewSpaceDialog extends StatefulWidget {
  const NewSpaceDialog({super.key, required this.client});

  final Client client;

  @override
  State<NewSpaceDialog> createState() => _NewSpaceDialogState();
}

class _NewSpaceDialogState extends State<NewSpaceDialog> {
  _SpaceMode _mode = _SpaceMode.create;
  final _inputController = TextEditingController();
  bool _public = false;
  bool _busy = false;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final input = _inputController.text.trim();
    if (input.isEmpty) return;
    setState(() => _busy = true);
    try {
      switch (_mode) {
        case _SpaceMode.create:
          await widget.client.createRoom(
            name: input,
            creationContent: {'type': 'm.space'},
            visibility: _public ? Visibility.public : Visibility.private,
            preset: _public
                ? CreateRoomPreset.publicChat
                : CreateRoomPreset.privateChat,
          );
        case _SpaceMode.join:
          await widget.client.joinRoom(input);
      }
      if (mounted) Navigator.of(context).pop();
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
      title: Text(context.l10n.newSpace),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<_SpaceMode>(
              segments: [
                ButtonSegment(
                  value: _SpaceMode.create,
                  label: Text(context.l10n.create),
                  icon: const Icon(Icons.workspaces_outline),
                ),
                ButtonSegment(
                  value: _SpaceMode.join,
                  label: Text(context.l10n.join),
                  icon: const Icon(Icons.login),
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
                labelText: _mode == _SpaceMode.create
                    ? context.l10n.spaceName
                    : context.l10n.roomIdOrAliasLabel,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_mode == _SpaceMode.create)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.publicSpace),
                value: _public,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _public = value),
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
              : Text(
                  _mode == _SpaceMode.create
                      ? context.l10n.create
                      : context.l10n.join,
                ),
        ),
      ],
    );
  }
}
