import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matrix/matrix.dart';

import 'client_manager.dart';
import 'settings.dart';
import 'widgets/user_banner.dart';

/// Keeps every account's sync presence in line with how the user is
/// actually reachable: only the active account advertises its chosen
/// presence, accounts in the background appear offline and manually
/// invisible accounts stay invisible. After [idleThreshold] without
/// keyboard/pointer input the active account drops to away, until the next
/// activity.
class PresenceService with WidgetsBindingObserver {
  PresenceService(
    this.manager,
    this.settings, {
    this.idleThreshold = const Duration(minutes: 10),
  });

  final Duration idleThreshold;

  final ClientManager manager;
  final AppSettings settings;

  DateTime _lastActivity = DateTime.now();
  bool _away = false;
  Timer? _timer;

  void init() {
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKey);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _check());
    manager.addListener(_apply);
    settings.addListener(_apply);
    _apply();
  }

  void dispose() {
    settings.removeListener(_apply);
    manager.removeListener(_apply);
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

  /// Called on any user input — including plain mouse movement, so simply
  /// coming back to the window counts. Returns presence to the chosen one
  /// when away.
  void notifyActivity() {
    final now = DateTime.now();
    // Hovering fires per pointer event; while active there is nothing to do
    // but keep the clock honest, and one update a second is enough for that.
    if (!_away && now.difference(_lastActivity) < const Duration(seconds: 1)) {
      return;
    }
    _lastActivity = now;
    if (!_away) return;
    _away = false;
    _apply();
    unawaited(_pushReturnToPresence());
  }

  /// The sync parameter only reaches the server with the *next* sync request,
  /// which is a long poll up to 30 s away — far too long to wait for the dot
  /// to go green again after coming back to the app. The presence API applies
  /// at once, and is used only for coming back: raising a presence can't
  /// wrongly downgrade another device that really is online, which is why the
  /// away direction is left to the sync parameter.
  Future<void> _pushReturnToPresence() async {
    final client = manager.activeClient;
    final userId = client?.userID;
    if (client == null || userId == null) return;
    final presence = effectiveSyncPresence(
      settings.presenceFor(client.clientName),
      active: true,
    );
    if (presence != PresenceType.online) return;
    try {
      // The presence API replaces the whole presence, so the status message
      // has to be passed back in or it is cleared.
      final statusMsg = resolveUserStatus(
        presenceStatusMsg: (await client.fetchCurrentPresence(
          userId,
        )).statusMsg,
        profileStatus: await fetchUserStatus(client, userId),
      );
      await client.setPresence(userId, presence, statusMsg: statusMsg);
    } catch (_) {
      // Best effort: the sync parameter still applies on the next request.
    }
  }

  void _check() {
    if (!settings.autoAway || _away) return;
    if (DateTime.now().difference(_lastActivity) >= idleThreshold) {
      _away = true;
      _apply();
    }
  }

  /// Runs the idle check that the internal timer drives, for tests.
  @visibleForTesting
  void checkIdle() => _check();

  /// Presence travels as the set_presence parameter of each sync request
  /// (unlike the presence API this can neither clear the status message nor
  /// downgrade another device that really is online), so a change takes
  /// effect within one long-poll cycle.
  void _apply() {
    for (final client in manager.loggedInClients) {
      client.syncPresence = effectiveSyncPresence(
        settings.presenceFor(client.clientName),
        active: client == manager.activeClient,
        idle: _away && settings.autoAway,
      );
    }
  }
}
