import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import 'l10n.dart';
import 'nicknames.dart';

/// Handles tapping a room in any list: shows a join/reject dialog for
/// invitations. Returns true if the room should be opened afterwards.
Future<bool> confirmRoomTap(BuildContext context, Room room) async {
  if (room.membership == Membership.knock) {
    final withdraw = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(room.nickOrDisplayname),
        content: Text(context.l10n.knockPendingWaiting),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.withdrawKnock),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.ok),
          ),
        ],
      ),
    );
    if (withdraw == true) {
      try {
        await room.leave();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
    return false;
  }
  if (room.membership != Membership.invite) return true;

  final join = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(room.nickOrDisplayname),
      content: Text(context.l10n.youHaveBeenInvited),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.reject),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(context.l10n.join),
        ),
      ],
    ),
  );
  if (join == null) return false;
  try {
    join ? await room.join() : await room.leave();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    return false;
  }
  return join;
}

/// Shows a confirmation dialog and signs out if the user confirms.
Future<void> confirmLogout(BuildContext context, Client client) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.signOut),
      content: Text(context.l10n.signOutConfirmation),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(context.l10n.signOut),
        ),
      ],
    ),
  );
  if (confirmed == true) await client.logout();
}

extension UnreadBadgeRoom on Room {
  /// Count for the room's unread badge: the server's notification count,
  /// or 1 for a room manually marked unread (which has no count of its own).
  int get unreadBadgeCount =>
      notificationCount > 0 ? notificationCount : (markedUnread ? 1 : 0);
}
