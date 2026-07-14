import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

/// Handles tapping a room in any list: shows a join/reject dialog for
/// invitations. Returns true if the room should be opened afterwards.
Future<bool> confirmRoomTap(BuildContext context, Room room) async {
  if (room.membership != Membership.invite) return true;

  final join = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(room.getLocalizedDisplayname()),
      content: const Text('You have been invited to this room.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Reject'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Join'),
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
      title: const Text('Sign out'),
      content: const Text('Do you want to sign out of your account?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Sign out'),
        ),
      ],
    ),
  );
  if (confirmed == true) await client.logout();
}
