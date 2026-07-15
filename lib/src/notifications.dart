import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:matrix/matrix.dart';

import 'client_manager.dart';
import 'pages/room_page.dart';
import 'settings.dart';

/// Shows desktop notifications for incoming messages (as selected by the
/// account's push rules) of all logged-in accounts while the window is not
/// focused.
class NotificationService with WidgetsBindingObserver {
  NotificationService(this.manager, {this.navigatorKey, this.settings});

  final ClientManager manager;
  final GlobalKey<NavigatorState>? navigatorKey;
  final AppSettings? settings;
  final _plugin = FlutterLocalNotificationsPlugin();
  final _listening = <Client>{};
  final _subscriptions = <StreamSubscription<Event>>[];
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  static const _notifiableTypes = {
    EventTypes.Message,
    EventTypes.Encrypted,
    EventTypes.Sticker,
    // Invites arrive as m.room.member events (the SDK only forwards the
    // ones addressed to us).
    EventTypes.RoomMember,
  };

  /// The room currently open in the UI, set by the room page. While the
  /// window is focused, no notifications are shown for this room.
  static String? activeRoomId;

  /// Whether the window currently has focus — consumed e.g. to pause GIF
  /// playback in the background.
  static final ValueNotifier<bool> appFocused = ValueNotifier(true);

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    _lifecycle =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    try {
      // Permissions are NOT requested during initialize: the request blocks
      // until the user answers the system prompt (or forever when the prompt
      // cannot be shown), so it must never gate anything else.
      await _plugin.initialize(
        settings: const InitializationSettings(
          macOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          linux: LinuxInitializationSettings(defaultActionName: 'Open'),
        ),
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      unawaited(
        _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true),
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
      navigator.push(MaterialPageRoute(builder: (_) => RoomPage(room: room)));
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
    final body = event.calcLocalizedBodyFallback(
      const MatrixDefaultLocalizations(),
      hideReply: true,
      plaintextBody: true,
      removeMarkdown: true,
      withSenderNamePrefix: !room.isDirectChat,
    );
    try {
      await _plugin.show(
        id: event.eventId.hashCode,
        title: room.getLocalizedDisplayname(),
        body: body,
        notificationDetails: NotificationDetails(
          macOS: DarwinNotificationDetails(
            presentSound: settings?.notificationSounds ?? true,
          ),
        ),
        payload: '${client.clientName}|${room.id}',
      );
    } catch (_) {
      // Notifications are best-effort (permission may have been denied).
    }
  }
}
