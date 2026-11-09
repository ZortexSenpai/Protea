import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../l10n.dart';
import '../nicknames.dart';
import 'mxc_avatar.dart';

/// Whether [room] is an open request: an invitation waiting for an answer,
/// or the user's own knock waiting for a moderator.
bool isOpenRequest(Room room) =>
    room.membership == Membership.invite || room.membership == Membership.knock;

/// Open requests across the whole account, invitations before knocks.
List<Room> openRequests(Iterable<Room> rooms) => [
  for (final room in rooms)
    if (room.membership == Membership.invite) room,
  for (final room in rooms)
    if (room.membership == Membership.knock) room,
];

/// "Requests" sidebar category: invitations to rooms, direct chats and
/// spaces with inline accept/decline, and pending knocks to withdraw.
class RequestsSection extends StatelessWidget {
  const RequestsSection({
    super.key,
    required this.requests,
    required this.onTap,
    required this.onJoined,
  });

  final List<Room> requests;

  /// Tapping a request opens the same invitation/knock dialog as any room.
  final void Function(Room room) onTap;

  /// Called once an invitation was accepted inline.
  final void Function(Room room) onJoined;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: [
              Icon(
                Icons.mail_outline,
                size: 12,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '${context.l10n.requests.toUpperCase()} — ${requests.length}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        for (final room in requests)
          _RequestTile(
            key: ValueKey(room.id),
            room: room,
            onTap: () => onTap(room),
            onJoined: () => onJoined(room),
          ),
      ],
    );
  }
}

class _RequestTile extends StatefulWidget {
  const _RequestTile({
    super.key,
    required this.room,
    required this.onTap,
    required this.onJoined,
  });

  final Room room;
  final VoidCallback onTap;
  final VoidCallback onJoined;

  @override
  State<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends State<_RequestTile> {
  bool _busy = false;

  /// Runs [action] behind a spinner. On success the spinner stays until
  /// sync moves the room out of the requests, so the buttons don't flash
  /// back in between.
  Future<bool> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return false;
    }
  }

  Future<void> _accept() async {
    if (await _run(widget.room.join)) widget.onJoined();
  }

  /// Declines an invitation or withdraws a knock.
  Future<void> _leave() => _run(widget.room.leave);

  String _subtitle(BuildContext context) {
    final room = widget.room;
    if (room.membership == Membership.knock) return context.l10n.knockPending;
    final userId = room.client.userID;
    final inviterId = userId == null
        ? null
        : room.getState(EventTypes.RoomMember, userId)?.senderId;
    // A direct chat is already named after the inviter: show their Matrix
    // ID instead, so an impersonating display name stands out.
    if (room.isDirectChat && inviterId != null) return inviterId;
    return [
      if (room.isSpace) context.l10n.space,
      inviterId == null
          ? context.l10n.invitation
          : context.l10n.invitedBy(
              room
                  .unsafeGetUserFromMemoryOrFallback(inviterId)
                  .nickOrDisplayname,
            ),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final isInvite = room.membership == Membership.invite;
    return ListTile(
      dense: true,
      onTap: _busy ? null : widget.onTap,
      leading: MxcAvatar(
        client: room.client,
        name: room.nickOrDisplayname,
        avatarUrl: room.avatar,
        radius: 14,
      ),
      title: Text(
        room.nickOrDisplayname,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: isInvite ? const TextStyle(fontWeight: FontWeight.bold) : null,
      ),
      subtitle: Text(
        _subtitle(context),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isInvite)
                  IconButton(
                    tooltip: context.l10n.accept,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.check, size: 20),
                    onPressed: _accept,
                  ),
                IconButton(
                  tooltip: isInvite
                      ? context.l10n.decline
                      : context.l10n.withdrawKnock,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: _leave,
                ),
              ],
            ),
    );
  }
}
