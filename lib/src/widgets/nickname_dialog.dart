import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../l10n.dart';
import '../nicknames.dart';
import 'text_prompt_dialog.dart';

/// Prompts for a nickname for [userId] and saves it. Returns whether a
/// nickname was saved (or removed); errors are shown in a snackbar.
Future<bool> showNicknameDialog(
  BuildContext context,
  Client client,
  String userId,
) async {
  final nickname = await showTextPromptDialog(
    context,
    title: context.l10n.setNickname,
    initial: nicknameOf(client, userId) ?? '',
    label: context.l10n.nicknameHint,
    confirmLabel: context.l10n.save,
  );
  if (nickname == null) return false;
  try {
    await setNickname(client, userId, nickname);
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    return false;
  }
}
