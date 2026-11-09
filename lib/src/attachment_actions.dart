import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matrix/matrix.dart';
import 'package:pasteboard/pasteboard.dart';

import 'l10n.dart';

/// Clipboard calls pasteboard gets wrong, implemented by the runners:
/// `writeImage` on Linux (linux/runner/my_application.cc), where
/// pasteboard's is a no-op, and `files` on macOS
/// (macos/Runner/MainFlutterWindow.swift), where pasteboard's also returns
/// the path component of copied web links.
const _nativeClipboard = MethodChannel('protea/clipboard');

/// Puts encoded image [bytes] (PNG, JPEG, GIF, …) on the system clipboard.
Future<void> writeImageToClipboard(Uint8List bytes) async {
  if (Platform.isLinux) {
    await _nativeClipboard.invokeMethod<void>('writeImage', bytes);
  } else {
    await Pasteboard.writeImage(bytes);
  }
}

/// The files on the clipboard, as a file manager's Copy puts them there;
/// folders are left out. Empty on mobile.
Future<List<File>> readClipboardFiles() async {
  final List<String> paths;
  if (Platform.isMacOS) {
    paths =
        await _nativeClipboard.invokeListMethod<String>('files') ?? const [];
  } else if (Platform.isLinux || Platform.isWindows) {
    paths = await Pasteboard.files();
  } else {
    return const [];
  }
  return [
    for (final path in paths)
      if (await FileSystemEntity.isFile(path)) File(path),
  ];
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
