import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../l10n.dart';
import '../nicknames.dart';
import 'html_message.dart';
import 'mxc_avatar.dart';

/// Shows who reacted to a message with which emoji. [reactions] maps each
/// reaction key to its reaction events; [initialKey] preselects that
/// emoji's tab (null opens the "All" tab).
Future<void> showReactionsDialog(
  BuildContext context, {
  required Room room,
  required Map<String, List<Event>> reactions,
  String? initialKey,
}) => showDialog(
  context: context,
  builder: (_) =>
      ReactionsDialog(room: room, reactions: reactions, initialKey: initialKey),
);

class ReactionsDialog extends StatefulWidget {
  const ReactionsDialog({
    super.key,
    required this.room,
    required this.reactions,
    this.initialKey,
  });

  final Room room;
  final Map<String, List<Event>> reactions;
  final String? initialKey;

  @override
  State<ReactionsDialog> createState() => _ReactionsDialogState();
}

class _ReactionsDialogState extends State<ReactionsDialog> {
  /// The selected reaction key; null is the "All" tab.
  String? _selected;

  @override
  void initState() {
    super.initState();
    if (widget.reactions.containsKey(widget.initialKey)) {
      _selected = widget.initialKey;
    }
  }

  /// The reaction key rendered as text, or as the custom emote image for
  /// an `mxc://` key (MSC4027).
  Widget _keyLabel(String key, List<Event> events, {double size = 18}) {
    final mxc = Uri.tryParse(key);
    if (mxc == null || !mxc.isScheme('mxc')) {
      return Text(key, style: TextStyle(fontSize: size));
    }
    final shortcode = events
        .map((reaction) => reaction.content.tryGet<String>('shortcode') ?? '')
        .firstWhere((code) => code.isNotEmpty, orElse: () => '');
    return InlineEmote(
      client: widget.room.client,
      uri: mxc,
      name: shortcode,
      size: size,
    );
  }

  Widget _tab(BuildContext context, String? key, Widget label, int count) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = _selected == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        mouseCursor: SystemMouseCursors.click,
        onTap: () => setState(() => _selected = key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? colorScheme.primary : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              label,
              const SizedBox(width: 6),
              Text('$count', style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reactions = widget.reactions;
    final total = reactions.values.fold(0, (sum, list) => sum + list.length);
    final selected = _selected;
    final rows = [
      for (final entry in reactions.entries)
        if (selected == null || entry.key == selected)
          for (final reaction in entry.value) (entry.key, reaction),
    ];
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 12, 8),
              child: Row(
                children: [
                  Text(
                    context.l10n.reactions,
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  _tab(
                    context,
                    null,
                    Text(
                      context.l10n.all,
                      style: const TextStyle(fontSize: 13),
                    ),
                    total,
                  ),
                  for (final entry in reactions.entries)
                    _tab(
                      context,
                      entry.key,
                      _keyLabel(entry.key, entry.value, size: 16),
                      entry.value.length,
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final (key, reaction) = rows[index];
                  final sender = reaction.senderFromMemoryOrFallback;
                  final name = sender.nickOrDisplayname;
                  return ListTile(
                    leading: MxcAvatar(
                      client: widget.room.client,
                      name: name,
                      avatarUrl: sender.avatarUrl,
                      radius: 16,
                    ),
                    title: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      sender.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // On the "All" tab each row says which emoji it was.
                    trailing: selected == null
                        ? _keyLabel(key, reactions[key]!, size: 20)
                        : null,
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
