import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:matrix/matrix.dart';

import 'client_manager.dart';
import 'room_actions.dart';

/// Shows how much is waiting across all logged-in accounts as a badge on
/// the app's icon, so new messages are visible while the window is in the
/// background: on the Dock icon on macOS, as an overlay on the taskbar
/// button on Windows.
///
/// macOS and Windows only; elsewhere [init] does nothing.
class DockBadgeService {
  DockBadgeService(this.manager, {MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('protea/dock');

  final ClientManager manager;

  /// Implemented by the macOS runner (macos/Runner/MainFlutterWindow.swift)
  /// and the Windows runner (windows/runner/taskbar_badge.cpp).
  final MethodChannel _channel;
  final _listening = <Client>{};
  final _subscriptions = <StreamSubscription<Object?>>[];

  /// The count last sent to the runner, so syncs that change nothing don't
  /// cross the channel.
  int? _shown;

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  void init() {
    if (!_supported) return;
    _listenAll();
    manager.addListener(_listenAll);
  }

  void dispose() {
    manager.removeListener(_listenAll);
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  /// Also runs on every manager change, which covers logins and logouts.
  void _listenAll() {
    for (final client in manager.clients) {
      if (!_listening.add(client)) continue;
      // Notification counts, invites and marked-unread flags all arrive by
      // sync — including the echo of a room read here or on another device.
      _subscriptions.add(client.onSync.stream.listen((_) => _update()));
    }
    _update();
  }

  Future<void> _update() async {
    final count = pendingCount(manager.loggedInClients);
    if (count == _shown) return;
    _shown = count;
    try {
      await _channel.invokeMethod<void>('setBadgeCount', count);
    } catch (e, s) {
      Logs().w('Failed to update the app icon badge', e, s);
    }
  }
}

/// What waits for the user across [clients]: the unread badge counts of all
/// rooms (as the room list shows them) plus every pending invitation.
int pendingCount(Iterable<Client> clients) {
  var count = 0;
  for (final client in clients) {
    for (final room in client.rooms) {
      if (room.membership == Membership.invite) {
        count++;
      } else if (!room.isSpace) {
        count += room.unreadBadgeCount;
      }
    }
  }
  return count;
}
