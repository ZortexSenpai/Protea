import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:matrix/matrix.dart';

import '../l10n.dart';
import '../nicknames.dart';
import '../pages/room_page.dart';
import 'mxc_avatar.dart';

/// Opens the cross-room message search, backed by the server's /search API.
Future<void> showGlobalSearch(BuildContext context, Client client) =>
    showDialog(
      context: context,
      builder: (_) => GlobalSearchDialog(client: client),
    );

/// Listens for Ctrl/Cmd+Shift+F anywhere in the app and opens the global
/// search.
class GlobalSearchListener extends StatefulWidget {
  const GlobalSearchListener({
    super.key,
    required this.client,
    required this.child,
  });

  final Client client;
  final Widget child;

  @override
  State<GlobalSearchListener> createState() => _GlobalSearchListenerState();
}

class _GlobalSearchListenerState extends State<GlobalSearchListener> {
  bool _open = false;

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyF &&
        HardwareKeyboard.instance.isShiftPressed &&
        (HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed) &&
        !_open) {
      _open = true;
      showGlobalSearch(
        context,
        widget.client,
      ).whenComplete(() => _open = false);
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Searches messages across all rooms via the server /search API and opens
/// tapped results in their room, scrolled to the match. Encrypted rooms are
/// not covered — homeservers cannot index what they cannot read.
class GlobalSearchDialog extends StatefulWidget {
  const GlobalSearchDialog({super.key, required this.client});

  final Client client;

  @override
  State<GlobalSearchDialog> createState() => _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends State<GlobalSearchDialog> {
  final _queryController = TextEditingController();
  final List<MatrixEvent> _results = [];
  String? _nextBatch;
  int? _count;
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
        _count = null;
        _searchedOnce = true;
      }
    });
    try {
      final response = await widget.client.search(
        Categories(
          roomEvents: RoomEventsCriteria(
            searchTerm: query,
            orderBy: SearchOrder.recent,
          ),
        ),
        nextBatch: more ? _nextBatch : null,
      );
      if (!mounted) return;
      final roomEvents = response.searchCategories.roomEvents;
      setState(() {
        _results.addAll([
          for (final result in roomEvents?.results ?? <Result>[])
            if (result.result != null) result.result!,
        ]);
        _nextBatch = roomEvents?.nextBatch;
        _count = roomEvents?.count;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _openResult(MatrixEvent event) {
    final room = widget.client.getRoomById(event.roomId ?? '');
    if (room == null) return;
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute(
        builder: (_) => RoomPage(room: room, initialEventId: event.eventId),
      ),
    );
  }

  Widget _buildResultTile(BuildContext context, MatrixEvent event) {
    final room = widget.client.getRoomById(event.roomId ?? '');
    final senderName = room != null
        ? room
              .unsafeGetUserFromMemoryOrFallback(event.senderId)
              .nickOrDisplayname
        : event.senderId.replaceFirst('@', '').split(':').first;
    final roomName = room?.nickOrDisplayname ?? event.roomId ?? '';
    final body = event.content.tryGet<String>('body') ?? '';
    return ListTile(
      leading: room != null
          ? MxcAvatar(
              client: widget.client,
              name: roomName,
              avatarUrl: room.avatar,
              radius: 16,
            )
          : const CircleAvatar(radius: 16, child: Icon(Icons.tag, size: 16)),
      title: Text(
        '$roomName · $senderName',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text(
        DateFormat.yMMMd().format(event.originServerTs),
        style: Theme.of(context).textTheme.labelSmall,
      ),
      enabled: room != null,
      onTap: () => _openResult(event),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
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
                      decoration: InputDecoration(
                        hintText: context.l10n.searchMessagesHint,
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _search(),
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
            const Divider(height: 1),
            Flexible(
              child: !_searchedOnce
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        context.l10n.searchAllRoomsPrompt,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : _results.isEmpty && !_searching
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(context.l10n.noMessagesFound),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _results.length,
                      itemBuilder: (context, index) =>
                          _buildResultTile(context, _results[index]),
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _count != null
                          ? context.l10n.searchResultCount(_count!)
                          : context.l10n.encryptedNotSearchable,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
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
                      child: Text(context.l10n.moreResults),
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
