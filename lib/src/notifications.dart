import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:matrix/matrix.dart';

import 'client_manager.dart';
import 'emoji_shortcodes.dart';
import 'nicknames.dart';
import 'pages/room_page.dart';
import 'room_navigator.dart';
import 'settings.dart';

/// Shows desktop notifications for incoming messages (as selected by the
/// account's push rules) of all logged-in accounts while the window is not
/// focused.
class NotificationService with WidgetsBindingObserver {
  NotificationService(
    this.manager, {
    this.navigatorKey,
    this.settings,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final ClientManager manager;
  final GlobalKey<NavigatorState>? navigatorKey;
  final AppSettings? settings;
  final FlutterLocalNotificationsPlugin _plugin;
  final _listening = <Client>{};
  final _subscriptions = <StreamSubscription<Object?>>[];
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  /// The running service, so the room page can dismiss notifications of a
  /// room the user just read.
  static NotificationService? _instance;

  /// Ids of the notifications currently shown, per `clientName|roomId`, so
  /// they can be dismissed once their room is read — otherwise they linger
  /// in the notification center and keep the launcher's unread badge alive.
  final _shownByRoom = <String, Set<int>>{};

  static const _notifiableTypes = {
    EventTypes.Message,
    EventTypes.Encrypted,
    EventTypes.Sticker,
    // Invites arrive as m.room.member events (the SDK only forwards the
    // ones addressed to us).
    EventTypes.RoomMember,
  };

  /// Per-platform plugin setup. Every desktop platform the app targets has
  /// to appear here: the plugin throws when the running platform's settings
  /// are missing, and that leaves the whole service dead rather than
  /// degraded.
  static const initializationSettings = InitializationSettings(
    macOS: DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    ),
    linux: LinuxInitializationSettings(defaultActionName: 'Open'),
    windows: WindowsInitializationSettings(
      appName: 'Protea',
      // Identifies the app to the Windows notification platform. The plugin
      // registers it under HKCU, so toasts work without an MSIX package.
      appUserModelId: 'energy.vgt.Protea',
      // COM class id of the toast activation callback. It must stay stable
      // across releases: change it and taps on toasts from an older install
      // stop reaching the app.
      guid: '45985c6e-b3da-4c8e-8255-a57684e6573c',
    ),
  );

  /// The room currently open in the UI, set by the room page. While the
  /// window is focused, no notifications are shown for this room.
  static String? activeRoomId;

  /// Whether the window currently has focus — consumed e.g. to pause GIF
  /// playback in the background.
  static final ValueNotifier<bool> appFocused = ValueNotifier(true);

  Future<void> init() async {
    _instance = this;
    WidgetsBinding.instance.addObserver(this);
    _lifecycle =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    try {
      // Permissions are NOT requested during initialize: the request blocks
      // until the user answers the system prompt (or forever when the prompt
      // cannot be shown), so it must never gate anything else.
      await _plugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      // Drop notifications left over from a previous run. On Linux the
      // plugin remembers them in a cache keyed by the daemon's ids, which
      // are session-scoped counters — after a restart those ids get reused
      // by unrelated notifications, and their ActionInvoked signals would
      // match the stale cache and open rooms nobody tapped.
      await _plugin.cancelAll();
      unawaited(
        _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true)
            .then((granted) {
              if (granted == true) return;
              Logs().w(
                'macOS notification permission not granted (granted: '
                '$granted) — check System Settings > Notifications.',
              );
            }),
      );
    } catch (e, s) {
      Logs().w('Failed to initialize desktop notifications', e, s);
    }
    _listenAll();
    manager.addListener(_listenAll);
  }

  void _listenAll() {
    for (final client in manager.clients) {
      if (!_listening.add(client)) continue;
      _subscriptions.add(
        client.onNotification.stream.listen(
          (event) => _showNotification(client, event),
        ),
      );
      // Reading a room on any device resets its notification count; drop
      // the room's shown notifications along with it.
      _subscriptions.add(
        client.onSync.stream.listen((update) => _onSync(client, update)),
      );
    }
  }

