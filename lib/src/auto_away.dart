import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matrix/matrix.dart';

import 'client_manager.dart';
import 'settings.dart';

/// Sets the presence of all logged-in accounts to "unavailable" after
/// [idleThreshold] without keyboard/pointer input, and back to online on the
/// next activity. Accounts manually set to invisible are left alone.
class AutoAwayService with WidgetsBindingObserver {
  AutoAwayService(this.manager, this.settings);

  static const idleThreshold = Duration(minutes: 10);

  final ClientManager manager;
  final AppSettings settings;

  DateTime _lastActivity = DateTime.now();
  bool _away = false;
  Timer? _timer;

  void init() {
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKey);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _check());
  }

  void dispose() {
    _timer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    WidgetsBinding.instance.removeObserver(this);
  }

  bool _onKey(KeyEvent event) {
    notifyActivity();
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) notifyActivity();
  }

  /// Called on any user input; returns presence to online when away.
  void notifyActivity() {
    _lastActivity = DateTime.now();
    if (_away) {
      _away = false;
      _setPresence(PresenceType.online);
    }
  }

  void _check() {
    if (!settings.autoAway || _away) return;
    if (DateTime.now().difference(_lastActivity) >= idleThreshold) {
      _away = true;
      _setPresence(PresenceType.unavailable);
    }
  }

  void _setPresence(PresenceType presence) {
    for (final client in manager.loggedInClients) {
      // Never override a manually chosen invisible/away state.
      if (client.syncPresence == PresenceType.offline ||
          client.syncPresence == PresenceType.unavailable && !_away) {
        continue;
      }
      final userId = client.userID;
      if (userId == null) continue;
      client.setPresence(userId, presence).catchError((_) {});
    }
  }
}
