import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matrix/matrix.dart';

import '../l10n.dart';
import '../nicknames.dart';
import '../pages/room_page.dart';
import '../room_actions.dart';
import '../room_navigator.dart';
import 'mxc_avatar.dart';
import 'user_profile_card.dart';

/// Opens the quick switcher: type to find rooms, direct messages and people,
/// Enter or click to open (or start a direct chat with a person).
Future<void> showQuickSwitcher(BuildContext context, Client client) =>
    showDialog(
      context: context,
      builder: (_) => QuickSwitcherDialog(client: client),
    );

/// Listens for Ctrl/Cmd+T anywhere in the app and opens the quick switcher.
class QuickSwitcherListener extends StatefulWidget {
  const QuickSwitcherListener({
    super.key,
    required this.client,
    required this.child,
  });

  final Client client;
  final Widget child;

  @override
  State<QuickSwitcherListener> createState() => _QuickSwitcherListenerState();
}

class _QuickSwitcherListenerState extends State<QuickSwitcherListener> {
  bool _open = false;

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyT &&
        !HardwareKeyboard.instance.isShiftPressed &&
        (HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed) &&
        !_open) {
      _open = true;
      showQuickSwitcher(
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

/// A quick switcher result: a joined room (or direct chat), or a person
/// without a direct chat yet.
class _Entry {
  _Entry.room(Room this.room)
    : userId = null,
      name = room.nickOrDisplayname,
      avatarUrl = room.avatar;

  _Entry.user(String this.userId, this.name, this.avatarUrl) : room = null;

  final Room? room;
  final String? userId;
  final String name;
  final Uri? avatarUrl;
}

class QuickSwitcherDialog extends StatefulWidget {
  const QuickSwitcherDialog({super.key, required this.client});

  final Client client;

  @override
  State<QuickSwitcherDialog> createState() => _QuickSwitcherDialogState();
}

class _QuickSwitcherDialogState extends State<QuickSwitcherDialog> {
  String _query = '';
  int _highlighted = 0;
  final _highlightedKey = GlobalKey();

  Timer? _debounce;
  List<Profile> _directory = [];
  bool _busy = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Like Discord: a leading `@` searches only people, `#` only rooms.
  ({String term, bool rooms, bool people}) get _parsed {
    if (_query.startsWith('@')) {
      return (term: _query.substring(1).trim(), rooms: false, people: true);
    }
    if (_query.startsWith('#')) {
      return (term: _query.substring(1).trim(), rooms: true, people: false);
    }
    return (term: _query, rooms: true, people: true);
  }

  List<_Entry> get _entries {
    final client = widget.client;
    final rooms =
        client.rooms
            .where(
              (room) =>
                  !room.isSpace &&
                  room.membership != Membership.leave &&
                  room.membership != Membership.ban,
            )
            .toList()
          ..sort(
            (a, b) => (b.lastEvent?.originServerTs ?? DateTime(0)).compareTo(
              a.lastEvent?.originServerTs ?? DateTime(0),
            ),
          );
    final parsed = _parsed;
    final term = parsed.term.toLowerCase();
    if (term.isEmpty) {
      return [
        for (final room in rooms)
          if (parsed.rooms || room.isDirectChat) _Entry.room(room),
      ];
    }

    bool matches(String? value) =>
        value != null && value.toLowerCase().contains(term);

    final entries = <_Entry>[];
    final directPartners = <String>{};
    for (final room in rooms) {
      final partner = room.directChatMatrixID;
      if (partner != null) directPartners.add(partner);
      if (!parsed.rooms && partner == null) continue;
      if (matches(room.nickOrDisplayname) ||
          matches(room.canonicalAlias) ||
          matches(partner)) {
        entries.add(_Entry.room(room));
      }
    }
    // Starts-with matches first, keeping recency order within each half.
    entries.sort((a, b) {
      final aStarts = a.name.toLowerCase().startsWith(term) ? 0 : 1;
      final bStarts = b.name.toLowerCase().startsWith(term) ? 0 : 1;
      return aStarts - bStarts;
    });

    if (!parsed.people) return entries;

    // People without a direct chat: members of joined rooms first (their
    // state is already in memory), then the server's user directory.
    final seen = {client.userID, ...directPartners};
    final people = <_Entry>[];
    for (final room in rooms) {
      for (final user in room.getParticipants()) {
        if (seen.contains(user.id)) continue;
        final name = user.nickOrDisplayname;
        if (matches(name) || matches(user.id)) {
          seen.add(user.id);
          people.add(_Entry.user(user.id, name, user.avatarUrl));
        }
      }
    }
    for (final profile in _directory) {
      if (seen.contains(profile.userId)) continue;
      seen.add(profile.userId);
      people.add(
        _Entry.user(
          profile.userId,
          nicknameOf(client, profile.userId) ??
              profile.displayName ??
              profile.userId,
          profile.avatarUrl,
        ),
      );
    }
    return [...entries, ...people];
  }

  void _onChanged(String value) {
    setState(() {
      _query = value.trim();
      _highlighted = 0;
    });
    _debounce?.cancel();
    final parsed = _parsed;
    if (!parsed.people || parsed.term.length < 2) {
      if (_directory.isNotEmpty) setState(() => _directory = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final term = parsed.term;
      try {
        final response = await widget.client.searchUserDirectory(
          term,
          limit: 10,
        );
        if (mounted && _parsed.term == term) {
          setState(() => _directory = response.results);
        }
      } catch (_) {
        // The directory is a bonus on top of local results; ignore failures.
      }
    });
  }

  void _move(int delta, int count) {
    if (count == 0) return;
    setState(() => _highlighted = (_highlighted + delta) % count);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _highlightedKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          alignmentPolicy: delta > 0
              ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
              : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      }
    });
  }

  void _open(_Entry entry) {
    if (_busy) return;
    final navigator = Navigator.of(context);
    if (entry.room case final room?) {
      navigator.pop();
      ComposerFocus.instance.request(room.id);
      // Let the active home layout select the room in place; only push a
      // full-screen chat when no layout is listening.
      if (RoomNavigator.instance.open(room.id)) return;
      navigator.push(MaterialPageRoute(builder: (_) => RoomPage(room: room)));
      return;
    }
    setState(() => _busy = true);
    openDirectChat(
      context,
      widget.client,
      entry.userId!,
      beforeOpen: navigator.pop,
      focusComposer: true,
    ).whenComplete(() {
      if (mounted) setState(() => _busy = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    final highlighted = entries.isEmpty
        ? -1
        : _highlighted.clamp(0, entries.length - 1);
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 80, left: 24, right: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                      _move(1, entries.length),
                  const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                      _move(-1, entries.length),
                  const SingleActivator(LogicalKeyboardKey.tab): () =>
                      _move(1, entries.length),
                  const SingleActivator(
                    LogicalKeyboardKey.tab,
                    shift: true,
                  ): () =>
                      _move(-1, entries.length),
                },
                child: TextField(
                  autofocus: true,
                  enabled: !_busy,
                  decoration: InputDecoration(
                    hintText: context.l10n.quickSwitcherHint,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _busy
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: _onChanged,
                  onSubmitted: (_) {
                    if (highlighted >= 0) _open(entries[highlighted]);
                  },
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: entries.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(context.l10n.noSearchResults),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final room = entry.room;
                        final subtitle =
                            entry.userId ?? room?.directChatMatrixID;
                        return ListTile(
                          key: index == highlighted ? _highlightedKey : null,
                          dense: true,
                          selected: index == highlighted,
                          selectedTileColor: colorScheme.secondaryContainer,
                          selectedColor: colorScheme.onSecondaryContainer,
                          leading: MxcAvatar(
                            client: widget.client,
                            name: entry.name,
                            avatarUrl: entry.avatarUrl,
                            radius: 14,
                          ),
                          title: Text(
                            entry.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: subtitle == null
                              ? null
                              : Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          trailing: room == null
                              ? Icon(
                                  Icons.person_add_alt_outlined,
                                  size: 18,
                                  color: colorScheme.onSurfaceVariant,
                                )
                              : room.unreadBadgeCount > 0
                              ? Badge(
                                  label: Text(room.unreadBadgeCount.toString()),
                                )
                              : Icon(
                                  room.isDirectChat
                                      ? Icons.alternate_email
                                      : Icons.tag,
                                  size: 16,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          onTap: () => _open(entry),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Text(
                context.l10n.quickSwitcherTip,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
