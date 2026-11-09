import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matrix/matrix.dart';
import 'package:pasteboard/pasteboard.dart';

import 'l10n.dart';

/// Implemented by the Linux runner (linux/runner/my_application.cc):
/// pasteboard's writeImage is a no-op on Linux.
const _linuxClipboard = MethodChannel('protea/clipboard');

/// Puts encoded image [bytes] (PNG, JPEG, GIF, …) on the system clipboard.
Future<void> writeImageToClipboard(Uint8List bytes) async {
  if (Platform.isLinux) {
    await _linuxClipboard.invokeMethod<void>('writeImage', bytes);
  } else {
    await Pasteboard.writeImage(bytes);
  }
}

/// Downloads the full image of [event] and copies it to the clipboard.
Future<void> copyImageAttachment(BuildContext context, Event event) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    final file = await event.downloadAndDecryptAttachment();
    await writeImageToClipboard(file.bytes);
    messenger.showSnackBar(SnackBar(content: Text(l10n.imageCopied)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.toString())));
  }
}

/// Downloads the attachment of [event] and saves it where the user picks.
Future<void> saveAttachment(BuildContext context, Event event) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    final file = await event.downloadAndDecryptAttachment();
    final location = await getSaveLocation(suggestedName: file.name);
    if (location == null) return;
    await XFile.fromData(
      file.bytes,
      mimeType: file.mimeType,
      name: file.name,
    ).saveTo(location.path);
    messenger.showSnackBar(SnackBar(content: Text(l10n.savedFile(file.name))));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.toString())));
  }
}
