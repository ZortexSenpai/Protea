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