  void _onSync(Client client, SyncUpdate update) {
    final joins = update.rooms?.join;
    if (joins == null) return;
    for (final roomId in joins.keys) {
      if (!_shownByRoom.containsKey('${client.clientName}|$roomId')) continue;
      final room = client.getRoomById(roomId);
      if (room != null && room.notificationCount == 0) {
        unawaited(_clearRoom(client, roomId));
      }
    }
  }

  /// Dismisses the shown notifications of [roomId] across accounts, e.g.
  /// when the room was just read in the app. Safe to call when none exist.
  static void clearRoomNotifications(String roomId) {
    final instance = _instance;
    if (instance == null) return;
    for (final client in instance.manager.clients) {
      unawaited(instance._clearRoom(client, roomId));
    }
  }

  Future<void> _clearRoom(Client client, String roomId) async {
    final ids = _shownByRoom.remove('${client.clientName}|$roomId');
    if (ids == null) return;
    for (final id in ids) {
      try {
        await _plugin.cancel(id: id);
      } catch (e, s) {
        Logs().w('Failed to dismiss desktop notification', e, s);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    appFocused.value = state == AppLifecycleState.resumed;
  }

  /// Opens the room a tapped notification belongs to. The payload is
  /// `clientName|roomId`.
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    final navigator = navigatorKey?.currentState;
    if (payload == null || navigator == null) return;
    final separator = payload.indexOf('|');
    if (separator == -1) return;
    final clientName = payload.substring(0, separator);
    final roomId = payload.substring(separator + 1);
    for (final client in manager.clients) {
      if (client.clientName != clientName) continue;
      final room = client.getRoomById(roomId);
      if (room == null) return;
      if (manager.activeClient != client) manager.setActive(client);
      // Select the room in the active layout instead of stacking a
      // full-screen page over it. After an account switch the layout for
      // the new account only mounts on the next frame, so deliver the
      // request afterwards.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (RoomNavigator.instance.open(roomId)) return;
        navigator.push(MaterialPageRoute(builder: (_) => RoomPage(room: room)));
      });
      return;
    }
  }

  Future<void> _showNotification(Client client, Event event) async {
    if (!(settings?.desktopNotifications ?? true)) return;
    // Suppress only what the user is actively reading: the room open in a
    // focused window. Messages for other rooms notify even while focused
    // (and everything notifies while the window is in the background).
    if (_lifecycle == AppLifecycleState.resumed &&
        event.room.id == activeRoomId) {
      return;
    }
    if (event.senderId == client.userID) return;
    if (!_notifiableTypes.contains(event.type)) return;
    final room = event.room;
    var body = replaceEmojiShortcodes(
      event.calcLocalizedBodyFallback(
        const MatrixDefaultLocalizations(),
        hideReply: true,
        plaintextBody: true,
        removeMarkdown: true,
      ),
    );
    // The SDK's withSenderNamePrefix, but with the sender's nickname.
    if (!room.isDirectChat &&
        event.type == EventTypes.Message &&
        Event.textOnlyMessageTypes.contains(event.messageType)) {
      body = '${event.senderFromMemoryOrFallback.nickOrDisplayname}: $body';
    }
    try {
      await _plugin.show(
        id: event.eventId.hashCode,
        title: room.nickOrDisplayname,
        body: body,
        notificationDetails: NotificationDetails(
          macOS: DarwinNotificationDetails(
            presentSound: settings?.notificationSounds ?? true,
          ),
          windows: WindowsNotificationDetails(
            audio: (settings?.notificationSounds ?? true)
                ? null
                : WindowsNotificationAudio.silent(),
          ),
        ),
        payload: '${client.clientName}|${room.id}',
      );
      (_shownByRoom['${client.clientName}|${room.id}'] ??= {}).add(
        event.eventId.hashCode,
      );
    } catch (e, s) {
      // Notifications are best-effort (permission may have been denied).
      Logs().w('Failed to show desktop notification', e, s);
    }
  }
}
