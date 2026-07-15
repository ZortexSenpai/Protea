import 'package:flutter/material.dart';

import '../l10n.dart';

/// Prompts for a line (or paragraph) of text and returns the trimmed input,
/// or null when cancelled.
///
/// The controller is owned by the dialog's own state, so it is disposed only
/// after the route's exit animation finished — disposing it right after
/// `showDialog` returns crashes when an outer rebuild hits the closing
/// dialog mid-animation.
Future<String?> showTextPromptDialog(
  BuildContext context, {
  required String title,
  String initial = '',
  String? label,
  bool multiline = false,
  String? confirmLabel,
}) => showDialog<String>(
  context: context,
  builder: (_) => _TextPromptDialog(
    title: title,
    initial: initial,
    label: label,
    multiline: multiline,
    confirmLabel: confirmLabel,
  ),
);

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.initial,
    required this.label,
    required this.multiline,
    required this.confirmLabel,
  });

  final String title;
  final String initial;
  final String? label;
  final bool multiline;
  final String? confirmLabel;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: widget.multiline ? 4 : 1,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: widget.multiline
            ? null
            : (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(widget.confirmLabel ?? context.l10n.save),
        ),
      ],
    );
  }
}
