import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:matrix/matrix.dart';

import 'mxc_avatar.dart';

/// Searches the room history (local first, then server pages) for messages
/// containing a text.
Future<void> showMessageSearch(
  BuildContext context,
  Room room, {
  ValueChanged<String>? onJumpToMessage,
}) =>
    showDialog(
      context: context,
      builder: (_) => MessageSearchDialog(
        room: room,
        onJumpToMessage: onJumpToMessage,
      ),
    );

class MessageSearchDialog extends StatefulWidget {
  const MessageSearchDialog({
    super.key,
    required this.room,
    this.onJumpToMessage,
  });

  final Room room;

  /// Called with the event ID when a result is tapped; the dialog closes
  /// itself first.
  final ValueChanged<String>? onJumpToMessage;

  @override
  State<MessageSearchDialog> createState() => _MessageSearchDialogState();
}

class _MessageSearchDialogState extends State<MessageSearchDialog> {
  final _queryController = TextEditingController();
  final List<Event> _results = [];
  String? _nextBatch;
  DateTime? _searchedUntil;
  bool _searching = false;
  bool _searchedOnce = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search({bool more = false}) async {
    final query = _queryController.text.trim();
    if (query.isEmpty || _searching) return;
    setState(() {
      _searching = true;
      if (!more) {
        _results.clear();
        _nextBatch = null;
        _searchedUntil = null;
        _searchedOnce = true;
      }
    });
    try {
      final result = await widget.room.searchEvents(
        searchTerm: query,
        nextBatch: more ? _nextBatch : null,
        limit: 500,
      );
      if (!mounted) return;
      setState(() {
        _results.addAll(result.events);
        _nextBatch = result.nextBatch;
        _searchedUntil = result.searchedUntil;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _showResult(Event event) {
    final sender = event.senderFromMemoryOrFallback.calcDisplayname();
    final body = event.calcLocalizedBodyFallback(
      const MatrixDefaultLocalizations(),
      hideReply: true,
      plaintextBody: true,
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(sender),
        content: SelectableText(body),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: body));
              Navigator.of(context).pop();
            },
            child: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _queryController,
                      autofocus: true,
                      enabled: !_searching,
                      decoration: const InputDecoration(
                        hintText: 'Search messages…',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _search(),
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
              child: !_searchedOnce
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Search the history of this room.'),
                    )
                  : _results.isEmpty && !_searching
                      ? const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('No messages found.'),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final event = _results[index];
                            final sender = event.senderFromMemoryOrFallback;
                            return ListTile(
                              leading: MxcAvatar(
                                client: widget.room.client,
                                name: sender.calcDisplayname(),
                                avatarUrl: sender.avatarUrl,
                                radius: 16,
                              ),
                              title: Text(
                                sender.calcDisplayname(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                event.calcLocalizedBodyFallback(
                                  const MatrixDefaultLocalizations(),
                                  hideReply: true,
                                  plaintextBody: true,
                                  removeMarkdown: true,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Text(
                                DateFormat.yMMMd()
                                    .format(event.originServerTs),
                                style:
                                    Theme.of(context).textTheme.labelSmall,
                              ),
                              onTap: () {
                                final jump = widget.onJumpToMessage;
                                if (jump != null) {
                                  Navigator.of(context).pop();
                                  jump(event.eventId);
                                } else {
                                  _showResult(event);
                                }
                              },
                            );
                          },
                        ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  if (_searchedUntil != null)
                    Expanded(
                      child: Text(
                        'Searched back to '
                        '${DateFormat.yMMMd().format(_searchedUntil!)}'
                        '${_nextBatch == null ? ' (beginning)' : ''}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    )
                  else
                    const Spacer(),
                  if (_searching)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (_nextBatch != null)
                    TextButton(
                      onPressed: () => _search(more: true),
                      child: const Text('Search further back'),
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
