import 'package:flutter/foundation.dart';

/// Lets deeply nested widgets (profile card, dialogs) ask the active home
/// layout to select a room in place instead of pushing a full-screen chat.
class RoomNavigator extends ChangeNotifier {
  RoomNavigator._();

  static final instance = RoomNavigator._();

  String? roomId;

  /// Requests the active layout to open [id]. Returns false when no layout
  /// is listening (e.g. the plain list layout), in which case the caller
  /// should fall back to pushing a chat page itself.
  bool open(String id) {
    if (!hasListeners) return false;
    roomId = id;
    notifyListeners();
    return true;
  }
}

/// Lets keyboard navigation (the quick switcher) put the caret in a room's
/// message box once its chat page shows, so typing can start right away.
/// Kept apart from [RoomNavigator]: chat pages listen here, while
/// [RoomNavigator.open] takes any listener for an active home layout.
class ComposerFocus extends ChangeNotifier {
  ComposerFocus._();

  static final instance = ComposerFocus._();

  /// Room whose composer should take focus; the chat page that takes it
  /// clears it, so a page opened for that room later starts unfocused.
  String? roomId;

  void request(String id) {
    roomId = id;
    notifyListeners();
  }
}
