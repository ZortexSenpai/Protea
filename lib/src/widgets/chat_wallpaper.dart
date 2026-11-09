import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../settings.dart';

/// Where picked wallpapers are kept. The file is copied in rather than
/// referenced where it was found, so moving or deleting the original doesn't
/// empty the chat background later.
Future<Directory> _wallpaperDirectory() async {
  final support = await getApplicationSupportDirectory();
  return Directory(p.join(support.path, 'wallpapers')).create(recursive: true);
}

/// Asks for an image and copies it in, returning its path — or null when the
/// picker was dismissed.
Future<String?> pickChatWallpaper() async {
  final picked = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Images',
        extensions: ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'],
      ),
    ],
  );
  if (picked == null) return null;
  final directory = await _wallpaperDirectory();
  final name =
      '${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}';
  final file = File(p.join(directory.path, name));
  await file.writeAsBytes(await picked.readAsBytes());
  return file.path;
}

/// Deletes a wallpaper Protea copied in. Quietly does nothing for a path
/// outside the wallpaper directory or a file already gone.
Future<void> deleteChatWallpaper(String path) async {
  if (path.isEmpty) return;
  try {
    final directory = await _wallpaperDirectory();
    if (p.isWithin(directory.path, path)) await File(path).delete();
  } catch (_) {}
}

/// The chat wallpaper, as a layer to put at the bottom of the timeline's
/// stack. Nothing when none is set. The image sits between the page
/// background and the messages, faded and blurred to whatever keeps text
/// readable.
class ChatWallpaper extends StatelessWidget {
  const ChatWallpaper({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final path = settings.chatWallpaper;
    if (path.isEmpty) return const SizedBox.shrink();
    final blur = settings.chatWallpaperBlur;
    Widget image = Image(
      image: FileImage(File(path)),
      fit: BoxFit.cover,
      // A wallpaper whose file went missing must not take the chat with it.
      errorBuilder: (context, _, _) => const SizedBox.shrink(),
    );
    if (blur > 0) {
      image = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: image,
      );
    }
    // Nothing here reacts to the pointer; the messages above do.
    return IgnorePointer(
      child: Opacity(
        opacity: settings.chatWallpaperOpacity.clamp(0.0, 1.0),
        child: image,
      ),
    );
  }
}
